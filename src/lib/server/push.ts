import webpush from 'web-push';
import { createClient } from '@supabase/supabase-js';
import {
	VAPID_PRIVATE_KEY,
	VAPID_SUBJECT
} from '$env/static/private';
import { PUBLIC_SUPABASE_ANON_KEY, PUBLIC_SUPABASE_URL, PUBLIC_VAPID_KEY } from '$env/static/public';

/**
 * L'invio delle notifiche, lato server.
 *
 * Il testo dei messaggi si costruisce QUI leggendo dal database, non arriva
 * dal client: chi chiama dice solo "e' successa la cosa X", e cosa raccontare
 * lo decide il server. Cosi' nessuno puo' far arrivare agli altri una
 * notifica che dice quello che gli pare.
 */

webpush.setVapidDetails(VAPID_SUBJECT, PUBLIC_VAPID_KEY, VAPID_PRIVATE_KEY);

export const db = createClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY, {
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

/** Tutti tranne quelli elencati: il caso piu' frequente. */
export async function tuttiTranne(esclusi: string[]): Promise<string[]> {
	const { data } = await db.from('users').select('id');
	return (data ?? []).map((u) => u.id as string).filter((id) => !esclusi.includes(id));
}

export const croq = (n: number) => `${n} ✦`;
