import type { User } from '$lib/types';

/**
 * Le @menzioni nella didascalia.
 *
 * Il riconoscimento e' per nome esatto, non per prefisso: "@nic" resterebbe
 * ambiguo fra due nomi che cominciano uguale, e attribuire i Croquembouche
 * alla persona sbagliata e' peggio che non attribuirli. Al nome giusto pensa
 * l'autocompletamento; chi digita a mano e sbaglia semplicemente non tagga.
 */

/** Un @ seguito da lettere, numeri o underscore. Niente accenti nei nomi. */
const MENZIONE = /@([\p{L}\p{N}_]+)/gu;

const normalizza = (s: string) => s.trim().toLowerCase();

/**
 * Chi si puo' menzionare: chi gioca davvero.
 *
 * Admin e Spione stanno fuori dalla partita (`nascosto`): non sono in
 * classifica, quindi un tag su di loro non varrebbe Croquembouche a nessuno e
 * li mostrerebbe nel feed come se giocassero. Il filtro sta qui dentro e non
 * nelle pagine, cosi' vale sia mentre si scrive sia quando si rilegge: una
 * vecchia didascalia con "@Admin" resta testo normale.
 */
export const menzionabili = (utenti: User[]) => utenti.filter((u) => !u.nascosto);

/** I giocatori nominati nel testo, senza duplicati e senza l'autore. */
export function estraiTaggati(testo: string, utenti: User[], autoreId?: string): User[] {
	const perNome = new Map(menzionabili(utenti).map((u) => [normalizza(u.nome), u]));
	const trovati = new Map<string, User>();

	for (const [, nome] of testo.matchAll(MENZIONE)) {
		const u = perNome.get(normalizza(nome));
		if (u && u.id !== autoreId) trovati.set(u.id, u);
	}
	return [...trovati.values()];
}

/**
 * La menzione che si sta scrivendo in questo momento, cioe' l'@ subito a
 * sinistra del cursore. Serve a decidere quando aprire il menu e cosa
 * filtrarci dentro.
 */
export function menzioneInCorso(
	testo: string,
	cursore: number
): { inizio: number; parziale: string } | null {
	const prima = testo.slice(0, cursore);
	const at = prima.lastIndexOf('@');
	if (at === -1) return null;

	const parziale = prima.slice(at + 1);
	// Appena si va a capo o si mette uno spazio, la menzione e' finita.
	if (/[\s@]/.test(parziale)) return null;

	// L'@ deve iniziare una parola, altrimenti si aprirebbe dentro un'email.
	const precedente = at > 0 ? prima[at - 1] : ' ';
	if (!/[\s(]/.test(precedente) && at !== 0) return null;

	return { inizio: at, parziale };
}

/** Sostituisce la menzione in corso col nome completo, e dice dove va il cursore. */
export function completaMenzione(
	testo: string,
	inizio: number,
	cursore: number,
	nome: string
): { testo: string; cursore: number } {
	const sostituzione = `@${nome} `;
	return {
		testo: testo.slice(0, inizio) + sostituzione + testo.slice(cursore),
		cursore: inizio + sostituzione.length
	};
}

/** Spezza il testo in pezzi normali e menzioni riconosciute, per il feed. */
export function spezzaMenzioni(
	testo: string,
	utenti: User[]
): { testo: string; utente: User | null }[] {
	const perNome = new Map(menzionabili(utenti).map((u) => [normalizza(u.nome), u]));
	const pezzi: { testo: string; utente: User | null }[] = [];
	let ultimo = 0;

	for (const m of testo.matchAll(MENZIONE)) {
		const i = m.index ?? 0;
		const u = perNome.get(normalizza(m[1])) ?? null;
		if (!u) continue; // un @ che non e' nessuno resta testo normale
		if (i > ultimo) pezzi.push({ testo: testo.slice(ultimo, i), utente: null });
		pezzi.push({ testo: m[0], utente: u });
		ultimo = i + m[0].length;
	}
	if (ultimo < testo.length) pezzi.push({ testo: testo.slice(ultimo), utente: null });
	return pezzi;
}
