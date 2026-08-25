import { browser } from '$app/environment';
import { get, set } from 'idb-keyval';
import { rete } from '$lib/state/rete.svelte';

/**
 * L'ultima risposta buona di ogni lettura, tenuta da parte su IndexedDB.
 *
 * Senza questo l'app moriva al primo fetch fallito: il layout mostrava
 * "Non riesco a parlare con il database" a tutto schermo e non si arrivava
 * nemmeno alla schermata di cattura. Ora una lettura senza linea ripesca
 * l'ultimo risultato noto, l'app resta in piedi e la striscia in cima dice
 * di quando sono i dati.
 *
 * Si ripiega su QUALSIASI errore, non solo su quelli di rete: se il database
 * risponde male, dei dati vecchi valgono comunque piu' di una schermata di
 * errore in vacanza. Se pero' in cache non c'e' niente — primo avvio senza
 * linea — l'errore risale come prima, perche' li' non c'e' niente da mostrare.
 */
const PREFISSO = 'cache:';

interface Conserva<T> {
	dati: T;
	quando: number;
}

export async function conCache<T>(chiave: string, leggi: () => Promise<T>): Promise<T> {
	// Se il telefono sa gia' di non avere linea, tentare la rete e aspettare
	// che fallisca e' tempo buttato: si va dritti alla cache. Con sette
	// letture in fila all'apertura di una schermata la differenza si vede.
	if (browser && !navigator.onLine) {
		const salvato = await get<Conserva<T>>(PREFISSO + chiave);
		if (salvato) {
			rete.vecchi(salvato.quando);
			return salvato.dati;
		}
	}

	try {
		const dati = await leggi();
		// $state.snapshot non serve: questi oggetti arrivano da PostgREST e
		// non sono ancora passati da nessuna rune. Sono clonabili come sono.
		await set(PREFISSO + chiave, { dati, quando: Date.now() } satisfies Conserva<T>);
		rete.freschi();
		return dati;
	} catch (e) {
		const salvato = await get<Conserva<T>>(PREFISSO + chiave);
		if (!salvato) throw e;
		rete.vecchi(salvato.quando);
		return salvato.dati;
	}
}
