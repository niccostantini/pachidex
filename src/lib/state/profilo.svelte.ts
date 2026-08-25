import { browser } from '$app/environment';
import { supabase } from '$lib/supabase';
import { conCache } from '$lib/db/cache';
import type { Saldo, User } from '$lib/types';

const CHIAVE = 'pachidex:profilo';

/**
 * Chi sta usando il telefono. Nessuna password: la scelta si fa una volta e
 * resta in localStorage, che e' esattamente quanta sicurezza serve qui.
 */
class StatoProfilo {
	utenti = $state<User[]>([]);
	io = $state<User | null>(null);
	saldi = $state<Saldo[]>([]);
	pronto = $state(false);
	errore = $state<string | null>(null);

	get saldo(): number {
		return this.saldi.find((s) => s.user_id === this.io?.id)?.saldo ?? 0;
	}

	get altri(): User[] {
		return this.utenti.filter((u) => u.id !== this.io?.id);
	}

	async carica() {
		// Questa e' la lettura che apre l'app, ed era anche quella che la
		// chiudeva: senza linea falliva e il layout copriva tutto con
		// "Non riesco a parlare con il database", schermata di cattura
		// compresa. Ora ripiega sull'elenco salvato e si va avanti.
		try {
			this.utenti = await conCache('utenti', async () => {
				const { data, error } = await supabase.from('users').select('*').order('created_at');
				if (error) throw error;
				return (data ?? []) as User[];
			});
			this.errore = null;
		} catch (e) {
			// Nemmeno in cache: e' il primo avvio senza rete, non c'e' niente
			// da mostrare e tanto vale dirlo.
			this.errore = e instanceof Error ? e.message : String(e);
			this.pronto = true;
			return;
		}

		if (browser) {
			const salvato = localStorage.getItem(CHIAVE);
			const trovato = this.utenti.find((u) => u.id === salvato);
			if (trovato) this.io = trovato;
		}
		this.pronto = true;
		void this.aggiornaSaldi();
	}

	async aggiornaSaldi() {
		try {
			this.saldi = await conCache('saldi', async () => {
				const { data, error } = await supabase.from('v_saldi').select('*');
				if (error) throw error;
				return (data ?? []) as Saldo[];
			});
		} catch {
			// Senza linea e senza cache i saldi restano a zero: e' un numero
			// sbagliato ma innocuo, e la striscia in cima avverte gia'.
		}
	}

	scegli(u: User) {
		this.io = u;
		if (browser) localStorage.setItem(CHIAVE, u.id);
	}

	esci() {
		this.io = null;
		if (browser) localStorage.removeItem(CHIAVE);
	}

	saldoDi(userId: string): number {
		return this.saldi.find((s) => s.user_id === userId)?.saldo ?? 0;
	}
}

export const profilo = new StatoProfilo();
