import { supabase } from '$lib/supabase';
import type { Capture, RigaClassifica, User, VoceDex } from '$lib/types';

/** La griglia intera: uguale per tutti, quindi una query sola. */
export async function caricaDex(): Promise<VoceDex[]> {
	const { data, error } = await supabase.from('v_dex').select('*').order('nome');
	if (error) throw error;
	return (data ?? []) as VoceDex[];
}

export interface MiaVoce {
	item_id: string;
	quante: number;
	ultima: string;
}

/** Cosa ha sbloccato un giocatore, e quante volte. */
export async function mieCatture(userId: string): Promise<Map<string, MiaVoce>> {
	const { data, error } = await supabase
		.from('captures')
		.select('item_id, timestamp')
		.eq('user_id', userId)
		.neq('stato', 'invalidato');
	if (error) throw error;

	const mappa = new Map<string, MiaVoce>();
	for (const r of (data ?? []) as { item_id: string; timestamp: string }[]) {
		const voce = mappa.get(r.item_id);
		if (voce) {
			voce.quante++;
			if (r.timestamp > voce.ultima) voce.ultima = r.timestamp;
		} else {
			mappa.set(r.item_id, { item_id: r.item_id, quante: 1, ultima: r.timestamp });
		}
	}
	return mappa;
}

/** Chi altro del gruppo ha preso questo elemento. */
export async function catturePerItem(
	itemId: string
): Promise<(Capture & { autore: User })[]> {
	const { data, error } = await supabase
		.from('captures')
		.select('*, autore:users(*)')
		.eq('item_id', itemId)
		.neq('stato', 'invalidato')
		.order('timestamp', { ascending: true });
	if (error) throw error;
	return (data ?? []) as unknown as (Capture & { autore: User })[];
}

export async function caricaClassifica(): Promise<RigaClassifica[]> {
	const { data, error } = await supabase.from('v_classifica').select('*');
	if (error) throw error;
	return (data ?? []) as RigaClassifica[];
}

export async function caricaConfig(): Promise<Record<string, number>> {
	const { data, error } = await supabase.from('game_config').select('chiave, valore');
	if (error) throw error;
	return Object.fromEntries(
		((data ?? []) as { chiave: string; valore: number }[]).map((r) => [r.chiave, r.valore])
	);
}
