import { supabase } from '$lib/supabase';

/**
 * Avvisa il server che e' successo qualcosa di notificabile.
 *
 * Non aspetta e non fa rumore se fallisce: una notifica persa e' un
 * fastidio, una cattura persa perche' il push era giu' sarebbe un danno.
 * Per questo si chiama sempre DOPO che l'azione e' andata a buon fine, e
 * l'errore muore qui.
 *
 * Va allegato il token: l'endpoint controlla che ad annunciare l'evento sia
 * qualcuno che c'entra — chi ha scattato, chi ha contestato, chi ha mandato
 * i Croquembouche. Senza sessione non si annuncia niente, ma l'azione era
 * comunque gia' andata a buon fine: si perde la notifica, non il gesto.
 */
export function notificaEvento(
	tipo: 'cattura' | 'contestazione_aperta' | 'contestazione_chiusa' | 'scambio',
	id: string
): void {
	void (async () => {
		const { data } = await supabase.auth.getSession();
		const token = data.session?.access_token;
		if (!token) return;

		await fetch('/api/push', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
			body: JSON.stringify({ tipo, id }),
			keepalive: true // regge anche se l'utente cambia pagina subito dopo
		});
	})().catch(() => {});
}
