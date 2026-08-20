import adapter from '@sveltejs/adapter-vercel';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	preprocess: vitePreprocess(),
	compilerOptions: { runes: true },
	kit: {
		// Quasi tutto resta statico come prima (ssr:false, SPA lato pagine): la
		// sola differenza e' la route /api/upload-url, che gira come funzione
		// serverless perche' deve firmare gli URL verso R2 con una chiave
		// segreta che non puo' stare nel bundle client.
		adapter: adapter(),
		alias: { $components: 'src/lib/components' },
		serviceWorker: { register: false } // se ne occupa vite-plugin-pwa
	}
};

export default config;
