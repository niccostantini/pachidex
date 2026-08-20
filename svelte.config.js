import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	preprocess: vitePreprocess(),
	compilerOptions: { runes: true },
	kit: {
		// SPA: nessun server, deploy statico identico su Vercel o Netlify.
		adapter: adapter({ fallback: 'index.html', precompress: true, strict: false }),
		alias: { $components: 'src/lib/components' },
		serviceWorker: { register: false } // se ne occupa vite-plugin-pwa
	}
};

export default config;
