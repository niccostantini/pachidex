import { supabase } from '$lib/supabase';
import { conCache } from '$lib/db/cache';

/**
 * I set: gruppi di sfiziosita' che, completati, valgono Croquembouche a chi
 * li chiude e puntini alla barra della storia, che e' di tutti.
 *
 * Servono a dare uno scopo alla coda lunga — quelle voci che da sole valgono
 * dieci punti e che altrimenti non guarderebbe nessuno.
 *
 * Il calcolo sta tutto nel database: qui si legge e basta.
 */
export interface Requisito {
	id: string;
	set_id: string;
	tipo: 'parola' | 'tutte_parola' | 'categoria' | 'orario' | 'tutti_taggati';
	valore: string | null;
	ora_da: number | null;
	ora_a: number | null;
	etichetta: string;
	ordine: number;
}

export interface SetGioco {
	id: string;
	nome: string;
	descrizione: string | null;
	croquembouche: number;
	punti_storia: number;
	stesso_giorno: boolean;
	giorno: string | null;
	ordine: number;
	attivo: boolean;
}

/** Un set con dentro come sta messa la giocatrice che guarda. */
export interface SetConStato extends SetGioco {
	requisiti: (Requisito & { fatto: boolean })[];
	fatti: number;
	totale: number;
	completo: boolean;
}

export async function caricaSet(userId: string | null): Promise<SetConStato[]> {
	return conCache(`set:${userId ?? 'anonimo'}`, async () => {
		const [sets, requisiti, stati, soddisfatti] = await Promise.all([
			supabase.from('game_sets').select('*').eq('attivo', true).order('ordine'),
			supabase.from('set_requisiti').select('*').order('ordine'),
			userId
				? supabase.from('v_set_stato').select('*').eq('user_id', userId)
				: Promise.resolve({ data: [], error: null }),
			userId
				? supabase.from('v_set_soddisfatti').select('requisito_id').eq('user_id', userId)
				: Promise.resolve({ data: [], error: null })
		]);

		if (sets.error) throw sets.error;
		if (requisiti.error) throw requisiti.error;
		if (stati.error) throw stati.error;
		if (soddisfatti.error) throw soddisfatti.error;

		const perSet = new Map(
			((stati.data ?? []) as { set_id: string; fatti: number; totale: number; completo: boolean }[]).map(
				(s) => [s.set_id, s]
			)
		);
		const fatti = new Set(
			((soddisfatti.data ?? []) as { requisito_id: string }[]).map((r) => r.requisito_id)
		);

		return ((sets.data ?? []) as SetGioco[]).map((s) => {
			const stato = perSet.get(s.id);
			const suoi = ((requisiti.data ?? []) as Requisito[]).filter((r) => r.set_id === s.id);
			return {
				...s,
				requisiti: suoi.map((r) => ({ ...r, fatto: fatti.has(r.id) })),
				fatti: stato?.fatti ?? 0,
				totale: stato?.totale ?? suoi.length,
				completo: stato?.completo ?? false
			};
		});
	});
}

/** La riga in fondo alla scheda: cosa vincola questo set, oltre ai requisiti. */
export function vincolo(s: SetGioco): string | null {
	if (s.giorno) {
		const d = new Date(s.giorno + 'T12:00:00');
		return `Solo il ${d.getDate()} ${d.toLocaleDateString('it-IT', { month: 'long' })}`;
	}
	if (s.stesso_giorno) return 'Tutto nella stessa giornata';
	return null;
}

/* --- pannello admin -------------------------------------------------------- */

/** L'admin li vede tutti, anche gli spenti, con dentro i requisiti. */
export async function setAdmin(): Promise<(SetGioco & { requisiti: Requisito[] })[]> {
	const [sets, requisiti] = await Promise.all([
		supabase.from('game_sets').select('*').order('ordine'),
		supabase.from('set_requisiti').select('*').order('ordine')
	]);
	if (sets.error) throw sets.error;
	if (requisiti.error) throw requisiti.error;

	return ((sets.data ?? []) as SetGioco[]).map((s) => ({
		...s,
		requisiti: ((requisiti.data ?? []) as Requisito[]).filter((r) => r.set_id === s.id)
	}));
}

export async function salvaSet(s: Partial<SetGioco> & { nome: string }) {
	const riga = {
		nome: s.nome,
		descrizione: s.descrizione || null,
		croquembouche: s.croquembouche ?? 30,
		punti_storia: s.punti_storia ?? 10,
		stesso_giorno: s.stesso_giorno ?? false,
		// Un campo data vuoto arriva come stringa vuota, che Postgres rifiuta.
		giorno: s.giorno || null,
		ordine: s.ordine ?? 0,
		attivo: s.attivo ?? true
	};
	const { data, error } = s.id
		? await supabase.from('game_sets').update(riga).eq('id', s.id).select().single()
		: await supabase.from('game_sets').insert(riga).select().single();
	if (error) throw error;
	return data as SetGioco;
}

export async function eliminaSet(id: string) {
	const { error } = await supabase.from('game_sets').delete().eq('id', id);
	if (error) throw error;
}

export async function salvaRequisito(r: Partial<Requisito> & { set_id: string; tipo: string }) {
	const riga = {
		set_id: r.set_id,
		tipo: r.tipo,
		// Solo "orario" usa le ore, solo gli altri usano il valore: si azzera
		// cio' che non serve, altrimenti restano rimasugli del tipo precedente.
		valore: r.tipo === 'orario' || r.tipo === 'tutti_taggati' ? null : r.valore || null,
		ora_da: r.tipo === 'orario' ? (r.ora_da ?? 0) : null,
		ora_a: r.tipo === 'orario' ? (r.ora_a ?? 24) : null,
		etichetta: r.etichetta || 'Requisito',
		ordine: r.ordine ?? 0
	};
	const { error } = r.id
		? await supabase.from('set_requisiti').update(riga).eq('id', r.id)
		: await supabase.from('set_requisiti').insert(riga);
	if (error) throw error;
}

export async function eliminaRequisito(id: string) {
	const { error } = await supabase.from('set_requisiti').delete().eq('id', id);
	if (error) throw error;
}

/**
 * Quante sfiziosita' aggancia una parola chiave, per far vedere subito
 * all'admin se ha scritto una parola che non becca niente — o che becca
 * mezzo PachiDex.
 */
export async function quanteCon(parola: string): Promise<number> {
	if (!parola.trim()) return 0;
	const { count, error } = await supabase
		.from('items')
		.select('*', { count: 'exact', head: true })
		.eq('attivo', true)
		.ilike('nome', `%${parola.trim()}%`);
	if (error) throw error;
	return count ?? 0;
}
