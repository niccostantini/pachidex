import { sveltekit } from '@sveltejs/kit/vite';
import { SvelteKitPWA } from '@vite-pwa/sveltekit';
import { defineConfig } from 'vite';

export default defineConfig(() => {
	return {
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
