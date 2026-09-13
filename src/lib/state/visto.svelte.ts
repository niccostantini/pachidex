import { browser } from '$app/environment';
import { supabase } from '$lib/supabase';

/**
 * Fin dove eri arrivata a leggere.
 *
 * Non e' una tab notifiche e non vuole diventarlo: il feed E' gia' l'elenco
 * di tutto quello che succede, e una seconda schermata sarebbe la stessa
 * cronaca scritta peggio. Quello che mancava davvero non e' la storia, e' il
 * segnaposto — «cosa e' successo da quando ho guardato l'ultima volta».
 *
 * Da qui escono due cose sole: un pallino sulla linguetta FEED quando c'e'
 * roba nuova, e la riga che nel feed divide il nuovo dal gia' visto.
 *
 * Il segnaposto sta sul telefono e non nel database perche' e' una faccenda
 * fra te e questo schermo: aprire l'app sul tablet non deve cancellare il
 * puntino sul telefono di qualcun altro, e nemmeno sul tuo.
 */
const CHIAVE = 'pachidex:visto';

class StatoVisto {
	/** Il momento dell'ultima occhiata, in ISO. */
	marcatore = $state<string>(new Date().toISOString());
	/** Quante cose sono successe dopo, che non hai fatto tu. */
	nuovi = $state(0);

	private chi: string | null = null;

	private get chiave() {
		return `${CHIAVE}:${this.chi ?? 'anonimo'}`;
	}

	/**
	 * Al primo avvio il segnaposto e' adesso, non l'inizio dei tempi: chi
	 * apre l'app per la prima volta non deve trovarsi settanta cose "nuove"
	 * e un pallino che non si spegne finche' non scorre tutto.
	 */
	init(userId: string) {
		if (!browser || this.chi === userId) return;
		this.chi = userId;
		this.marcatore = localStorage.getItem(this.chiave) ?? new Date().toISOString();
		void this.ricontrolla();
	}

	/** L'hai guardato: il segnaposto si sposta a adesso e il pallino si spegne. */
	segna() {
		if (!browser || !this.chi) return;
		this.marcatore = new Date().toISOString();
		try {
			localStorage.setItem(this.chiave, this.marcatore);
		} catch {
			/* archiviazione piena o negata: il pallino resta acceso, pazienza */
		}
		this.nuovi = 0;
	}

	/**
	 * Quanta roba e' arrivata dopo il segnaposto.
	 *
	 * Quattro conteggi senza righe (`head: true`), non il feed intero: questo
	 * gira anche stando sulla mappa o sul PachiDex, e caricare sessanta
	 * catture con foto e like per accendere un pallino sarebbe sproporzionato.
	 *
	 * Quello che hai fatto tu non conta: un pallino che si accende perche' hai
	 * appena pubblicato una cosa tua e' solo un pallino da spegnere.
	 */
	async ricontrolla() {
		if (!this.chi) return;
		const da = this.marcatore;
		const io = this.chi;
		const conta = async (
			tabella: string,
			quando: string,
			mio: string,
			filtra?: (q: ReturnType<typeof this.query>) => ReturnType<typeof this.query>
		) => {
			let q = this.query(tabella).gt(quando, da).neq(mio, io);
			if (filtra) q = filtra(q);
			const { count } = await q;
			return count ?? 0;
		};

		try {
			const pezzi = await Promise.all([
				conta('captures', 'timestamp', 'user_id'),
				conta('transfers', 'created_at', 'from_user_id', (q) => q.eq('annullato', false)),
				conta('oversharing', 'created_at', 'user_id'),
				conta('contests', 'created_at', 'contestante_id')
			]);
			this.nuovi = pezzi.reduce((a, b) => a + b, 0);
		} catch {
			/* senza linea il pallino resta com'e': non e' una notizia urgente */
		}
	}

	private query(tabella: string) {
		return supabase.from(tabella).select('id', { count: 'exact', head: true });
	}
}

export const visto = new StatoVisto();
