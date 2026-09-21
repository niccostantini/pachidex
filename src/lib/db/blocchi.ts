import { supabase } from '$lib/supabase';

/**
 * I blocchi «?» sulla mappa.
 *
 * Dove sono, e se sono premi o trappole, lo sa solo il database: il telefono
 * riceve la posta e basta, e il d20 lo tira il server. Vedi la 0056.
 */

export type Posta = 'piccola' | 'media' | 'grossa' | 'enorme';

export const POSTE: Posta[] = ['piccola', 'media', 'grossa', 'enorme'];

export interface Blocco {
	luogo_id: string;
	nome: string;
	lat: number;
	lng: number;
	posta: Posta;
	croquembouche: number;
	cd: number;
	scade_at: string;
}

export interface Esito {
	tiro: number;
	cd: number;
	posta: Posta;
	trappola: boolean;
	riuscito: boolean;
	/** Con il segno: quanto e' entrato o uscito dal portacroque. */
	croquembouche: number;
}

/** Il database rifiuta riquadri piu' grandi di cosi': la mappa non li chiede. */
export const ZOOM_MINIMO = 14;

export async function blocchiVicini(sud: number, ovest: number, nord: number, est: number) {
	const { data, error } = await supabase.rpc('blocchi_vicini', {
		p_sud: sud,
		p_ovest: ovest,
		p_nord: nord,
		p_est: est
	});
	if (error) throw error;
	return (data ?? []) as Blocco[];
}

export async function apriBlocco(luogo: string, lat: number, lng: number): Promise<Esito> {
	const { data, error } = await supabase.rpc('apri_blocco', { p_luogo: luogo, p_lat: lat, p_lng: lng });
	if (error) throw error;
	return (data as Esito[])[0];
}

export async function segnalaLuogo(luogo: string): Promise<void> {
	const { error } = await supabase.rpc('segnala_luogo', { p_luogo: luogo });
	if (error) throw error;
}

/* --- pannello ------------------------------------------------------------- */

export interface RigaPosta {
	posta: Posta;
	croquembouche: number;
	cd: number;
	peso: number;
}

export interface LuogoSegnalato {
	id: string;
	nome: string;
	tipo: string;
	lat: number;
	lng: number;
	attivo: boolean;
	segnalazioni: number;
	ultima: string | null;
}

export async function caricaPoste(): Promise<RigaPosta[]> {
	const { data, error } = await supabase
		.from('blocchi_poste')
		.select('posta, croquembouche, cd, peso')
		.order('croquembouche');
	if (error) throw error;
	return (data ?? []) as RigaPosta[];
}

/** Le quattro poste sono fisse: si aggiornano, non si aggiungono ne' si tolgono. */
export async function salvaPoste(poste: RigaPosta[]): Promise<void> {
	const pulite = poste.map((p) => ({
		posta: p.posta,
		croquembouche: Math.max(1, Math.round(p.croquembouche)),
		cd: Math.min(20, Math.max(1, Math.round(p.cd))),
		peso: Math.max(0, Math.round(p.peso))
	}));
	const { error } = await supabase.from('blocchi_poste').upsert(pulite);
	if (error) throw error;
}

export async function luoghiSegnalati(): Promise<LuogoSegnalato[]> {
	const { data, error } = await supabase
		.from('v_luoghi_segnalati')
		.select('*')
		.order('segnalazioni', { ascending: false });
	if (error) throw error;
	return (data ?? []) as LuogoSegnalato[];
}

export async function rimettiLuogo(luogo: string): Promise<void> {
	const { error } = await supabase.rpc('rimetti_luogo', { p_luogo: luogo });
	if (error) throw error;
}

export async function contaLuoghi(): Promise<{ totali: number; attivi: number }> {
	const [tutti, accesi] = await Promise.all([
		supabase.from('luoghi').select('id', { count: 'exact', head: true }),
		supabase.from('luoghi').select('id', { count: 'exact', head: true }).eq('attivo', true)
	]);
	if (tutti.error) throw tutti.error;
	if (accesi.error) throw accesi.error;
	return { totali: tutti.count ?? 0, attivi: accesi.count ?? 0 };
}
