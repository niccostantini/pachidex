import { json, error } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { CRON_SECRET, SUPABASE_SERVICE_ROLE_KEY } from '$env/static/private';
import { PUBLIC_SUPABASE_ANON_KEY, PUBLIC_SUPABASE_URL } from '$env/static/public';
import { cancella, chiaveDaUrl, r2Pronto } from '$lib/server/r2';
import type { RequestHandler } from './$types';

/**
 * Svuota una stagione: toglie le foto da R2 e poi le catture dal database.
 *
 * L'ordine e' quello e non il contrario. Se sparissero prima le righe, gli
 * oggetti su R2 resterebbero senza che nessuno sappia piu' di averli: nel
 * database non ci sarebbe piu' l'indirizzo per trovarli.
 *
 * Il database da solo non ci arriva — le chiavi di R2 stanno qui — quindi
 * lui dice quali, e questo endpoint fa il lavoro. Le condizioni le mette
 * comunque il database: svuota_stagione rifiuta se lo svuotamento e' spento,
 * se il Wrapped non l'hanno visto tutti e non sono ancora passate 24 ore, o
 * se quella stagione era gia' stata svuotata.
 *
 * Ci si entra in due modi: col segreto del cron, per il lavoro a orario, o
 * col token di un amministratore, per il pulsante nel pannello.
 */

const servizio = () =>
	createClient(PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
		auth: { persistSession: false, autoRefreshToken: false }
	});

async function esigiChiPuo(request: Request) {
	const segreto = request.headers.get('x-cron-secret');
	if (CRON_SECRET && segreto === CRON_SECRET) return;

	const autorizzazione = request.headers.get('Authorization') ?? '';
	if (!autorizzazione.startsWith('Bearer ')) error(401, 'Non sei entrato');

	const comeChiama = createClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY, {
		global: { headers: { Authorization: autorizzazione } },
		auth: { persistSession: false }
	});
	const { data } = await comeChiama.rpc('sono_admin');
	if (data !== true) error(403, 'Serve un account admin');
}

export const POST: RequestHandler = async ({ request }) => {
	if (!SUPABASE_SERVICE_ROLE_KEY) error(500, 'Manca SUPABASE_SERVICE_ROLE_KEY');
	if (!r2Pronto) error(500, 'Mancano le chiavi di R2');
	await esigiChiPuo(request);

	const corpo = await request.json().catch(() => null);
	const stagione = Number(corpo?.stagione);
	if (!Number.isInteger(stagione)) error(400, 'stagione non valida');

	const db = servizio();

	const { data: foto, error: errElenco } = await db.rpc('foto_da_cancellare', {
		p_stagione: stagione
	});
	if (errElenco) error(400, errElenco.message);

	const elenco = (foto ?? []) as { capture_id: string; foto_url: string }[];
	let tolte = 0;
	let saltate = 0;

	for (const f of elenco) {
		const chiave = chiaveDaUrl(f.foto_url);
		// Una foto che non viene dal nostro dominio non si tocca: e' di
		// qualcun altro, o e' una prova. La riga se ne va lo stesso.
		if (!chiave) {
			saltate++;
			continue;
		}
		if (await cancella(chiave)) tolte++;
		else saltate++;
	}

	// Solo adesso le righe. Se qualcosa e' andato storto su R2 restano oggetti
	// orfani, che sono spazio sprecato: il contrario — righe che puntano a
	// foto che non ci sono — sarebbe un feed rotto.
	const { data: cancellate, error: errSvuota } = await db.rpc('svuota_stagione', {
		p_stagione: stagione
	});
	if (errSvuota) error(400, errSvuota.message);

	return json({ stagione, foto: elenco.length, tolte, saltate, catture: cancellate });
};
