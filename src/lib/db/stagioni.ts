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

/* --- dal pannello ----------------------------------------------------------- */

export interface Stagione {
	numero: number;
	inizio: string;
	fine: string;
	chiusa_at: string | null;
	foto_cancellate_at: string | null;
}

export interface DaSvuotare {
	stagione: number;
	chiusa_at: string;
	scade: string;
	visto_da: number;
	giocatori: number;
	pronta: boolean;
	catture: number;
}

export async function stagioni(): Promise<Stagione[]> {
	const { data, error } = await supabase
		.from('stagioni')
		.select('numero, inizio, fine, chiusa_at, foto_cancellate_at')
		.order('numero', { ascending: false });
	if (error) throw error;
	return (data ?? []) as Stagione[];
}

export async function daSvuotare(): Promise<DaSvuotare[]> {
	const { data, error } = await supabase.from('v_da_svuotare').select('*');
	if (error) throw error;
	return (data ?? []) as DaSvuotare[];
}

/** Quante sfiziosita' sono in gioco, per categoria. */
export async function catalogoDiStagione(numero: number): Promise<number> {
	const { count, error } = await supabase
		.from('stagione_items')
		.select('item_id', { count: 'exact', head: true })
		.eq('stagione', numero);
	if (error) throw error;
	return count ?? 0;
}

export async function apriStagione(giorni = 14): Promise<number> {
	const { data, error } = await supabase.rpc('apri_stagione', { p_giorni: giorni });
	if (error) throw error;
	return data as number;
}

export async function chiudiStagione(giorni = 14): Promise<number> {
	const { data, error } = await supabase.rpc('chiudi_stagione', { p_giorni: giorni });
	if (error) throw error;
	return data as number;
}

/**
 * Lo svuotamento passa dal server: le chiavi di R2 stanno li', e il database
 * da solo non sa togliere un file da un secchio che non conosce.
 */
export async function svuotaStagione(numero: number): Promise<{ catture: number; tolte: number }> {
	const { data: sessione } = await supabase.auth.getSession();
	const token = sessione.session?.access_token;
	if (!token) throw new Error('Sessione scaduta');

	const risposta = await fetch('/api/stagione/svuota', {
		method: 'POST',
		headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
		body: JSON.stringify({ stagione: numero })
	});
	const esito = await risposta.json().catch(() => null);
	if (!risposta.ok) throw new Error(esito?.message ?? `Errore ${risposta.status}`);
	return esito;
}
