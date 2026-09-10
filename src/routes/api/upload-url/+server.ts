import { json, error } from '@sveltejs/kit';
import { AwsClient } from 'aws4fetch';
import { createClient } from '@supabase/supabase-js';
import {
	R2_ACCOUNT_ID,
	R2_ACCESS_KEY_ID,
	R2_SECRET_ACCESS_KEY,
	R2_BUCKET,
	R2_PUBLIC_BASE_URL,
	R2_JURISDICTION
} from '$env/static/private';
import { PUBLIC_SUPABASE_ANON_KEY, PUBLIC_SUPABASE_URL } from '$env/static/public';
import { idUnico } from '$lib/id';
import type { RequestHandler } from './$types';

/**
 * Firma un URL di upload temporaneo verso R2, cosi' il browser puo' caricare
 * la foto direttamente sul bucket senza che la secret key di R2 finisca mai
 * nel bundle client — a differenza della anon key di Supabase, una chiave R2
 * trapelata permetterebbe di scrivere e CANCELLARE l'intero bucket.
 *
 * --- CHI PUO' CHIEDERLO -----------------------------------------------------
 * Chi ha fatto login ed e' in partita, e nessun altro.
 *
 * Prima non lo chiedeva a nessuno: bastava un POST con un uuid qualsiasi nel
 * corpo per farsi firmare una PUT sul bucket di produzione, senza credenziali.
 * Il dominio pubblico delle foto diventava spazio di hosting per chiunque.
 *
 * L'identita' adesso la decide chi_agisce(), che la prende da auth.uid() e
 * rifiuta chi guarda da fuori: la stessa porta da cui passa una cattura vera.
 * La cartella e' l'id che torna da li' — il corpo della richiesta non nomina
 * piu' nessuno, quindi non c'e' modo di scrivere nello spazio di un altro.
 */

const ESTENSIONI: Record<string, string> = {
	avif: 'image/avif',
	webp: 'image/webp',
	jpg: 'image/jpeg'
};

// Path del giocatore: solo esadecimale con trattini, come un uuid v4.
const UUID = /^[0-9a-f-]{36}$/i;

const client = new AwsClient({
	accessKeyId: R2_ACCESS_KEY_ID,
	secretAccessKey: R2_SECRET_ACCESS_KEY,
	service: 's3',
	region: 'auto'
});

/**
 * R2 espone endpoint diversi per giurisdizione: un bucket creato con
 * giurisdizione EU non e' raggiungibile da quello standard, e risponde
 * AccessDenied — indistinguibile da una chiave sbagliata, quindi vale la
 * pena tenerlo esplicito invece di scoprirlo a tentativi.
 */
const SOTTODOMINIO = R2_JURISDICTION ? `${R2_JURISDICTION}.` : '';
const HOST = `${R2_ACCOUNT_ID}.${SOTTODOMINIO}r2.cloudflarestorage.com`;

/** L'id di chi sta caricando, preso dal token e non dal corpo. */
async function chiCarica(request: Request): Promise<string> {
	const autorizzazione = request.headers.get('Authorization') ?? '';
	if (!autorizzazione.startsWith('Bearer ')) error(401, 'Non sei entrato');

	const comeChiama = createClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY, {
		global: { headers: { Authorization: autorizzazione } },
		auth: { persistSession: false }
	});

	// chi_agisce() alza un'eccezione parlante se il token non vale piu' o se
	// l'account non e' un giocatore: qui basta rimandarla indietro.
	const { data, error: errore } = await comeChiama.rpc('chi_agisce');
	if (errore) error(403, errore.message);
	if (typeof data !== 'string' || !UUID.test(data)) {
		error(403, "Questo account non puo' caricare foto");
	}
	return data;
}

export const POST: RequestHandler = async ({ request }) => {
	const utente = await chiCarica(request);

	const body = await request.json().catch(() => null);
	const estensione = body?.estensione;

	if (typeof estensione !== 'string' || !(estensione in ESTENSIONI)) {
		error(400, 'estensione non supportata');
	}

	const contentType = ESTENSIONI[estensione];
	const nomeFile = `${idUnico()}.${estensione}`;
	const chiave = `catture/${utente}/${nomeFile}`;

	const endpoint = new URL(`https://${HOST}/${R2_BUCKET}/${chiave}`);
	// Cinque minuti bastano e avanzano: la foto e' gia' pronta sul dispositivo
	// quando si chiede l'URL, l'upload parte subito dopo.
	endpoint.searchParams.set('X-Amz-Expires', '300');

	const firmata = await client.sign(endpoint, {
		method: 'PUT',
		headers: { 'Content-Type': contentType },
		// allHeaders serve a far entrare il Content-Type NELLA firma. Senza,
		// aws4fetch lo tratta come intestazione non firmabile: restava un
		// suggerimento, e chi aveva l'URL poteva caricare qualsiasi cosa —
		// una pagina HTML servita dal dominio delle foto, per dire.
		aws: { signQuery: true, allHeaders: true }
	});

	return json({
		uploadUrl: firmata.url,
		contentType,
		publicUrl: `${R2_PUBLIC_BASE_URL}/${chiave}`
	});
};
