import { supabase } from '$lib/supabase';
import type { Coccarda } from './coccarde';

/**
 * Le stagioni, e la pagina che le chiude.
 *
 * Tutto quello che c'e' qui dentro e' gia' congelato nel database: la
 * classifica di quella stagione, le coccarde, la foto tenuta da parte. Non si
 * ricalcola niente — il Wrapped e' un ricordo, e un ricordo che cambia ogni
 * volta che lo guardi non e' un ricordo.
 */

export interface Wrapped {
	stagione: number;
	inizio: string;
	fine: string;
	chiusa_at: string;
	/** Dopo questo momento le foto si possono cancellare comunque. */
	scade: string;
	visto_da_me: boolean;
	visto_da: number;
	giocatori: number;
}

export interface RigaStagione {
	user_id: string;
	acquisiti: number;
	penalita: number;
	punti: number;
	posizione: number;
}

export interface FotoStagione {
	user_id: string;
	foto_url: string;
	item_nome: string;
	mi_piace: number;
}

/** L'ultima stagione chiusa, o null se non ce n'e' ancora nessuna. */
export async function wrapped(): Promise<Wrapped | null> {
	const { data, error } = await supabase.from('v_wrapped').select('*').maybeSingle();
	if (error) throw error;
	return (data as Wrapped) ?? null;
}

export async function classificaStagione(stagione: number): Promise<RigaStagione[]> {
	const { data, error } = await supabase
		.from('stagione_saldi')
		.select('user_id, acquisiti, penalita, punti, posizione')
		.eq('stagione', stagione)
		.order('posizione');
	if (error) throw error;
	return (data ?? []) as RigaStagione[];
}

export async function coccardeStagione(stagione: number): Promise<Coccarda[]> {
	const { data, error } = await supabase
		.from('coccarde')
		.select('*')
		.eq('stagione', stagione)
		.order('tipo')
		.order('chiave');
	if (error) throw error;
	return (data ?? []) as Coccarda[];
}

export async function fotoStagione(stagione: number): Promise<FotoStagione[]> {
	const { data, error } = await supabase
		.from('stagione_foto')
		.select('user_id, foto_url, item_nome, mi_piace')
		.eq('stagione', stagione)
		.order('mi_piace', { ascending: false });
	if (error) throw error;
	return (data ?? []) as FotoStagione[];
}

/**
 * Segna che l'hai visto. E' anche il gesto che avvicina la cancellazione
 * delle foto: quando l'hanno visto tutti, si puo' svuotare.
 */
export async function segnaWrappedVisto(stagione: number): Promise<void> {
	const { error } = await supabase.rpc('segna_wrapped_visto', { p_stagione: stagione });
	if (error) throw error;
}
