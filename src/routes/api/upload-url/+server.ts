import { json, error } from '@sveltejs/kit';
import { AwsClient } from 'aws4fetch';
import {
	R2_ACCOUNT_ID,
	R2_ACCESS_KEY_ID,
	R2_SECRET_ACCESS_KEY,
	R2_BUCKET,
	R2_PUBLIC_BASE_URL
} from '$env/static/private';
import type { RequestHandler } from './$types';

/**
 * Firma un URL di upload temporaneo verso R2, cosi' il browser puo' caricare
 * la foto direttamente sul bucket senza che la secret key di R2 finisca mai
 * nel bundle client — a differenza della anon key di Supabase, una chiave R2
 * trapelata permetterebbe di scrivere e CANCELLARE l'intero bucket.
 *
 * Il contratto e' minimo apposta: il client manda solo la cartella (l'id del
 * giocatore) e l'estensione, il nome del file lo decide il server. Cosi' non
 * c'e' alcuna stringa libera del client che finisce nella chiave dell'oggetto.
 */

const ESTENSIONI: Record<string, string> = {
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

export const POST: RequestHandler = async ({ request }) => {
	const body = await request.json().catch(() => null);
	const userId = body?.userId;
	const estensione = body?.estensione;

	if (typeof userId !== 'string' || !UUID.test(userId)) {
		error(400, 'userId non valido');
	}
	if (typeof estensione !== 'string' || !(estensione in ESTENSIONI)) {
		error(400, 'estensione non supportata');
	}

	const contentType = ESTENSIONI[estensione];
	const nomeFile = `${crypto.randomUUID()}.${estensione}`;
	const chiave = `catture/${userId}/${nomeFile}`;

	const endpoint = new URL(
		`https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${R2_BUCKET}/${chiave}`
	);
	// Cinque minuti bastano e avanzano: la foto e' gia' pronta sul dispositivo
	// quando si chiede l'URL, l'upload parte subito dopo.
	endpoint.searchParams.set('X-Amz-Expires', '300');

	const firmata = await client.sign(endpoint, {
		method: 'PUT',
		headers: { 'Content-Type': contentType },
		aws: { signQuery: true }
	});

	return json({
		uploadUrl: firmata.url,
		contentType,
		publicUrl: `${R2_PUBLIC_BASE_URL}/${chiave}`
	});
};
