import { supabase } from '$lib/supabase';
import { notificaEvento } from '$lib/notifica';
import type { Voto } from '$lib/types';

/** Tutte le regole vivono nel database: qui si bussa e basta. */

export async function apriContestazione(captureId: string, ioId: string, motivo?: string) {
	const { data, error } = await supabase.rpc('apri_contestazione', {
		p_capture: captureId,
		p_contestante: ioId,
		p_motivo: motivo ?? null
	});
	if (error) throw error;
	notificaEvento('contestazione_aperta', data as string);
	return data as string;
}

export async function vota(contestId: string, ioId: string, voto: Voto) {
	const { data, error } = await supabase.rpc('vota_contestazione', {
		p_contest: contestId,
		p_user: ioId,
		p_voto: voto
	});
	if (error) throw error;
	// vota_contestazione restituisce lo stato risultante: se il voto ha
	// chiuso la partita, l'esito va raccontato a tutti.
	if (data && data !== 'aperta') notificaEvento('contestazione_chiusa', contestId);
	return data as string;
}

export async function inviaCroquembouche(
	da: string,
	a: string,
	importo: number,
	causale?: string
) {
	const { data, error } = await supabase.rpc('invia_croquembouche', {
		p_from: da,
		p_to: a,
		p_importo: importo,
		p_causale: causale ?? null
	});
	if (error) throw error;
	notificaEvento('scambio', data as string);
	return data as string;
}
