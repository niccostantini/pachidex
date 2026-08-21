/**
 * Ridimensiona e alleggerisce le foto di riferimento.
 *
 *   node scripts/prepara-riferimenti.mjs
 *
 * Finiscono nel bundle e nel precache del service worker, quindi ogni KB
 * qui e' un KB che i sei telefoni scaricano prima di partire. Si punta a
 * 640px di lato lungo, che a schermo non si distinguono dall'originale.
 */
import { execFileSync } from 'node:child_process';
import { readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const CARTELLA = 'src/assets/riferimenti';
const LATO = 640;

const immagini = readdirSync(CARTELLA).filter((f) => /\.(png|jpe?g|webp)$/i.test(f));

if (!immagini.length) {
	console.log('  Nessuna immagine in ' + CARTELLA + ': non c e niente da fare.');
	process.exit(0);
}

const kb = (p) => statSync(p).size / 1024;
let prima = 0;
let dopo = 0;

for (const nome of immagini) {
	const percorso = join(CARTELLA, nome);
	const partenza = kb(percorso);
	prima += partenza;

	if (/\.webp$/i.test(nome)) {
		// sips su macOS legge i webp ma non sa riscriverli: si lasciano stare.
		dopo += partenza;
		console.log(`  ${nome.padEnd(24)} ${partenza.toFixed(0).padStart(5)}KB  (webp, non toccato)`);
		continue;
	}

	execFileSync('sips', ['-Z', String(LATO), percorso, '--out', percorso], { stdio: 'ignore' });
	const arrivo = kb(percorso);
	dopo += arrivo;
	console.log(
		`  ${nome.padEnd(24)} ${partenza.toFixed(0).padStart(5)}KB -> ${arrivo.toFixed(0)}KB`
	);
}

console.log(`\n  totale: ${prima.toFixed(0)}KB -> ${dopo.toFixed(0)}KB`);
