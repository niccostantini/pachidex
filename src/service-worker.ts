/// <reference lib="webworker" />
/**
 * Service worker scritto a mano.
 *
 * Prima era generato da Workbox, ma un service worker auto-generato non puo'
 * ricevere i push: il gestore va scritto, e per scriverlo serve possedere il
 * file. Il prezzo e' che la cache runtime, prima dichiarata in configurazione,
 * ora e' codice qui sotto.
 */
import {
	cleanupOutdatedCaches,
	createHandlerBoundToURL,
	precacheAndRoute
} from 'workbox-precaching';
import { NavigationRoute, registerRoute } from 'workbox-routing';
import { CacheFirst } from 'workbox-strategies';
import { ExpirationPlugin } from 'workbox-expiration';
import { CacheableResponsePlugin } from 'workbox-cacheable-response';

declare const self: ServiceWorkerGlobalScope & {
	__WB_MANIFEST: Array<{ url: string; revision: string | null }>;
};

/* --- precache e aggiornamento ------------------------------------------- */
precacheAndRoute(self.__WB_MANIFEST);
cleanupOutdatedCaches();

self.addEventListener('install', () => {
	void self.skipWaiting();
});
self.addEventListener('activate', (e) => {
	e.waitUntil(self.clients.claim());
});

/**
 * Rete assente: le rotte fisse (/cattura, /pachidex, /mappa...) stanno gia'
 * nel precache e rispondono da sole. Quelle con un pezzo variabile no —
 * /pachidex/<id> non e' un file — e un ricaricamento li' finirebbe sulla
 * pagina di errore del browser. Questa regola ripiega sul guscio della home:
 * l'app parte e il router disegna la pagina giusta da solo, senza rete.
 *
 * Va registrata DOPO precacheAndRoute, che ha la precedenza: le rotte fisse
 * continuano a rispondere con il proprio guscio, non con questo.
 */
registerRoute(new NavigationRoute(createHandlerBoundToURL('/'), {
	// Il pannello di gestione e le chiamate al server non sono navigazioni da
	// far finire nel guscio: senza rete non avrebbero comunque niente da dire.
	denylist: [/^\/api\//]
}));

/* --- cache runtime -------------------------------------------------------- */
const cacheLunga = (nome: string, voci: number) => [
	new ExpirationPlugin({ maxEntries: voci, maxAgeSeconds: 60 * 60 * 24 * 30 }),
	new CacheableResponsePlugin({ statuses: [0, 200] })
];

// Le foto delle catture, servite dal dominio R2.
registerRoute(
	({ url }) => url.pathname.startsWith('/catture/'),
	new CacheFirst({ cacheName: 'catture', plugins: cacheLunga('catture', 300) })
);

// Le tile della mappa.
registerRoute(
	({ url }) => url.hostname.endsWith('tile.openstreetmap.org'),
	new CacheFirst({ cacheName: 'osm-tiles', plugins: cacheLunga('osm-tiles', 500) })
);

/* --- notifiche ------------------------------------------------------------ */
interface Payload {
	titolo: string;
	corpo: string;
	url?: string;
	/** Notifiche con lo stesso tag si sovrascrivono invece di impilarsi. */
	tag?: string;
	/** true per far vibrare e riaccendere lo schermo anche se il tag esiste. */
	insisti?: boolean;
}

self.addEventListener('push', (evento) => {
	if (!evento.data) return;

	let p: Payload;
	try {
		p = evento.data.json() as Payload;
	} catch {
		p = { titolo: 'Pachino Express', corpo: evento.data.text() };
	}

	evento.waitUntil(
		self.registration.showNotification(p.titolo, {
			body: p.corpo,
			icon: '/icon-192.png',
			badge: '/icon-192.png',
			// Il tag e' quello che accorpa: le catture a raffica diventano una
			// notifica sola che si aggiorna, invece di dodici impilate.
			tag: p.tag ?? 'pachidex',
			renotify: p.insisti ?? false,
			data: { url: p.url ?? '/' }
		} as NotificationOptions)
	);
});

self.addEventListener('notificationclick', (evento) => {
	evento.notification.close();
	const destinazione = (evento.notification.data?.url as string) ?? '/';

	evento.waitUntil(
		(async () => {
			const finestre = await self.clients.matchAll({
				type: 'window',
				includeUncontrolled: true
			});
			// Se l'app e' gia' aperta si porta in primo piano invece di aprirne
			// un'altra copia: su iOS aprire una seconda finestra e' rumoroso.
			for (const f of finestre) {
				if ('focus' in f) {
					await f.focus();
					if ('navigate' in f) await f.navigate(destinazione).catch(() => {});
					return;
				}
			}
			await self.clients.openWindow(destinazione);
		})()
	);
});
