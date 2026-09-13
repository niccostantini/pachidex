import { supabase } from '$lib/supabase';
import type { Formula, PostOversharing, User } from '$lib/types';

/**
 * Fa' Oversharing: le frasi che non sono catture.
 *
 * Le regole stanno nel database — chi puo' scrivere, chi puo' votare, quando
 * un voto si puo' ancora cambiare — e qui si bussa e basta, come per tutto il
 * resto.
 */

/*
 * L'autore si chiede per nome della chiave esterna e non per tabella: da
 * oversharing si arriva a users in due modi — chi l'ha scritto, e chi l'ha
 * votato passando per oversharing_voti — e PostgREST, davanti a due strade,
 * non ne sceglie una: risponde 300 e non mostra niente.
 */
const SELECT = `
	*,
	autore:users!oversharing_user_id_fkey(*),
	formula:formule(id, testo),
	voti:oversharing_voti(user_id, voto)
`;

interface RigaOversharing {
	id: string;
	user_id: string;
	testo: string;
	formula_id: string | null;
	created_at: string;
	autore: User;
	formula: { id: string; testo: string } | null;
	voti: { user_id: string; voto: 'chic' | 'cheap' }[];
}

/**
 * La formula di riserva, quando quella pescata alla pubblicazione e' stata
 * tolta dal pannello.
 *
 * Si sceglie dall'id del post e non a caso: cosi' quel post ha comunque
 * SEMPRE la stessa, che e' tutto il punto di averla scelta una volta sola.
 * Una battuta che cambia cornice a ogni ricarica non si puo' nemmeno citare.
 */
function dallId(id: string, quante: number): number {
	let n = 0;
	for (const c of id) n = (n * 31 + c.charCodeAt(0)) % 100000;
	return quante ? n % quante : 0;
}

function aPost(riga: RigaOversharing, ioId: string | null, ripiego: Formula[]): PostOversharing {
	const voti = riga.voti ?? [];
	const formula =
		riga.formula?.testo ??
		(ripiego.length ? ripiego[dallId(riga.id, ripiego.length)].testo : 'X dice:');
	return {
		tipo: 'oversharing',
		id: riga.id,
		user_id: riga.user_id,
		testo: riga.testo,
		autore: riga.autore,
		formula,
		chic: voti.filter((v) => v.voto === 'chic').length,
		cheap: voti.filter((v) => v.voto === 'cheap').length,
		mio_voto: (ioId && voti.find((v) => v.user_id === ioId)?.voto) || null,
		created_at: riga.created_at,
		at: riga.created_at
	};
}

/** Le formule attive, per il ripiego e per il pannello. */
export async function caricaFormule(soloAttive = true): Promise<Formula[]> {
	let q = supabase.from('formule').select('*').order('ordine').order('created_at');
	if (soloAttive) q = q.eq('attiva', true);
	const { data, error } = await q;
	if (error) throw error;
	return (data ?? []) as Formula[];
}

export async function caricaOversharing(
	ioId: string | null,
	limite = 60
): Promise<PostOversharing[]> {
	const [righe, formule] = await Promise.all([
		supabase.from('oversharing').select(SELECT).order('created_at', { ascending: false }).limit(limite),
		// Se le formule non arrivano si va avanti lo stesso: quasi tutti i post
		// se la portano dietro, e per gli altri c'e' «X dice:».
		caricaFormule().catch(() => [] as Formula[])
	]);
	if (righe.error) throw righe.error;
	return ((righe.data ?? []) as unknown as RigaOversharing[]).map((r) => aPost(r, ioId, formule));
}

/** Il nome al posto della X. Se la X non c'e', il nome va davanti. */
export function conIlNome(formula: string, nome: string): string {
	return /\bX\b/.test(formula) ? formula.replace(/\bX\b/, nome) : `${nome} ${formula}`;
}

export const LIMITE = 280;

export async function pubblica(testo: string): Promise<string> {
	const { data, error } = await supabase.rpc('pubblica_oversharing', { p_testo: testo });
	if (error) throw error;
	return data as string;
}

/** Ripremere lo stesso pulsante toglie il voto. Restituisce com'e' rimasto. */
export async function vota(id: string, voto: 'chic' | 'cheap'): Promise<'chic' | 'cheap' | null> {
	const { data, error } = await supabase.rpc('vota_oversharing', {
		p_oversharing: id,
		p_voto: voto
	});
	if (error) throw error;
	return (data as 'chic' | 'cheap' | null) ?? null;
}

export async function butta(id: string) {
	const { error } = await supabase.from('oversharing').delete().eq('id', id);
	if (error) throw error;
}

// --- il pannello ------------------------------------------------------------

export async function aggiungiFormula(testo: string, ordine: number) {
	const { error } = await supabase.from('formule').insert({ testo, ordine });
	if (error) throw error;
}

export async function cambiaFormula(id: string, campi: Partial<Formula>) {
	const { error } = await supabase.from('formule').update(campi).eq('id', id);
	if (error) throw error;
}

export async function togliFormula(id: string) {
	const { error } = await supabase.from('formule').delete().eq('id', id);
	if (error) throw error;
}

/**
 * L'ordine si riscrive tutto insieme: spostarne una sola vorrebbe dire
 * rinumerare a mano quelle in mezzo, e basta un aggiornamento andato male per
 * ritrovarsi con due formule allo stesso posto.
 */
export async function riordinaFormule(ids: string[]) {
	for (const [i, id] of ids.entries()) {
		const { error } = await supabase.from('formule').update({ ordine: i + 1 }).eq('id', id);
		if (error) throw error;
	}
}
