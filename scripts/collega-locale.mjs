/**
 * Scrive .env.local puntando al Supabase che gira su questa macchina.
 *
 *   node scripts/collega-locale.mjs          -> IP della LAN (per i telefoni)
 *   node scripts/collega-locale.mjs --solo-io -> 127.0.0.1 (solo questo Mac)
 *   node scripts/collega-locale.mjs --tunnel  -> l'https di ngrok (per l'iPhone)
 *
 * Serve uno script e non un file fisso perche' l'indirizzo cambia a ogni
 * rete: attaccati all'hotspot di qualcuno l'IP di ieri non esiste piu'.
 */
import { execSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { networkInterfaces } from 'node:os';

const soloIo = process.argv.includes('--solo-io');
const tunnel = process.argv.includes('--tunnel');

/**
 * L'indirizzo https che ngrok ha dato a `npm run tunnel:dev`.
 *
 * Serve all'iPhone: Safari da' il GPS solo in https, e una pagina https non
 * puo' chiamare un Supabase in http. Quindi passa tutto dallo stesso tunnel:
 * la pagina e Supabase, che Vite inoltra a Docker (vedi vite.config.ts).
 */
async function indirizzoTunnel() {
	const r = await fetch('http://127.0.0.1:4040/api/tunnels').catch(() => null);
	if (!r?.ok) throw new Error('ngrok non risponde: fai partire prima npm run tunnel:dev');
	const { tunnels } = await r.json();
	const https = tunnels.find((t) => t.public_url.startsWith('https://'));
	if (!https) throw new Error('ngrok non ha un tunnel https');
	return https.public_url;
}

function indirizzo() {
	if (soloIo) return '127.0.0.1';
	for (const schede of Object.values(networkInterfaces())) {
		for (const s of schede ?? []) {
			if (s.family === 'IPv4' && !s.internal) return s.address;
		}
	}
	console.warn('Nessuna rete trovata: ripiego su 127.0.0.1');
	return '127.0.0.1';
}

const stato = JSON.parse(execSync('supabase status -o json', { encoding: 'utf8' }));
const ip = tunnel ? null : indirizzo();
const url = tunnel ? await indirizzoTunnel() : `http://${ip}:54321`;

writeFileSync(
	new URL('../.env.local', import.meta.url),
	`# ============================================================================
# AMBIENTE LOCALE — scritto da scripts/collega-locale.mjs, non a mano.
#
# Vite carica .env.local dopo .env e in tutti i modi, quindi "npm run dev" e
# "npm run preview" parlano con il Supabase in Docker su questa macchina.
# Il deploy su Vercel non e' toccato: usa le variabili sue.
#
# Per tornare alla produzione: rinomina o cancella questo file.
#
# Ignorato da git (.gitignore copre .env.*).
# ============================================================================
PUBLIC_SUPABASE_URL="${url}"
PUBLIC_SUPABASE_ANON_KEY="${stato.ANON_KEY}"

# Chiave di servizio: SOLO lato server, crea gli account. Non prefissarla PUBLIC_.
# Va riscritta qui ogni volta: senza, SvelteKit ricade su quella di .env, che e'
# di produzione, e non combacia con l'istanza locale a cui punta l'URL sopra.
SUPABASE_SERVICE_ROLE_KEY="${stato.SERVICE_ROLE_KEY}"
`
);

console.log(`.env.local -> ${url}`);
if (tunnel) {
	console.log(`\nDall'iPhone, anche fuori casa:  ${url}`);
	console.log('Ricordati di far partire (o ripartire) il server con:  npm run dev');
} else if (!soloIo) {
	console.log(`\nDagli altri telefoni, sulla stessa rete:  http://${ip}:4173`);
	console.log('Ricordati di far partire il server con:   npm run preview:lan');
	console.log('\nNota: su http (non https) il service worker non si installa,');
	console.log('quindi niente offline e niente notifiche. La premiazione funziona.');
}
