import { sveltekit } from '@sveltejs/kit/vite';
import { SvelteKitPWA } from '@vite-pwa/sveltekit';
import { defineConfig } from 'vite';

export default defineConfig(() => {
	return {
		// ngrok assegna un sottodominio casuale a ogni avvio e Vite rifiuta gli
		// host che non conosce: senza questi, chi apre il link del tunnel si
		// trova un "Blocked request" al posto dell'app.
		server: {
			allowedHosts: ['.ngrok-free.dev', '.ngrok-free.app', '.ngrok.app'],
			// Supabase dallo stesso indirizzo della pagina. Serve al tunnel per
			// l'iPhone: la pagina e' in https, il Supabase in Docker in http, e
			// Safari blocca le chiamate da una all'altro. Passando da qui escono
			// entrambe dallo stesso https. In produzione non c'e' Vite davanti.
			proxy: Object.fromEntries(
				['/rest/v1', '/auth/v1', '/storage/v1', '/functions/v1', '/realtime/v1'].map((p) => [
					p,
					{ target: 'http://127.0.0.1:54321', changeOrigin: true, ws: p === '/realtime/v1' }
				])
			)
		},
		preview: { allowedHosts: ['.ngrok-free.dev', '.ngrok-free.app', '.ngrok.app'] },
		plugins: [
			sveltekit(),
			SvelteKitPWA({
				// injectManifest invece di generateSW: un service worker generato
				// non puo' ricevere i push, il gestore va scritto a mano.
				strategies: 'injectManifest',
				srcDir: 'src',
				filename: 'service-worker.ts',
				registerType: 'autoUpdate',
				manifest: {
					name: 'Pachino Express',
					short_name: 'PachiDex',
					description: 'Il PachiDex della vacanza a Pachino',
					lang: 'it',
					start_url: '/',
					scope: '/',
					display: 'standalone',
					orientation: 'portrait',
					background_color: '#E7DDC6',
					theme_color: '#161B3D',
					icons: [
						{ src: '/icon-192.png', sizes: '192x192', type: 'image/png' },
						{ src: '/icon-512.png', sizes: '512x512', type: 'image/png' },
						{ src: '/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' }
					]
				},
				injectManifest: {
					// jpg e jpeg ci sono per le foto di riferimento degli animali:
					// senza, offline restavano fuori 18 delle 26 e uno si trovava
					// davanti a una folaga senza sapere che aspetto abbia.
					globPatterns: ['**/*.{js,css,html,woff2,png,svg,webp,jpg,jpeg}'],
					// Le foto di riferimento superano il mezzo mega: il limite
					// predefinito di 2 MiB le lascerebbe fuori in silenzio.
					maximumFileSizeToCacheInBytes: 4 * 1024 * 1024
				}
			})
		]
	};
});
