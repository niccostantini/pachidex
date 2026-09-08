/**
 * Gli sprite dei giocatori, presi dalla cartella invece che elencati a mano.
 *
 * Prima erano sei import cablati per sei amici che non cambiavano. Ora il
 * file si prende quello che trova: basta lasciare un PNG in
 * src/assets/avatars/ chiamato come il giocatore — tutto minuscolo, senza
 * spazi — e compare da solo. Nessun elenco da tenere allineato.
 *
 * Vite li importa come asset: fingerprint, cache lunga e nessuna richiesta a
 * runtime verso Supabase o R2.
 */
const FILE = import.meta.glob('../assets/avatars/*.{png,webp}', {
	eager: true,
	query: '?url',
	import: 'default'
}) as Record<string, string>;

/** Chiave: il nome del file senza estensione, che e' il nome del giocatore. */
const PER_NOME: Record<string, string> = Object.fromEntries(
	Object.entries(FILE).map(([percorso, url]) => [
		percorso.split('/').pop()!.replace(/\.\w+$/, '').toLowerCase(),
		url
	])
);

/**
 * Lo sprite di un giocatore, se ne ha uno.
 * Chi non ce l'ha ricade sulle iniziali colorate: e' il comportamento
 * giusto, non un caso da gestire.
 */
export function avatarDi(nome: string | undefined | null): string | null {
	if (!nome) return null;
	return PER_NOME[nome.trim().toLowerCase().replace(/\s+/g, '')] ?? null;
}
