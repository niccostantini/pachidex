/**
 * Scrive .env.local puntando al Supabase che gira su questa macchina.
 *
 *   node scripts/collega-locale.mjs          -> IP della LAN (per i telefoni)
 *   node scripts/collega-locale.mjs --solo-io -> 127.0.0.1 (solo questo Mac)
 *
 * Serve uno script e non un file fisso perche' l'indirizzo cambia a ogni
 * rete: attaccati all'hotspot di qualcuno l'IP di ieri non esiste piu'.
 */
import { execSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { networkInterfaces } from 'node:os';

const soloIo = process.argv.includes('--solo-io');

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
const ip = indirizzo();
const url = `http://${ip}:54321`;

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
`
);

console.log(`.env.local -> ${url}`);
if (!soloIo) {
	console.log(`\nDagli altri telefoni, sulla stessa rete:  http://${ip}:4173`);
	console.log('Ricordati di far partire il server con:   npm run preview:lan');
	console.log('\nNota: su http (non https) il service worker non si installa,');
	console.log('quindi niente offline e niente notifiche. La premiazione funziona.');
}
