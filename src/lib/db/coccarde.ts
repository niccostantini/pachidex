import { supabase } from '$lib/supabase';
import { conCache } from './cache';

/**
 * Le coccarde: quello che resta quando la stagione si porta via tutto il
 * resto. Non si ricalcolano mai — vengono da una classifica e da titoli che
 * il giorno dopo non esistono piu' — quindi si leggono e basta.
 */
export interface Coccarda {
	id: string;
	user_id: string;
	stagione: number;
	tipo: 'podio' | 'titolo';
	chiave: string;
	etichetta: string;
	quanto: number | null;
	foto_url: string | null;
	assegnata_at: string;
}

/** Le coccarde di una persona, dalla piu' recente. */
export async function coccardeDi(userId: string): Promise<Coccarda[]> {
	return conCache(`coccarde:${userId}`, async () => {
		const { data, error } = await supabase
			.from('coccarde')
			.select('*')
			.eq('user_id', userId)
			.order('stagione', { ascending: false })
			.order('tipo');
		if (error) throw error;
		return (data ?? []) as Coccarda[];
	});
}
