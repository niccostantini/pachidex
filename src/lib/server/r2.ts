import { AwsClient } from 'aws4fetch';
import {
	R2_ACCOUNT_ID,
	R2_ACCESS_KEY_ID,
	R2_SECRET_ACCESS_KEY,
	R2_BUCKET,
	R2_PUBLIC_BASE_URL,
	R2_JURISDICTION
} from '$env/static/private';

/**
 * Il secchio delle foto.
 *
 * Stava tutto dentro l'endpoint che firma gli upload, finche' non e' servito
 * anche a cancellarle a fine stagione. Le credenziali di R2 permettono di
 * scrivere e di CANCELLARE l'intero bucket: meglio un posto solo che le
 * conosce, e due endpoint che gli chiedono le cose.
 */

export const r2 = new AwsClient({
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
export const R2_HOST = `${R2_ACCOUNT_ID}.${SOTTODOMINIO}r2.cloudflarestorage.com`;
export const BUCKET = R2_BUCKET;
export const BASE_PUBBLICA = R2_PUBLIC_BASE_URL;

export const r2Pronto = R2_ACCESS_KEY_ID.length > 0 && R2_SECRET_ACCESS_KEY.length > 0;

/**
 * Dalla URL pubblica alla chiave dell'oggetto.
 *
 * Restituisce null per tutto cio' che non viene dal nostro dominio: nel
 * database ci sono anche foto di prova che puntano altrove, e una
 * cancellazione non deve mai andare a tentoni su un indirizzo che non
 * riconosce.
 */
export function chiaveDaUrl(url: string): string | null {
	if (!url.startsWith(BASE_PUBBLICA + '/')) return null;
	const chiave = url.slice(BASE_PUBBLICA.length + 1);
	return chiave.length ? chiave : null;
}

/** Toglie un oggetto dal bucket. true se non c'e' piu', comunque sia andata. */
export async function cancella(chiave: string): Promise<boolean> {
	const r = await r2.fetch(`https://${R2_HOST}/${BUCKET}/${chiave}`, { method: 'DELETE' });
	// 204 e' fatto, 404 vuol dire che non c'era: per noi sono la stessa cosa.
	return r.status === 204 || r.status === 404;
}
