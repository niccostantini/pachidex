import { supabase } from '$lib/supabase';
import { conCache } from '$lib/db/cache';
import type { Saldo, User } from '$lib/types';

/**
 * Chi sta usando l'app.
 *
 * Prima era una scelta salvata sul telefono: si toccava il proprio nome in un
 * elenco e bastava. Fra sei amici in vacanza andava bene; adesso che l'app
 * resta in piedi e gira anche a chi non e' della partita, serve una sessione
 * vera.
 *
 * Si entra con NOME UTENTE e password. Supabase Auth vuole un'email, quindi
 * se ne costruisce una tecnica dal nome: nessuno la vede mai, vive solo qui
 * dentro.
 */
const DOMINIO = 'pachidex.local';

/** Da "Vito" a "vito@pachidex.local", e senza sorprese sugli spazi. */
export const emailDi = (nome: string) =>
	`${nome.trim().toLowerCase().replace(/\s+/g, '')}@${DOMINIO}`;

class StatoProfilo {
	utenti = $state<User[]>([]);
	io = $state<User | null>(null);
	saldi = $state<Saldo[]>([]);
	/** true quando si sa se c'e' una sessione: prima non si decide niente. */
	pronto = $state(false);
	errore = $state<string | null>(null);

	get saldo(): number {
		return this.saldi.find((s) => s.user_id === this.io?.id)?.saldo ?? 0;
	}

	/**
	 * Chi e' in partita.
	 *
	 * Dentro users non ci sono solo giocatori: c'e' chi amministra e c'e' chi
	 * guarda per vedere com'e' fatto il gioco. Sono gli account `nascosto`,
	 * gia' fuori da classifica e titoli, e devono restare fuori da tutto il
	 * resto: menzioni, scambi, voti, maggioranze. Un conteggio che li include
	 * non e' solo brutto da vedere — alza l'asticella delle contestazioni e
	 * lascia il finale in attesa di voti che non arriveranno.
	 */
	get giocatori(): User[] {
		return this.utenti.filter((u) => !u.nascosto);
	}

	get altri(): User[] {
		return this.giocatori.filter((u) => u.id !== this.io?.id);
	}

	/** Chi guarda e basta: niente catture, niente like, niente scambi. */
	get soloSguardo(): boolean {
		return (this.io?.sola_lettura || this.io?.nascosto) ?? false;
	}

	async carica() {
		const { data: sessione } = await supabase.auth.getSession();
		await this.daSessione(sessione.session?.user?.id ?? null);

		// Il token si rinnova da solo e la sessione puo' cadere: si sta in
		// ascolto invece di fidarsi della fotografia presa all'avvio.
		supabase.auth.onAuthStateChange((_evento, s) => {
			void this.daSessione(s?.user?.id ?? null);
		});
	}

	private async daSessione(id: string | null) {
		if (!id) {
			this.io = null;
			this.pronto = true;
			return;
		}

		try {
			// L'elenco resta in cache: senza linea l'app deve aprirsi lo stesso,
			// e chi e' entrato ieri e' ancora entrato oggi.
			this.utenti = await conCache('utenti', async () => {
				const { data, error } = await supabase.from('users').select('*').order('created_at');
				if (error) throw error;
				return (data ?? []) as User[];
			});
			this.errore = null;
		} catch (e) {
			this.errore = e instanceof Error ? e.message : String(e);
			this.pronto = true;
			return;
		}

		this.io = this.utenti.find((u) => u.id === id) ?? null;
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

	/** Restituisce il messaggio d'errore, oppure null se si e' entrati. */
	async entra(nome: string, password: string): Promise<string | null> {
		const { error } = await supabase.auth.signInWithPassword({
			email: emailDi(nome),
			password
		});
		if (!error) return null;
		// Il messaggio di Supabase parla di email e qui l'email non esiste:
		// tradurlo evita di far cercare a qualcuno un indirizzo che non ha.
		return /invalid login|credentials/i.test(error.message)
			? 'Nome utente o password sbagliati'
			: error.message;
	}

	async esci() {
		await supabase.auth.signOut();
		this.io = null;
	}

	saldoDi(userId: string): number {
		return this.saldi.find((s) => s.user_id === userId)?.saldo ?? 0;
	}
}

export const profilo = new StatoProfilo();
