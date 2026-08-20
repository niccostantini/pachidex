import { sveltekit } from '@sveltejs/kit/vite';
import { SvelteKitPWA } from '@vite-pwa/sveltekit';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [
		sveltekit(),
		SvelteKitPWA({
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
			workbox: {
				globPatterns: ['**/*.{js,css,html,woff2,png,svg}'],
				// Le foto delle catture: cache runtime, non precache.
				runtimeCaching: [
					{
						urlPattern: /\/storage\/v1\/object\/public\/catture\/.*/i,
						handler: 'CacheFirst',
						options: {
							cacheName: 'catture',
							expiration: { maxEntries: 300, maxAgeSeconds: 60 * 60 * 24 * 30 },
							cacheableResponse: { statuses: [0, 200] }
						}
					},
					{
						urlPattern: /^https:\/\/[a-z]\.tile\.openstreetmap\.org\/.*/i,
						handler: 'CacheFirst',
						options: {
							cacheName: 'osm-tiles',
							expiration: { maxEntries: 500, maxAgeSeconds: 60 * 60 * 24 * 30 },
							cacheableResponse: { statuses: [0, 200] }
						}
					}
				]
			}
		})
	]
});
