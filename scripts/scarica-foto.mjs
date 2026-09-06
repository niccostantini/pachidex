/**
 * Porta a casa le foto della vacanza.
 *
 * Scarica ogni cattura da R2 e le rinomina in ordine cronologico, cosi' una
 * cartella ordinata per nome e' la vacanza in ordine di come e' successa.
 * Accanto ci mette un indice leggibile con didascalie, taggati e valore.
 *
 * Legge .env di proposito e NON .env.local: quest'ultimo punta al Supabase
 * locale, e le foto vere stanno in produzione.
 *
 *   node scripts/scarica-foto.mjs [cartella]
 */
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const env = Object.fromEntries(
	readFileSync(new URL('../.env', import.meta.url), 'utf8')
		.split('\n')
		.filter((r) => r.includes('=') && !r.trim().startsWith('#'))
		.map((r) => {
			const i = r.indexOf('=');
			return [r.slice(0, i).trim(), r.slice(i + 1).trim().replace(/^["']|["']$/g, '')];
		})
);

const DOVE = process.argv[2] ?? join(homedir(), 'Desktop', 'PachinoExpress-foto');

/** Nomi di file che sopravvivono a qualsiasi sistema: niente accenti, niente spazi. */
const pulisci = (s) =>
	s
		.normalize('NFD')
		.replace(/[̀-ͯ]/g, '')
		.replace(/['’]/g, '')
		.replace(/[^a-zA-Z0-9]+/g, '-')
		.replace(/^-|-$/g, '')
		.slice(0, 60);

const due = (n) => String(n).padStart(2, '0');
/**
 * Il progressivo va a tre cifre anche sotto il 100: con due, "100" si mette
 * in mezzo fra "10" e "11" in qualsiasi elenco ordinato per nome, e la
 * cartella smette di raccontare la vacanza in ordine.
 */
const tre = (n) => String(n).padStart(3, '0');

async function catture() {
	const select =
		'select=timestamp,foto_url,nota,stato,item:items(nome,categoria,rarita,croquembouche),' +
		'autore:users(nome),tag:capture_tags(utente:users(nome))';
	const r = await fetch(
		`${env.PUBLIC_SUPABASE_URL}/rest/v1/captures?${select}&order=timestamp.asc`,
		{ headers: { apikey: env.PUBLIC_SUPABASE_ANON_KEY } }
	);
	if (!r.ok) throw new Error(`Le catture non arrivano: ${r.status}`);
	return r.json();
}

const righe = await catture();
mkdirSync(DOVE, { recursive: true });
console.log(`${righe.length} catture da scaricare in ${DOVE}\n`);

const indice = [];
let fatte = 0;
let mancate = 0;

for (const [i, c] of righe.entries()) {
	const d = new Date(c.timestamp);
	const giorno = `${d.getFullYear()}-${due(d.getMonth() + 1)}-${due(d.getDate())}`;
	const ora = `${due(d.getHours())}${due(d.getMinutes())}`;
	const est = (c.foto_url.split('.').pop() ?? 'webp').split('?')[0].slice(0, 5);
	const nome =
		`${tre(i + 1)}_${giorno}_${ora}_${pulisci(c.autore?.nome ?? 'ignoto')}_` +
		`${pulisci(c.item?.nome ?? 'sconosciuto')}` +
		`${c.stato === 'invalidato' ? '_CONTESTATA' : ''}.${est}`;

	const taggati = (c.tag ?? []).map((t) => t.utente?.nome).filter(Boolean);
	indice.push({
		file: nome,
		quando: `${giorno} ${due(d.getHours())}:${due(d.getMinutes())}`,
		autore: c.autore?.nome ?? '',
		elemento: c.item?.nome ?? '',
		categoria: c.item?.categoria ?? '',
		rarita: c.item?.rarita ?? '',
		croquembouche: c.item?.croquembouche ?? '',
		taggati: taggati.join(' '),
		nota: (c.nota ?? '').replace(/\s+/g, ' ').trim(),
		stato: c.stato
	});

	try {
		// Quello che c'e' gia' non si riscarica: rilanciare lo script dopo
		// un'interruzione costa secondi invece di mezzo giga.
		if (existsSync(join(DOVE, nome))) {
			fatte++;
			continue;
		}
		// curl e non fetch: scrive direttamente su disco senza tenere in memoria
		// nulla, e segue i redirect del CDN da solo.
		execFileSync('curl', ['-sfL', '--retry', '2', '-o', join(DOVE, nome), c.foto_url]);
		fatte++;
		process.stdout.write(`\r  scaricate ${fatte}/${righe.length}`);
	} catch {
		mancate++;
		indice.at(-1).file = `(non scaricata) ${nome}`;
	}
}

// Indice in due formati: uno da leggere, uno da aprire con un foglio di calcolo.
const intestazioni = Object.keys(indice[0] ?? { file: '' });
writeFileSync(
	join(DOVE, 'elenco.csv'),
	[intestazioni.join(','), ...indice.map((r) => intestazioni.map((k) => `"${String(r[k]).replace(/"/g, '""')}"`).join(','))].join('\n')
);

writeFileSync(
	join(DOVE, 'elenco.md'),
	`# Pachino Express — le foto\n\n${righe.length} catture, dalla prima all'ultima.\n\n` +
		indice
			.map(
				(r) =>
					`## ${r.file}\n\n- **${r.elemento}** (${r.categoria}, ${r.rarita}, ${r.croquembouche} ✦)\n` +
					`- ${r.autore}${r.taggati ? ` con ${r.taggati}` : ''} — ${r.quando}\n` +
					(r.nota ? `- «${r.nota}»\n` : '') +
					(r.stato === 'invalidato' ? `- contestata e invalidata\n` : '')
			)
			.join('\n')
);

console.log(`\n\nscaricate ${fatte}, mancanti ${mancate}`);
console.log(`indice: elenco.md e elenco.csv`);
