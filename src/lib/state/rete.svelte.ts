import { browser } from '$app/environment';

/**
 * Lo stato della linea, e l'eta' di cio' che si sta guardando.
 *
 * Serve perche' a Vendicari, in spiaggia e in mezzo alle serre la tacca non
 * c'e'. L'app deve restare in piedi lo stesso: si continua a catturare col
 * GPS, si consulta il PachiDex, e la cronaca resta ferma all'ultima volta che
 * si e' visto il mondo. L'unica cosa che non si deve fare e' mentire su
 * quanto sono vecchi i dati — da qui la striscia in cima.
 */
class StatoRete {
	online = $state(true);
	/** true quando l'ultimo caricamento e' arrivato dalla cache, non dalla rete. */
	daCache = $state(false);
	/** A quando risalgono i dati mostrati. null se sono freschi. */
	quando = $state<number | null>(null);

	init() {
		if (!browser) return;
		this.online = navigator.onLine;
		addEventListener('online', () => (this.online = true));
		addEventListener('offline', () => (this.online = false));
	}

	/** Un caricamento e' arrivato dalla rete: quello che si vede e' vero adesso. */
	freschi() {
		this.daCache = false;
		this.quando = null;
	}

	/**
	 * Un caricamento e' ripiegato sulla cache. Si tiene la data piu' vecchia
	 * fra quelle ripescate: se il PachiDex e' di ieri e il feed di un'ora fa,
	 * dire "un'ora fa" sarebbe la meta' della verita'.
	 */
	vecchi(quando: number) {
		this.daCache = true;
		this.quando = this.quando === null ? quando : Math.min(this.quando, quando);
	}
}

export const rete = new StatoRete();

/** "2 ore fa", "ieri". Sotto il minuto non si scende: non interessa a nessuno. */
export function quantoFa(quando: number): string {
	const min = Math.round((Date.now() - quando) / 60000);
	if (min < 2) return 'poco fa';
	if (min < 60) return `${min} minuti fa`;
	const ore = Math.round(min / 60);
	if (ore < 24) return ore === 1 ? "un'ora fa" : `${ore} ore fa`;
	const giorni = Math.round(ore / 24);
	return giorni === 1 ? 'ieri' : `${giorni} giorni fa`;
}
