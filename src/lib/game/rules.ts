import type { Categoria, Rarita } from '$lib/types';

export const CATEGORIE: { valore: Categoria; label: string; plurale: string; icona: string }[] = [
	{ valore: 'posto', label: 'Posto', plurale: 'Posti', icona: '▲' },
	{ valore: 'pietanza', label: 'Pietanza', plurale: 'Pietanze', icona: '◆' },
	{ valore: 'animale', label: 'Animale', plurale: 'Animali', icona: '●' },
	{ valore: 'attivita', label: 'Attivita', plurale: 'Attivita', icona: '★' }
];

export const RARITA: { valore: Rarita; label: string; croq: number }[] = [
	{ valore: 'comune', label: 'Comune', croq: 10 },
	{ valore: 'raro', label: 'Raro', croq: 25 },
	{ valore: 'leggendario', label: 'Leggendario', croq: 60 }
];

export const CROQ_DEFAULT: Record<Rarita, number> = {
	comune: 10,
	raro: 25,
	leggendario: 60
};

/**
 * I caratteri ammessi nel nome di una sfiziosita': lettere di qualsiasi
 * alfabeto, cifre, spazi e la punteggiatura che i nomi veri usano davvero —
 * "Cavaliere d'Italia", "1ª cosa da fare: selfie inaugurale".
 *
 * Fuori restano soprattutto < > " = e &, cioe' quello che serve a scrivere un
 * tag: un nome finisce nel fumetto della mappa, e li' deve restare testo.
 * La regola sta qui e non dentro l'import perche' la usano in due — il CSV e
 * il modulo del pannello — e due copie che si scostano sono peggio di niente.
 */
const NOME_ITEM = /^[\p{L}\p{N} '’·°ª,.:;!?()\-–]{2,80}$/u;

/** I caratteri che l'utente ha scritto e che non sono ammessi. */
const fuoriRegola = (nome: string) => [...new Set([...nome].filter((c) => !NOME_ITEM.test(`a${c}`)))];

/**
 * Cosa c'e' che non va in questo nome, detto a chi lo sta scrivendo.
 * null quando va bene.
 */
export function problemaNome(nome: string): string | null {
	const pulito = nome.trim();
	if (!pulito) return 'Il nome serve.';
	if (pulito.length < 2) return 'Il nome e\' troppo corto: almeno due caratteri.';
	if (pulito.length > 80) return `Il nome e' troppo lungo: ${pulito.length} caratteri invece di 80.`;
	if (NOME_ITEM.test(pulito)) return null;
	const strani = fuoriRegola(pulito);
	return `Questi caratteri non si possono usare in un nome: ${strani.join(' ')}`;
}

export const varCategoria = (c: Categoria) => `var(--cat-${c})`;
export const varRarita = (r: Rarita) => `var(--rarity-${r})`;

export const etichettaCategoria = (c: Categoria) =>
	CATEGORIE.find((x) => x.valore === c)?.label ?? c;

export const iconaCategoria = (c: Categoria) => CATEGORIE.find((x) => x.valore === c)?.icona ?? '?';

export const etichettaRarita = (r: Rarita) => RARITA.find((x) => x.valore === r)?.label ?? r;

/**
 * Voti necessari per chiudere una contestazione.
 * Vota chiunque tranne il contestato, quindi con 6 profili sono 5 voti e
 * la maggioranza e' 3: dispari per costruzione, mai una parita'.
 */
export const maggioranza = (giocatoriTotali: number) =>
	Math.floor((giocatoriTotali - 1) / 2) + 1;

/** Le iniziali usate finche' un giocatore non ha il suo sprite. */
export function iniziali(nome: string): string {
	const parti = nome.replace(/([a-zà-ÿ])([A-Z])/g, '$1 $2').split(/[\s_-]+/);
	if (parti.length >= 2) return (parti[0][0] + parti[1][0]).toUpperCase();
	return nome.slice(0, 2).toUpperCase();
}

/** "ora", "12 min", "3 h", "ieri", "14 ago" — compatto come in un feed. */
export function tempoRelativo(iso: string): string {
	const t = new Date(iso).getTime();
	const diff = Date.now() - t;
	const min = Math.floor(diff / 60000);
	if (min < 1) return 'ora';
	if (min < 60) return `${min} min`;
	const h = Math.floor(min / 60);
	if (h < 24) return `${h} h`;
	if (h < 48) return 'ieri';
	return new Date(t).toLocaleDateString('it-IT', { day: 'numeric', month: 'short' });
}

/** Countdown "4h 12m" per le contestazioni aperte. */
export function tempoRimanente(iso: string): string {
	const ms = new Date(iso).getTime() - Date.now();
	if (ms <= 0) return 'scaduta';
	const min = Math.floor(ms / 60000);
	const h = Math.floor(min / 60);
	return h > 0 ? `${h}h ${min % 60}m` : `${min}m`;
}

export const formattaCroq = (n: number) => `${n > 0 ? '+' : ''}${n}`;
