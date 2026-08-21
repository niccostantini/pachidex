/**
 * Prepara le foto di riferimento per stare dentro l'app.
 *
 *   node scripts/prepara-riferimenti.mjs
 *
 * Prende qualsiasi cosa trovi in src/assets/riferimenti (jpg, png, webp),
 * la riduce a 720px di lato lungo e la ricomprime in WebP. Queste immagini
 * finiscono nel bundle e nel precache del service worker, quindi ogni KB qui
 * e' un KB che sei telefoni scaricano prima di partire.
 *
 * Perche' 720px: nella scheda l'immagine occupa al massimo ~340pt di
 * larghezza su un telefono, che a 2x fa 680 pixel veri. Piu' grande non si
 * vede, pesa e basta.
 *
 * Serve cwebp (`brew install webp`). Senza, ripiega su JPEG.
 */
import { execFileSync } from 'node:child_process';
import { existsSync, readdirSync, renameSync, statSync, unlinkSync } from 'node:fs';
import { join, extname, basename } from 'node:path';

const CARTELLA = 'src/assets/riferimenti';
const LATO = 720;
const QUALITA = 78;
const BUDGET_KB = 90; // oltre questo si segnala: qualcosa non va

const kb = (p) => statSync(p).size / 1024;
const zitto = { stdio: 'ignore' };

const haCwebp = (() => {
	try {
		execFileSync('which', ['cwebp'], zitto);
		return true;
	} catch {
		return false;
	}
})();

if (!haCwebp) {
	console.log('  cwebp non trovato: uso JPEG. Per risultati migliori: brew install webp\n');
}

/** Lato lungo in pixel. sips legge anche i webp, quindi vale per tutti. */
function latoLungo(percorso) {
	const out = execFileSync('sips', ['-g', 'pixelWidth', '-g', 'pixelHeight', percorso], {
		encoding: 'utf8'
	});
	const w = Number(out.match(/pixelWidth:\s*(\d+)/)?.[1] ?? 0);
	const h = Number(out.match(/pixelHeight:\s*(\d+)/)?.[1] ?? 0);
	return Math.max(w, h);
}

const immagini = readdirSync(CARTELLA).filter((f) => /\.(png|jpe?g|webp)$/i.test(f));

if (!immagini.length) {
	console.log(`  Nessuna immagine in ${CARTELLA}: non c'e' niente da fare.`);
	process.exit(0);
}

let prima = 0;
let dopo = 0;
const grosse = [];

for (const nome of immagini) {
	const percorso = join(CARTELLA, nome);
	const partenza = kb(percorso);
	const lato = latoLungo(percorso);
	prima += partenza;

	// Gia' WebP e gia' della dimensione giusta: non si tocca, nemmeno se pesa
	// piu' del budget. Ricomprimerlo a ogni giro perde qualita' ogni volta e
	// non recupera niente: su una foto molto dettagliata il secondo passaggio
	// ha guadagnato 2KB, che non valgono una generazione di artefatti. Il
	// peso eccessivo si segnala e basta: si risolve cambiando foto, non
	// schiacciandola di nuovo.
	if (extname(nome).toLowerCase() === '.webp' && lato <= LATO) {
		dopo += partenza;
		if (partenza > BUDGET_KB) grosse.push(`${nome} (${partenza.toFixed(0)}KB)`);
		console.log(
			`  ${nome.padEnd(26)} ${partenza.toFixed(0).padStart(4)}KB  ${lato}px  gia' a posto`
		);
		continue;
	}

	const radice = basename(nome, extname(nome));
	const tmp = join(CARTELLA, `.tmp-${radice}.png`);

	// sips -Z INGRANDISCE le immagini piu' piccole del bersaglio, gonfiandole
	// senza aggiungere un solo dettaglio: si ridimensiona solo in discesa.
	if (lato > LATO) {
		execFileSync('sips', ['-Z', String(LATO), '-s', 'format', 'png', percorso, '--out', tmp], zitto);
	} else {
		execFileSync('sips', ['-s', 'format', 'png', percorso, '--out', tmp], zitto);
	}

	const finale = join(CARTELLA, `${radice}.${haCwebp ? 'webp' : 'jpg'}`);

	if (haCwebp) {
		execFileSync('cwebp', ['-q', String(QUALITA), '-quiet', tmp, '-o', finale], zitto);
	} else {
		execFileSync('sips', ['-s', 'format', 'jpeg', '-s', 'formatOptions', '70', tmp, '--out', finale], zitto);
	}

	unlinkSync(tmp);
	// L'originale sparisce solo se ha prodotto un file con un altro nome.
	if (percorso !== finale && existsSync(percorso)) unlinkSync(percorso);

	const arrivo = kb(finale);
	dopo += arrivo;
	const latoFinale = Math.min(lato, LATO);
	if (arrivo > BUDGET_KB) grosse.push(`${basename(finale)} (${arrivo.toFixed(0)}KB)`);

	console.log(
		`  ${nome.padEnd(26)} ${partenza.toFixed(0).padStart(4)}KB -> ` +
			`${arrivo.toFixed(0).padStart(4)}KB  ${latoFinale}px`
	);
}

console.log(`\n  ${immagini.length} immagini: ${prima.toFixed(0)}KB -> ${dopo.toFixed(0)}KB`);
console.log(`  peso aggiunto all'app: ${dopo.toFixed(0)}KB`);

if (grosse.length) {
	console.log(`\n  Sopra i ${BUDGET_KB}KB, forse vale la pena guardarle:`);
	for (const g of grosse) console.log(`    ${g}`);
}
