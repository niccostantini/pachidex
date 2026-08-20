import { browser } from '$app/environment';
import { del, get, keys, set } from 'idb-keyval';
import { supabase } from '$lib/supabase';
import { idUnico } from '$lib/id';

/**
 * Coda di upload per quando il segnale non c'e' (succedera', vicino a
 * Vendicari). La foto resta su IndexedDB e riparte da sola appena la rete
 * torna, cosi' nessuno perde una cattura per colpa di una tacca.
 */
export interface CatturaInCoda {
	id: string;
	userId: string;
	itemId: string;
	nomeItem: string;
	blob: Blob;
	estensione: string;
	nota: string | null;
	lat: number | null;
	lng: number | null;
	creata: number;
	tentativi: number;
	ultimoErrore?: string;
	/** true quando il database ha rifiutato per regola: inutile insistere. */
	definitivo?: boolean;
}

/** Rifiuto per regola di gioco, non per rete: non si riprova. */
class ErroreDefinitivo extends Error {}

const PREFISSO = 'coda:';

class StatoCoda {
	inAttesa = $state<CatturaInCoda[]>([]);
	inInvio = $state(false);
	online = $state(true);

	async init() {
		if (!browser) return;
		this.online = navigator.onLine;
		addEventListener('online', () => {
			this.online = true;
			void this.svuota();
		});
		addEventListener('offline', () => (this.online = false));
		await this.rileggi();
		if (this.online) void this.svuota();
	}

	private async rileggi() {
		const tutte = await keys();
		const mie = tutte.filter((k) => typeof k === 'string' && k.startsWith(PREFISSO));
		const voci: CatturaInCoda[] = [];
		for (const k of mie) {
			const v = await get<CatturaInCoda>(k as string);
			if (v) voci.push(v);
		}
		this.inAttesa = voci.sort((a, b) => a.creata - b.creata);
	}

	async accoda(voce: Omit<CatturaInCoda, 'id' | 'creata' | 'tentativi'>) {
		const completa: CatturaInCoda = {
			...voce,
			id: idUnico(),
			creata: Date.now(),
			tentativi: 0
		};
		await set(PREFISSO + completa.id, completa);
		this.inAttesa = [...this.inAttesa, completa];
		if (this.online) void this.svuota();
		return completa.id;
	}

	async svuota() {
		if (this.inInvio || !this.inAttesa.length) return;
		this.inInvio = true;
		try {
			for (const voce of [...this.inAttesa]) {
				try {
					await this.spedisci(voce);
					await this.scarta(voce.id);
				} catch (e) {
					if (e instanceof ErroreDefinitivo) {
						// Regola di gioco violata: riprovare non cambierebbe nulla.
						// Resta in coda con l'errore in chiaro, decide il giocatore.
						voce.tentativi++;
						voce.ultimoErrore = e.message;
						voce.definitivo = true;
						await set(PREFISSO + voce.id, voce);
						this.inAttesa = [...this.inAttesa];
						continue;
					}
					voce.tentativi++;
					voce.ultimoErrore = e instanceof Error ? e.message : String(e);
					await set(PREFISSO + voce.id, voce);
					this.inAttesa = [...this.inAttesa];
					break; // caduta la rete: si riprende quando torna
				}
			}
		} finally {
			this.inInvio = false;
		}
	}

	private async spedisci(voce: CatturaInCoda) {
		// La foto va su R2, con un URL firmato dal server e valido 5 minuti:
		// si chiede un URL fresco a ogni tentativo, cosi' una firma scaduta
		// (coda rimasta ferma per ore senza rete) si risolve da sola al
		// prossimo giro invece di restare bloccata per sempre.
		const risp = await fetch('/api/upload-url', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ userId: voce.userId, estensione: voce.estensione })
		});
		if (!risp.ok) throw new Error(`Non riesco a preparare l'upload (${risp.status})`);
		const { uploadUrl, contentType, publicUrl } = await risp.json();

		const rispPut = await fetch(uploadUrl, {
			method: 'PUT',
			headers: { 'Content-Type': contentType },
			body: voce.blob
		});
		if (!rispPut.ok) throw new Error(`Upload della foto rifiutato (${rispPut.status})`);

		const { error: errRpc } = await supabase.rpc('registra_cattura', {
			p_user: voce.userId,
			p_item: voce.itemId,
			p_foto: publicUrl,
			p_nota: voce.nota,
			p_lat: voce.lat,
			p_lng: voce.lng
		});
		if (errRpc) {
			// Il database ha detto no per una regola (doppione, troppo lontano):
			// e' definitivo. Se invece e' caduta la rete, si riprova.
			const retedown = /fetch|network|timeout/i.test(errRpc.message);
			throw retedown ? new Error(errRpc.message) : new ErroreDefinitivo(errRpc.message);
		}
	}

	async scarta(id: string) {
		await del(PREFISSO + id);
		this.inAttesa = this.inAttesa.filter((v) => v.id !== id);
	}
}

export const coda = new StatoCoda();
