import { browser } from '$app/environment';
import { supabase } from '$lib/supabase';
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
		const { data, error } = await supabase.from('users').select('*').order('created_at');
		if (error) {
			this.errore = error.message;
			this.pronto = true;
			return;
		}
		this.utenti = (data ?? []) as User[];

		if (browser) {
			const salvato = localStorage.getItem(CHIAVE);
			const trovato = this.utenti.find((u) => u.id === salvato);
			if (trovato) this.io = trovato;
		}
		this.pronto = true;
		void this.aggiornaSaldi();
	}

	async aggiornaSaldi() {
		const { data } = await supabase.from('v_saldi').select('*');
		if (data) this.saldi = data as Saldo[];
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
