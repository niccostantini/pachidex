/**
 * Converte il TTF di Ithaca nel woff2 che l'app carica davvero.
 *
 *   node scripts/build-font.mjs
 *
 * Il TTF originale resta in src/assets/fonts come sorgente; qui si produce
 * la versione compressa e ridotta ai soli caratteri che servono all'italiano,
 * perche' l'originale porta oltre mille glifi di cui ne usiamo un decimo.
 *
 * Richiede fonttools con supporto woff2:  pip install "fonttools[woff]"
 */
import { execFileSync } from 'node:child_process';
import { statSync } from 'node:fs';

const SORGENTE = 'src/assets/fonts/Ithaca-LVB75.ttf';
const USCITA = 'src/assets/fonts/ithaca.woff2';

// Latino base ed esteso, punteggiatura, simboli di valuta: tutto cio' che
// serve a scrivere in italiano. I simboli geometrici della UI (✦ ▸ ★ …) non
// sono in Ithaca a prescindere, quindi non c'e' niente da conservare.
const UNICODI = [
	'U+0000-00FF', // latino base + Latin-1 (include à è é ì ò ù)
	'U+0100-017F', // latino esteso A
	'U+2018-201F', // virgolette curve
	'U+2013-2014', // trattini
	'U+2026', // ellissi
	'U+00B7,U+2022', // separatori
	'U+20AC' // euro
].join(',');

const kb = (p) => (statSync(p).size / 1024).toFixed(1);

execFileSync(
	'pyftsubset',
	[
		SORGENTE,
		`--unicodes=${UNICODI}`,
		'--flavor=woff2',
		'--layout-features=*',
		`--output-file=${USCITA}`
	],
	{ stdio: 'inherit' }
);

console.log(`${SORGENTE}  ${kb(SORGENTE)}KB`);
console.log(`${USCITA}  ${kb(USCITA)}KB`);
