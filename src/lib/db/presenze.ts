import { supabase } from '$lib/supabase';

/**
 * I premi di chi torna.
 *
 * Il conto dei giorni di fila lo tiene il database: il telefono dice solo
 * "sono qui", e si sente rispondere a che punto sta. Se lo calcolasse il
 * client basterebbe cambiare l'orologio per farsi una striscia di sette
 * giorni in sette minuti.
 */

export interface Presenza {
	giorno: string;
	striscia: number;
	croquembouche: number;
	/** Quanto varrebbe domani, se si torna. */
	prossimo: number;
	/** Quante volte si e' gia' salita la scala: 1 la prima, 2 dopo il giro. */
	giro: number;
	/** false se oggi era gia' stata segnata: niente festa una seconda volta. */
	nuova: boolean;
}

export interface Gradino {
	passo: number;
	croquembouche: number;
}

export interface RigaPresenza {
	user_id: string;
	nome: string;
	striscia: number;
	ultimo_giorno: string | null;
	giorni: number;
	croquembouche: number;
}

/**
 * Segna che oggi ci sei. Restituisce null quando non c'e' niente da dire:
 * premi spenti, gioco congelato, o chi guarda da fuori.
 */
export async function segnaPresenza(): Promise<Presenza | null> {
	const { data, error } = await supabase.rpc('segna_presenza');
	if (error) throw error;
	const righe = (data ?? []) as Presenza[];
	return righe[0] ?? null;
}

export async function scalaPresenze(): Promise<Gradino[]> {
	const { data, error } = await supabase
		.from('presenze_scala')
		.select('passo, croquembouche')
		.order('passo');
	if (error) throw error;
	return (data ?? []) as Gradino[];
}

export async function presenzeDiTutti(): Promise<RigaPresenza[]> {
	const { data, error } = await supabase
		.from('v_presenze')
		.select('*')
		.order('striscia', { ascending: false });
	if (error) throw error;
	return (data ?? []) as RigaPresenza[];
}

/**
 * Riscrive la scala per intero: si cancella e si reinserisce.
 *
 * Aggiornare gradino per gradino vorrebbe dire tenere il conto di quali sono
 * spariti, e una scala accorciata lascerebbe in giro i gradini di prima.
 */
export async function salvaScala(gradini: Gradino[]): Promise<void> {
	const puliti = gradini
		.map((g, i) => ({ passo: i + 1, croquembouche: Math.max(0, Math.round(g.croquembouche)) }))
		.filter((g) => Number.isFinite(g.croquembouche));

	const { error: errCanc } = await supabase.from('presenze_scala').delete().gte('passo', 1);
	if (errCanc) throw errCanc;
	if (!puliti.length) return;

	const { error } = await supabase.from('presenze_scala').insert(puliti);
	if (error) throw error;
}
