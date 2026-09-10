import webpush from 'web-push';
import { createClient } from '@supabase/supabase-js';
import {
	SUPABASE_SERVICE_ROLE_KEY,
	VAPID_PRIVATE_KEY,
	VAPID_SUBJECT
} from '$env/static/private';
import { PUBLIC_SUPABASE_URL, PUBLIC_VAPID_KEY } from '$env/static/public';

/**
 * L'invio delle notifiche, lato server.
 *
 * Il testo dei messaggi si costruisce QUI leggendo dal database, non arriva
 * dal client: chi chiama dice solo "e' successa la cosa X", e cosa raccontare
 * lo decide il server. Cosi' nessuno puo' far arrivare agli altri una
 * notifica che dice quello che gli pare.
 */

webpush.setVapidDetails(VAPID_SUBJECT, PUBLIC_VAPID_KEY, VAPID_PRIVATE_KEY);

/**
 * Qui serve la service role, non la chiave anonima.
 *
 * Mandare una notifica vuol dire leggere le iscrizioni DI ALTRI, ed e'
 * esattamente cio' che le policy vietano a chiunque: `le_mie_notifiche`
 * lascia vedere solo le proprie. Con la chiave anonima — che e' quello che
 * c'era qui — dalla 0027 in poi la select tornava zero righe sempre, e le
 * notifiche erano mute senza che nessun errore lo dicesse: il pannello
 * contava i dispositivi iscritti (quello passa da una funzione definer) e
 * sembrava tutto a posto.
 *
 * Una chiave che scavalca le RLS pero' non basta tenerla lontana dal
 * browser: chi puo' chiamare l'endpoint conta quanto la chiave stessa, ed e'
 * il motivo per cui /api/push adesso chiede chi sei.
 */
export const pushPronto = SUPABASE_SERVICE_ROLE_KEY.length > 0;

export const db = createClient(PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
	auth: { persistSession: false, autoRefreshToken: false }
});

export interface Messaggio {
	titolo: string;
	corpo: string;
	url?: string;
	tag?: string;
	insisti?: boolean;
}

interface Iscrizione {
	id: string;
	endpoint: string;
	p256dh: string;
	auth: string;
}

/**
 * Manda un messaggio a un gruppo di giocatori.
 * Le iscrizioni che il servizio push rifiuta come morte (410, 404) vengono
 * marcate scadute: un telefono che ha disinstallato la PWA non deve far
 * fallire gli invii di tutti gli altri per sempre.
 */
export async function inviaA(userIds: string[], m: Messaggio): Promise<number> {
	const destinatari = [...new Set(userIds)].filter(Boolean);
	if (!destinatari.length) return 0;

	const { data, error } = await db
		.from('push_subscriptions')
		.select('id, endpoint, p256dh, auth')
		.in('user_id', destinatari)
		.eq('scaduta', false);

	if (error || !data?.length) return 0;

	const corpo = JSON.stringify(m);
	let inviate = 0;

	await Promise.all(
		(data as Iscrizione[]).map(async (i) => {
			try {
				await webpush.sendNotification(
					{ endpoint: i.endpoint, keys: { p256dh: i.p256dh, auth: i.auth } },
					corpo,
					{ TTL: 60 * 60 * 12 }
				);
				inviate++;
			} catch (e) {
				const stato = (e as { statusCode?: number }).statusCode;
				const morta = stato === 404 || stato === 410;
				await db
					.from('push_subscriptions')
					.update({
						scaduta: morta,
						ultimo_errore: `${stato ?? '?'}: ${(e as Error).message}`.slice(0, 300)
					})
					.eq('id', i.id);
			}
		})
	);

	return inviate;
}

/**
 * Chi gioca, e quindi chi ha senso avvisare.
 *
 * Gli account `nascosto` — chi amministra, chi guarda per curiosita' — non
 * catturano, non votano e non stanno in classifica: un promemoria del tipo
 * "non hai ancora votato" andrebbe a chi non puo' votare.
 */
export async function tuttiIGiocatori(): Promise<string[]> {
	const { data } = await db.from('users').select('id').eq('nascosto', false);
	return (data ?? []).map((u) => u.id as string);
}

/** Tutti tranne quelli elencati: il caso piu' frequente. */
export async function tuttiTranne(esclusi: string[]): Promise<string[]> {
	return (await tuttiIGiocatori()).filter((id) => !esclusi.includes(id));
}

export const croq = (n: number) => `${n} ✦`;
