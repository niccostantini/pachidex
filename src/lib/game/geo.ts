import type { VoceDex } from '$lib/types';

export interface Posizione {
	lat: number;
	lng: number;
	precisione: number;
}

/** Haversine, gli stessi metri che calcola il database. */
export function distanzaMetri(
	lat1: number,
	lng1: number,
	lat2: number,
	lng2: number
): number {
	const R = 6371000;
	const rad = Math.PI / 180;
	const dLat = (lat2 - lat1) * rad;
	const dLng = (lng2 - lng1) * rad;
	const a =
		Math.sin(dLat / 2) ** 2 +
		Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) ** 2;
	return 2 * R * Math.asin(Math.sqrt(a));
}

export function posizioneAttuale(timeout = 10000): Promise<Posizione> {
	return new Promise((risolvi, rifiuta) => {
		if (!('geolocation' in navigator)) {
			rifiuta(new Error('Questo dispositivo non ha il GPS'));
			return;
		}
		navigator.geolocation.getCurrentPosition(
			(p) =>
				risolvi({
					lat: p.coords.latitude,
					lng: p.coords.longitude,
					precisione: p.coords.accuracy
				}),
			(e) =>
				rifiuta(
					new Error(
						e.code === e.PERMISSION_DENIED
							? 'Permesso posizione negato'
							: 'Non riesco a leggere la posizione'
					)
				),
			{ enableHighAccuracy: true, timeout, maximumAge: 15000 }
		);
	});
}

/** Osserva la posizione; restituisce la funzione per smettere. */
export function osservaPosizione(
	onPos: (p: Posizione) => void,
	onErr?: (e: Error) => void
): () => void {
	if (!('geolocation' in navigator)) {
		onErr?.(new Error('Questo dispositivo non ha il GPS'));
		return () => {};
	}
	const id = navigator.geolocation.watchPosition(
		(p) =>
			onPos({ lat: p.coords.latitude, lng: p.coords.longitude, precisione: p.coords.accuracy }),
		(e) => onErr?.(new Error(e.message)),
		{ enableHighAccuracy: true, maximumAge: 10000, timeout: 20000 }
	);
	return () => navigator.geolocation.clearWatch(id);
}

export interface CheckpointVicino {
	voce: VoceDex;
	distanza: number;
	dentro: boolean;
}

/** I checkpoint GPS ordinati per distanza, il piu' vicino per primo. */
export function checkpointVicini(
	voci: VoceDex[],
	pos: Posizione,
	raggio: number
): CheckpointVicino[] {
	return voci
		.filter((v) => v.validazione === 'auto_gps' && v.lat != null && v.lng != null)
		.map((voce) => {
			const distanza = distanzaMetri(pos.lat, pos.lng, voce.lat as number, voce.lng as number);
			return { voce, distanza, dentro: distanza <= raggio };
		})
		.sort((a, b) => a.distanza - b.distanza);
}

export const formattaDistanza = (m: number) =>
	m < 1000 ? `${Math.round(m)} m` : `${(m / 1000).toFixed(1)} km`;
