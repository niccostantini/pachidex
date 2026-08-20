import { browser } from '$app/environment';
import { PUBLIC_VAPID_KEY } from '$env/static/public';
import { supabase } from '$lib/supabase';

/**
 * Notifiche push.
 *
 * Il vincolo che decide tutto: su iOS il push funziona solo se la PWA e'
 * stata installata sulla schermata Home. In Safari come scheda normale
 * l'API non c'e' proprio, e non e' un permesso negato — e' assente. Per
 * questo lo stato distingue "non supportato" da "rifiutato": all'utente si
 * dicono due cose diverse.
 */

export type StatoPush =
	| 'sconosciuto'
	| 'non_supportato'
	| 'serve_installazione'
	| 'da_chiedere'
	| 'attive'
	| 'rifiutate';

/**
 * La chiave VAPID viaggia in base64url, l'API la vuole in byte.
 * Il tipo di ritorno e' ArrayBuffer e non Uint8Array perche' applicationServerKey
 * non accetta viste su SharedArrayBuffer, e TypeScript non sa distinguerle.
 */
function chiaveInByte(base64: string): ArrayBuffer {
	const pieno = (base64 + '='.repeat((4 - (base64.length % 4)) % 4))
		.replace(/-/g, '+')
		.replace(/_/g, '/');
	const grezzo = atob(pieno);
	const byte = new Uint8Array(grezzo.length);
	for (let i = 0; i < grezzo.length; i++) byte[i] = grezzo.charCodeAt(i);
	return byte.buffer;
}

const installata = () =>
	matchMedia('(display-mode: standalone)').matches ||
	// Safari su iOS non espone display-mode standalone in tutte le versioni.
	(navigator as unknown as { standalone?: boolean }).standalone === true;

class StatoNotifiche {
	stato = $state<StatoPush>('sconosciuto');
	inCorso = $state(false);
	errore = $state<string | null>(null);

	get attive() {
		return this.stato === 'attive';
	}

	async init() {
		if (!browser) return;

		if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
			// Su iPhone questo significa quasi sempre "non e' installata",
			// non "il telefono non sa fare le notifiche".
			this.stato = /iphone|ipad|ipod/i.test(navigator.userAgent) && !installata()
				? 'serve_installazione'
				: 'non_supportato';
			return;
		}

		if (Notification.permission === 'denied') {
			this.stato = 'rifiutate';
			return;
		}

		const reg = await navigator.serviceWorker.ready;
		const iscrizione = await reg.pushManager.getSubscription();
		this.stato = iscrizione ? 'attive' : 'da_chiedere';
	}

	/** Va chiamata da un gesto dell'utente: i browser non concedono altrimenti. */
	async attiva(userId: string) {
		if (!browser || this.inCorso) return;
		this.inCorso = true;
		this.errore = null;
		try {
			const permesso = await Notification.requestPermission();
			if (permesso !== 'granted') {
				this.stato = permesso === 'denied' ? 'rifiutate' : 'da_chiedere';
				return;
			}

			const reg = await navigator.serviceWorker.ready;
			const iscrizione =
				(await reg.pushManager.getSubscription()) ??
				(await reg.pushManager.subscribe({
					userVisibleOnly: true,
					applicationServerKey: chiaveInByte(PUBLIC_VAPID_KEY)
				}));

			const dati = iscrizione.toJSON();
			const { error } = await supabase.from('push_subscriptions').upsert(
				{
					user_id: userId,
					endpoint: iscrizione.endpoint,
					p256dh: dati.keys?.p256dh ?? '',
					auth: dati.keys?.auth ?? '',
					scaduta: false,
					ultimo_errore: null
				},
				{ onConflict: 'endpoint' }
			);
			if (error) throw error;

			this.stato = 'attive';
		} catch (e) {
			this.errore = e instanceof Error ? e.message : String(e);
		} finally {
			this.inCorso = false;
		}
	}

	async disattiva() {
		if (!browser || this.inCorso) return;
		this.inCorso = true;
		try {
			const reg = await navigator.serviceWorker.ready;
			const iscrizione = await reg.pushManager.getSubscription();
			if (iscrizione) {
				await supabase.from('push_subscriptions').delete().eq('endpoint', iscrizione.endpoint);
				await iscrizione.unsubscribe();
			}
			this.stato = 'da_chiedere';
		} catch (e) {
			this.errore = e instanceof Error ? e.message : String(e);
		} finally {
			this.inCorso = false;
		}
	}

	/**
	 * Riaggancia l'iscrizione di questo dispositivo al profilo scelto: sullo
	 * stesso telefono si puo' cambiare giocatore, e le notifiche devono
	 * seguire chi lo sta usando adesso.
	 */
	async riassegna(userId: string) {
		if (!browser || this.stato !== 'attive') return;
		const reg = await navigator.serviceWorker.ready;
		const iscrizione = await reg.pushManager.getSubscription();
		if (!iscrizione) return;
		await supabase
			.from('push_subscriptions')
			.update({ user_id: userId })
			.eq('endpoint', iscrizione.endpoint);
	}
}

export const notifiche = new StatoNotifiche();
