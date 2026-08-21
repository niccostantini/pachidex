/**
 * Foto di riferimento: com'e' fatto un elemento, per chi non lo riconosce.
 *
 * I file stanno in src/assets/riferimenti/ e vengono agganciati per nome, non
 * elencati a mano: aggiungerne uno significa lasciarlo cadere nella cartella
 * e scriverne il nome nella colonna `riferimento` del CSV. Nessuna lista da
 * tenere allineata, che sarebbe la prima cosa a scollarsi.
 *
 * Vite risolve il glob a build time, quindi le immagini finiscono nel bundle
 * con il loro fingerprint e il service worker le precarica: si vedono anche
 * senza campo, che e' il caso in cui servono davvero.
 */
const FILE = import.meta.glob<string>('../assets/riferimenti/*.{webp,jpg,jpeg,png}', {
	eager: true,
	query: '?url',
	import: 'default'
});

/** Chiave: nome del file senza estensione, minuscolo. */
const PER_NOME = new Map<string, string>(
	Object.entries(FILE).map(([percorso, url]) => {
		const base = percorso.split('/').pop() ?? '';
		return [base.replace(/\.[^.]+$/, '').toLowerCase(), url];
	})
);

/** L'immagine di riferimento, se quel nome corrisponde a un file presente. */
export function riferimentoDi(nome: string | undefined | null): string | null {
	if (!nome) return null;
	return PER_NOME.get(nome.trim().toLowerCase()) ?? null;
}

/** I nomi disponibili, per la tendina del pannello e per l'import CSV. */
export function riferimentiDisponibili(): string[] {
	return [...PER_NOME.keys()].sort();
}

export const esisteRiferimento = (nome: string) => PER_NOME.has(nome.trim().toLowerCase());
