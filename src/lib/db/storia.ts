import { supabase } from '$lib/supabase';
import { conCache } from '$lib/db/cache';

export interface Capitolo {
	numero: number;
	/** null finche' il capitolo e' bloccato: il server non lo manda proprio. */
	titolo: string | null;
	soglia: number;
	sbloccato_at: string | null;
	sbloccato: boolean;
}

export interface StatoStoria {
	punti: number;
	capitoli: Capitolo[];
	ultimoSbloccato: Capitolo | null;
	prossimo: Capitolo | null;
	/** Quanto manca al prossimo capitolo, 0 se sono tutti sbloccati. */
	mancano: number;
	/** Avanzamento nel tratto corrente, da 0 a 1. */
	avanzamento: number;
}

export async function caricaStoria(): Promise<StatoStoria> {
	return conCache('storia', async () => {
	const [{ data: barra, error: errBarra }, { data: capitoli, error: errCap }] = await Promise.all([
		supabase.from('v_punti_storia').select('punti').single(),
		supabase.rpc('capitoli')
	]);

	// Senza questo controllo una lettura fallita passava per un gioco appena
	// cominciato: zero punti, nessun capitolo, la barra che si svuota da sola
	// sotto gli occhi di tutti.
	if (errBarra || errCap) throw errBarra ?? errCap;

	const punti = (barra?.punti as number) ?? 0;
	const elenco = ((capitoli ?? []) as Capitolo[]).sort((a, b) => a.numero - b.numero);

	const sbloccati = elenco.filter((c) => c.sbloccato);
	const ultimoSbloccato = sbloccati.at(-1) ?? null;
	const prossimo = elenco.find((c) => !c.sbloccato) ?? null;

	// La barra misura il tratto fra il capitolo raggiunto e il prossimo, non
	// il totale: 340 su 450 dice qualcosa, 2840 non dice niente.
	const base = ultimoSbloccato?.soglia ?? 0;
	const tratto = prossimo ? prossimo.soglia - base : 0;
	const fatto = punti - base;

	return {
		punti,
		capitoli: elenco,
		ultimoSbloccato,
		prossimo,
		mancano: prossimo ? Math.max(prossimo.soglia - punti, 0) : 0,
		avanzamento: tratto > 0 ? Math.min(Math.max(fatto / tratto, 0), 1) : 1
	};
	});
}

/* --- pannello admin -------------------------------------------------------- */
/* story_chapters ha le RLS accese e nessuna policy — i titoli bloccati sono
   l'unica cosa da non far vedere — quindi anche il pannello ci arriva solo
   attraverso funzioni dedicate. */

/** L'admin li vede tutti, titoli compresi: e' lui che li scrive. */
export async function capitoliAdmin(): Promise<Capitolo[]> {
	const { data, error } = await supabase.rpc('capitoli_admin');
	if (error) throw error;
	return ((data ?? []) as Capitolo[])
		.map((c) => ({ ...c, sbloccato: !!c.sbloccato_at }))
		.sort((a, b) => a.numero - b.numero);
}

export async function salvaCapitolo(
	numero: number,
	campi: { soglia?: number; titolo?: string | null }
) {
	const titolo = campi.titolo?.trim() ?? null;
	const { error } = await supabase.rpc('imposta_capitolo', {
		p_numero: numero,
		p_soglia: campi.soglia ?? null,
		p_titolo: titolo || null,
		// Distinguere "non toccare" da "svuota": senza questo un titolo
		// cancellato tornerebbe indietro al salvataggio successivo.
		p_pulisci_titolo: campi.titolo !== undefined && !titolo
	});
	if (error) throw error;
}
