import { browser } from '$app/environment';

/**
 * Il pannello admin si usa da desktop prima di partire e dal telefono
 * durante la vacanza: stessi dati, due impaginazioni diverse.
 */
class StatoSchermo {
	largo = $state(false);

	init() {
		if (!browser) return () => {};
		const mq = matchMedia('(min-width: 860px)');
		this.largo = mq.matches;
		const onCambio = (e: MediaQueryListEvent) => (this.largo = e.matches);
		mq.addEventListener('change', onCambio);
		return () => mq.removeEventListener('change', onCambio);
	}
}

export const schermo = new StatoSchermo();
