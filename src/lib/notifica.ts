/**
 * Avvisa il server che e' successo qualcosa di notificabile.
 *
 * Non aspetta e non fa rumore se fallisce: una notifica persa e' un
 * fastidio, una cattura persa perche' il push era giu' sarebbe un danno.
 * Per questo si chiama sempre DOPO che l'azione e' andata a buon fine, e
 * l'errore muore qui.
 */
export function notificaEvento(
	tipo: 'cattura' | 'contestazione_aperta' | 'contestazione_chiusa' | 'scambio',
	id: string
): void {
	void fetch('/api/push', {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ tipo, id }),
		keepalive: true // regge anche se l'utente cambia pagina subito dopo
	}).catch(() => {});
}
