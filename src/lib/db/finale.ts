import { supabase } from '$lib/supabase';
import type { User } from '$lib/types';

/**
 * La cerimonia finale.
 *
 * Lo stato non vive nei telefoni: sta tutto su una riga di "finale". Ogni
 * telefono legge quella riga e l'orologio del server e sa cosa disegnare,
 * senza che nessuno faccia da capo. Se il telefono di chi ha avviato si
 * spegne, la serata va avanti lo stesso.
 */
export interface StatoFinale {
	id: string;
	fase: 'podio' | 'premi' | 'podio_finale';
	premio_numero: number | null;
	apertura: string | null;
	secondi_voto: number;
	secondi_pausa: number;
	chiusa_at: string | null;
}

export interface Premio {
	id: string;
	numero: number;
	domanda: string;
	croquembouche: number;
	attivo: boolean;
}

export interface Voto {
	premio_id: string;
	votante_id: string;
	votato_id: string;
}

export interface Esito {
	premio_id: string;
	vincitore_id: string | null;
	voti: number;
}

/** null quando la cerimonia non e' ancora cominciata. */
export async function statoFinale(): Promise<StatoFinale | null> {
	const { data, error } = await supabase.from('finale').select('*').limit(1).maybeSingle();
	if (error) throw error;
	return (data as StatoFinale) ?? null;
}

export async function premiAttivi(): Promise<Premio[]> {
	const { data, error } = await supabase
		.from('premi')
		.select('*')
		.eq('attivo', true)
		.order('numero');
	if (error) throw error;
	return (data ?? []) as Premio[];
}

export async function votiEEsiti(finaleId: string): Promise<{ voti: Voto[]; esiti: Esito[] }> {
	const [v, e] = await Promise.all([
		supabase.from('premi_voti').select('premio_id, votante_id, votato_id').eq('finale_id', finaleId),
		supabase.from('premi_esiti').select('premio_id, vincitore_id, voti').eq('finale_id', finaleId)
	]);
	if (v.error) throw v.error;
	if (e.error) throw e.error;
	return { voti: (v.data ?? []) as Voto[], esiti: (e.data ?? []) as Esito[] };
}

/**
 * Lo scarto fra l'orologio del telefono e quello del server, in millisecondi.
 *
 * Senza, un telefono avanti di due minuti vedrebbe scadere il tempo di voto
 * mentre gli altri stanno ancora scegliendo, e chiamerebbe la chiusura da
 * solo. Si chiede una volta all'apertura della pagina.
 */
export async function scartoOrologio(): Promise<number> {
	const prima = Date.now();
	const { data, error } = await supabase.rpc('adesso');
	if (error) return 0;
	// Meta' del giro di rete: e' un'approssimazione onesta e basta e avanza
	// per una premiazione.
	const viaggio = (Date.now() - prima) / 2;
	return new Date(data as string).getTime() + viaggio - Date.now();
}

/* --- azioni ---------------------------------------------------------------- */

export async function avviaFinale(): Promise<string> {
	const { data, error } = await supabase.rpc('avvia_finale');
	if (error) throw error;
	return data as string;
}

export async function cominciaPremi(finaleId: string) {
	const { error } = await supabase.rpc('comincia_premi', { p_finale: finaleId });
	if (error) throw error;
}

export async function vota(finaleId: string, premioId: string, ioId: string, votatoId: string) {
	const { error } = await supabase.rpc('vota_premio', {
		p_finale: finaleId,
		p_premio: premioId,
		p_votante: ioId,
		p_votato: votatoId
	});
	if (error) throw error;
}

/**
 * La chiamano tutti i telefoni insieme quando scade il minuto: la prima
 * assegna, le altre trovano l'esito gia' scritto e non fanno niente. Per
 * questo un errore qui si ingoia — e' quasi sempre "sono arrivato secondo".
 */
export async function chiudiPremio(finaleId: string, premioId: string) {
	await supabase.rpc('chiudi_premio', { p_finale: finaleId, p_premio: premioId }).then(
		() => {},
		() => {}
	);
}

export async function annullaFinale() {
	const { error } = await supabase.rpc('annulla_finale');
	if (error) throw error;
}

/**
 * Un canale per chi ascolta, e il nome va passato.
 *
 * Due canali con lo STESSO nome sullo stesso client si annullano a vicenda:
 * il layout (che sorveglia l'avvio) e la pagina della cerimonia ascoltano
 * tutti e due, e finche' si chiamavano uguale non arrivava niente a nessuno
 * — i voti si registravano sul database e gli schermi restavano fermi.
 */
export function sottoscriviFinale(onCambio: () => void, nome = 'cerimonia') {
	const canale = supabase.channel(nome);
	for (const table of ['finale', 'premi_voti', 'premi_esiti', 'premi']) {
		canale.on('postgres_changes', { event: '*', schema: 'public', table }, onCambio);
	}
	canale.subscribe();
	return () => void supabase.removeChannel(canale);
}

/* --- pannello -------------------------------------------------------------- */

export async function tuttiIPremi(): Promise<Premio[]> {
	const { data, error } = await supabase.from('premi').select('*').order('numero');
	if (error) throw error;
	return (data ?? []) as Premio[];
}

export async function salvaPremio(p: Partial<Premio> & { domanda: string; numero: number }) {
	const riga = {
		numero: p.numero,
		domanda: p.domanda,
		croquembouche: p.croquembouche ?? 40,
		attivo: p.attivo ?? true
	};
	const { error } = p.id
		? await supabase.from('premi').update(riga).eq('id', p.id)
		: await supabase.from('premi').insert(riga);
	if (error) throw error;
}

export async function eliminaPremio(id: string) {
	const { error } = await supabase.from('premi').delete().eq('id', id);
	if (error) throw error;
}

/** Chi ha gia' votato questo premio, per la fila di pallini in pagina. */
export function hannoVotato(voti: Voto[], premioId: string, utenti: User[]): User[] {
	const ids = new Set(voti.filter((v) => v.premio_id === premioId).map((v) => v.votante_id));
	return utenti.filter((u) => ids.has(u.id));
}
