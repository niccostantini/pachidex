import { supabase } from '$lib/supabase';
import type { Contest, Item, Transfer, User } from '$lib/types';
import type { RigaItem } from '$lib/game/csv';

/* --- elementi -------------------------------------------------------------- */

export async function tuttiGliItem(): Promise<Item[]> {
	const { data, error } = await supabase
		.from('items')
		.select('*')
		.order('categoria')
		.order('nome');
	if (error) throw error;
	return (data ?? []) as Item[];
}

export async function salvaItem(item: Partial<Item> & { nome: string }) {
	if (item.id) {
		const { error } = await supabase.from('items').update(item).eq('id', item.id);
		if (error) throw error;
		return item.id;
	}
	const { data, error } = await supabase.from('items').insert(item).select('id').single();
	if (error) throw error;
	return (data as { id: string }).id;
}

export async function attivaItem(id: string, attivo: boolean) {
	const { error } = await supabase.from('items').update({ attivo }).eq('id', id);
	if (error) throw error;
}

export async function eliminaItem(id: string) {
	const { error } = await supabase.from('items').delete().eq('id', id);
	if (error) throw error;
}

const LOTTO = 100;

const motivoErrore = (e: { code?: string; message: string }) =>
	e.code === '23505' ? 'esiste gia a database' : e.message;

/**
 * Import parziale, ma non una riga per volta: un CSV da cento elementi su rete
 * mobile diventerebbe cento andate e ritorni. Si spedisce a lotti, e solo se
 * un lotto viene respinto lo si ripete riga per riga per capire chi e' stato.
 * Cosi' il caso normale e' veloce e quello sporco resta preciso.
 */
export async function importaItem(
	righe: RigaItem[],
	onProgresso?: (fatte: number, totali: number) => void
): Promise<{ inserite: number; falliti: { nome: string; motivo: string }[] }> {
	let inserite = 0;
	const falliti: { nome: string; motivo: string }[] = [];

	for (let i = 0; i < righe.length; i += LOTTO) {
		const lotto = righe.slice(i, i + LOTTO);
		const { error } = await supabase.from('items').insert(lotto);

		if (error) {
			for (const riga of lotto) {
				const { error: singolo } = await supabase.from('items').insert(riga);
				if (singolo) falliti.push({ nome: riga.nome, motivo: motivoErrore(singolo) });
				else inserite++;
			}
		} else {
			inserite += lotto.length;
		}

		onProgresso?.(Math.min(i + LOTTO, righe.length), righe.length);
	}

	return { inserite, falliti };
}

/* --- configurazione -------------------------------------------------------- */

export async function salvaConfig(valori: Record<string, number>) {
	for (const [chiave, valore] of Object.entries(valori)) {
		const { error } = await supabase
			.from('game_config')
			.update({ valore })
			.eq('chiave', chiave);
		if (error) throw error;
	}
}

/* --- giocatori -------------------------------------------------------------- */

export async function salvaUtente(u: Partial<User> & { nome: string }) {
	if (u.id) {
		const { error } = await supabase.from('users').update(u).eq('id', u.id);
		if (error) throw error;
		return u.id;
	}
	const { data, error } = await supabase.from('users').insert(u).select('id').single();
	if (error) throw error;
	return (data as { id: string }).id;
}

export async function eliminaUtente(id: string) {
	const { error } = await supabase.from('users').delete().eq('id', id);
	if (error) throw error;
}

/* Gli avatar non si caricano piu': sono sei sprite cablati nel codice,
   vedi src/lib/avatars.ts. */

/* --- contestazioni ---------------------------------------------------------- */

export async function tutteLeContestazioni() {
	const { data, error } = await supabase
		.from('contests')
		.select(
			`*,
			 contestante:users!contests_contestante_id_fkey(*),
			 votes(*),
			 cattura:captures(*, item:items(*), autore:users(*))`
		)
		.order('created_at', { ascending: false });
	if (error) throw error;
	return data ?? [];
}

/**
 * Override d'emergenza: l'admin chiude a mano quello che il voto non ha
 * risolto. Nessuna magia, si scrive lo stato finale e si allinea la cattura.
 */
export async function forzaEsito(
	contest: Contest,
	esito: 'chiusa_valido' | 'chiusa_non_valido'
) {
	const { error } = await supabase
		.from('contests')
		.update({ stato: esito, risolta_at: new Date().toISOString() })
		.eq('id', contest.id);
	if (error) throw error;

	const { error: err2 } = await supabase
		.from('captures')
		.update({ stato: esito === 'chiusa_non_valido' ? 'invalidato' : 'valido' })
		.eq('id', contest.capture_id);
	if (err2) throw err2;
}

/** Annulla del tutto: la contestazione sparisce e la cattura torna valida. */
export async function annullaContestazione(contest: Contest) {
	const { error } = await supabase.from('contests').delete().eq('id', contest.id);
	if (error) throw error;
	const { error: err2 } = await supabase
		.from('captures')
		.update({ stato: 'valido' })
		.eq('id', contest.capture_id);
	if (err2) throw err2;
}

/* --- scambi ------------------------------------------------------------------ */

export async function tuttiGliScambi(): Promise<Transfer[]> {
	const { data, error } = await supabase
		.from('transfers')
		.select(
			'*, mittente:users!transfers_from_user_id_fkey(nome), destinatario:users!transfers_to_user_id_fkey(nome)'
		)
		.order('created_at', { ascending: false });
	if (error) throw error;
	return (data ?? []) as unknown as Transfer[];
}

export async function annullaScambio(id: string, annullato: boolean) {
	const { error } = await supabase.from('transfers').update({ annullato }).eq('id', id);
	if (error) throw error;
}

/** Una cattura cancellata a mano dall'admin, quando proprio serve. */
export async function eliminaCattura(id: string) {
	const { error } = await supabase.from('captures').delete().eq('id', id);
	if (error) throw error;
}

/* --- azzeramento ------------------------------------------------------------ */

export interface RigaAzzerata {
	tabella: string;
	cancellate: number;
}

/**
 * Ricomincia il gioco da capo. Cancella cronaca e sfiziosita' in una sola
 * transazione lato database; giocatori e configurazione restano.
 *
 * Le foto gia' caricate su R2 non vengono toccate: restano li' come file
 * orfani, senza piu' niente che le referenzi. Sono pochi megabyte su un
 * bucket da 10 GB gratuiti, e cancellarle richiederebbe un endpoint server
 * apposta — se un giorno danno fastidio si svuota la cartella dal pannello
 * Cloudflare.
 */
export async function azzeraGioco(): Promise<RigaAzzerata[]> {
	const { data, error } = await supabase.rpc('azzera_gioco');
	if (error) throw error;
	return (data ?? []) as RigaAzzerata[];
}

/**
 * Crea un account nuovo. Passa dall'endpoint sul server perche' creare utenti
 * richiede la chiave di servizio, che nel browser non puo' stare.
 *
 * Il token della sessione va mandato a mano: e' con quello che il server
 * verifica che chi chiede sia davvero un admin.
 */
export async function creaAccount(dati: {
	nome: string;
	password: string;
	is_admin?: boolean;
	sola_lettura?: boolean;
	nascosto?: boolean;
}) {
	const { data: sessione } = await supabase.auth.getSession();
	const token = sessione.session?.access_token;
	if (!token) throw new Error('Sessione scaduta: rientra');

	const risposta = await fetch('/api/utenti', {
		method: 'POST',
		headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
		body: JSON.stringify(dati)
	});

	if (!risposta.ok) {
		const detto = await risposta.json().catch(() => null);
		throw new Error(detto?.message ?? `L'account non si crea (${risposta.status})`);
	}
	return risposta.json();
}

/** Cambia la password di un giocatore. Solo un admin ci riesce. */
export async function cambiaPassword(id: string, password: string) {
	const { data: sessione } = await supabase.auth.getSession();
	const token = sessione.session?.access_token;
	if (!token) throw new Error('Sessione scaduta: rientra');

	const risposta = await fetch('/api/utenti', {
		method: 'PATCH',
		headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
		body: JSON.stringify({ id, password })
	});

	if (!risposta.ok) {
		const detto = await risposta.json().catch(() => null);
		throw new Error(detto?.message ?? `La password non si cambia (${risposta.status})`);
	}
}

/** Una password robusta da passare a voce: niente caratteri che si confondono. */
export function passwordACaso(lunghezza = 16): string {
	const min = 'abcdefghijkmnopqrstuvwxyz';
	const mai = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
	const num = '23456789';
	const seg = '!@#%&*+-';
	const pesca = (x: string) => x[Math.floor(Math.random() * x.length)];
	const p = [pesca(mai), pesca(min), pesca(num), pesca(seg)];
	const tutto = min + mai + num + seg;
	while (p.length < lunghezza) p.push(pesca(tutto));
	for (let i = p.length - 1; i > 0; i--) {
		const j = Math.floor(Math.random() * (i + 1));
		[p[i], p[j]] = [p[j], p[i]];
	}
	return p.join('');
}

/* --- notifiche -------------------------------------------------------------- */

export interface StatoNotifiche {
	app_url: string | null;
	/** Il segreto non torna mai indietro: si sa solo se c'e'. */
	cron_secret_impostato: boolean;
	configurate: boolean;
	lavori_accesi: boolean;
	dispositivi: number;
}

export async function statoNotifiche(): Promise<StatoNotifiche> {
	const { data, error } = await supabase.rpc('stato_notifiche');
	if (error) throw error;
	return (Array.isArray(data) ? data[0] : data) as StatoNotifiche;
}

/** Il segreto si manda solo se cambia: vuoto vuol dire "lascia com'e'". */
export async function impostaNotifiche(appUrl: string, cronSecret?: string) {
	const { error } = await supabase.rpc('imposta_notifiche', {
		p_app_url: appUrl,
		p_cron_secret: cronSecret?.trim() ? cronSecret.trim() : null
	});
	if (error) throw error;
}

export async function accendiNotifiche(accese: boolean) {
	const { error } = await supabase.rpc('accendi_notifiche', { p_accese: accese });
	if (error) throw error;
}
