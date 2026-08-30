import { browser } from '$app/environment';

/**
 * Il ritmo delle catture, visto dal telefono.
 *
 * Il limite vero lo fa il database — questo serve solo a non far scattare una
 * foto, scegliere l'elemento e scrivere la didascalia per poi sentirsi dire
 * di no. Meglio dirlo prima, con il conto alla rovescia.
 *
 * Le ore restano in localStorage e non sul server perche' devono funzionare
 * anche senza linea: e' proprio quando si e' offline, con la coda che si
 * riempie, che uno rischia di andare troppo di fretta senza accorgersene.
 *
 * E' una comodita', non un controllo: chi svuota il localStorage salta il
 * conto alla rovescia e viene fermato dal database un attimo dopo.
 */
const CHIAVE = 'pachidex:ritmo';

function leggi(): number[] {
	if (!browser) return [];
	try {
		const grezzo = JSON.parse(localStorage.getItem(CHIAVE) ?? '[]');
		return Array.isArray(grezzo) ? grezzo.filter((n) => typeof n === 'number') : [];
	} catch {
		return [];
	}
}

/** Si segna una cattura appena fatta. */
export function segnaCattura(quando = Date.now()) {
	if (!browser) return;
	// Si tiene solo l'ultima mezz'ora: oltre non serve a nessuno.
	const tenute = [...leggi(), quando].filter((t) => t > quando - 30 * 60_000);
	try {
		localStorage.setItem(CHIAVE, JSON.stringify(tenute));
	} catch {
		/* localStorage pieno o negato: si perde il conto alla rovescia, non la cattura */
	}
}

/**
 * Quanti secondi mancano prima di poter catturare di nuovo. Zero se si puo'
 * gia'. I due parametri arrivano dalla configurazione, cosi' se l'admin
 * cambia le soglie il telefono le rispetta senza dover aggiornare l'app.
 */
export function attesaResidua(max = 3, finestraMinuti = 6, ora = Date.now()): number {
	const finestra = finestraMinuti * 60_000;
	const dentro = leggi()
		.filter((t) => t > ora - finestra)
		.sort((a, b) => a - b);
	if (dentro.length < max) return 0;

	// Si aspetta che la piu' vecchia fra quelle che riempiono la finestra ne
	// esca: da quel momento c'e' di nuovo posto.
	const liberaAlle = dentro[dentro.length - max] + finestra;
	return Math.max(0, Math.ceil((liberaAlle - ora) / 1000));
}

/** "1:20" oppure "45 s". */
export function formattaAttesa(secondi: number): string {
	if (secondi < 60) return `${secondi} s`;
	const m = Math.floor(secondi / 60);
	const s = secondi % 60;
	return `${m}:${String(s).padStart(2, '0')}`;
}
