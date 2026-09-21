/**
 * Porta dentro i luoghi di Roma dove possono comparire i blocchi «?».
 *
 * Li chiede a OpenStreetMap (Overpass) e li scrive nella tabella `luoghi`.
 * Rilanciarlo aggiorna nomi e posizioni senza toccare `attivo`: un luogo tolto
 * dalle segnalazioni resta tolto.
 *
 *   node scripts/importa-luoghi.mjs          -> Supabase locale (.env.local)
 *   node scripts/importa-luoghi.mjs --prod   -> produzione (.env)
 *
 * La sicurezza sta nella whitelist: entra solo cio' che e' pubblico e ci si
 * va a piedi. Una blacklist lascerebbe passare tutto quello a cui non si e'
 * pensato.
 */
import { existsSync, readFileSync } from 'node:fs';

const prod = process.argv.includes('--prod');

function leggiEnv(file) {
	const url = new URL(`../${file}`, import.meta.url);
	if (!existsSync(url)) return {};
	return Object.fromEntries(
		readFileSync(url, 'utf8')
			.split('\n')
			.filter((r) => r.includes('=') && !r.trim().startsWith('#'))
			.map((r) => {
				const i = r.indexOf('=');
				return [r.slice(0, i).trim(), r.slice(i + 1).trim().replace(/^["']|["']$/g, '')];
			})
	);
}

// Come fa Vite: .env.local sopra .env. In produzione solo .env.
const env = prod ? leggiEnv('.env') : { ...leggiEnv('.env'), ...leggiEnv('.env.local') };
const URL_DB = env.PUBLIC_SUPABASE_URL;
const CHIAVE = env.SUPABASE_SERVICE_ROLE_KEY;
if (!URL_DB || !CHIAVE) {
	console.error('Mancano PUBLIC_SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY');
	process.exit(1);
}

// L'ordine conta: in una cella affollata restano i primi della lista.
const PIAZZA = /^(piazza|piazzale|piazzetta|largo|slargo)\b/i;

const TIPI = [
	// Anche le piazze minori: spesso non sono place=square ma una strada che
	// si chiama "Piazza …" o "Largo …", e sono le uniche di molti quartieri.
	['piazza', (t) => t.place === 'square' || (t.highway && PIAZZA.test(t.name ?? ''))],
	['parco', (t) => ['park', 'garden', 'playground'].includes(t.leisure)],
	['monumento', (t) => t.tourism === 'attraction' || t.historic],
	['fontana', (t) => t.amenity === 'fountain'],
	['museo', (t) => t.tourism === 'museum'],
	['panorama', (t) => t.tourism === 'viewpoint'],
	['mercato', (t) => t.amenity === 'marketplace'],
	['biblioteca', (t) => t.amenity === 'library'],
	['stazione', (t) => t.railway === 'station' || t.public_transport === 'station'],
	['chiesa', (t) => t.amenity === 'place_of_worship'],
	['arte', (t) => t.tourism === 'artwork'],
	['via', (t) => t.highway === 'pedestrian'],
	// I nasoni: migliaia, pubblici, per strada e in ogni quartiere. Sono loro
	// a coprire la periferia, dove di monumenti ce ne sono pochi.
	['nasone', (t) => t.amenity === 'drinking_water']
];

const QUERY = `
[out:json][timeout:300];
area["name"="Roma"]["admin_level"="8"]->.roma;
(
  nwr["place"="square"]["name"](area.roma);
  way["highway"]["name"~"^(Piazza|Piazzale|Piazzetta|Largo|Slargo) "](area.roma);
  nwr["leisure"~"^(park|garden|playground)$"]["name"](area.roma);
  nwr["tourism"~"^(attraction|viewpoint|museum|artwork)$"]["name"](area.roma);
  nwr["historic"]["name"](area.roma);
  nwr["amenity"~"^(fountain|place_of_worship|marketplace|library)$"]["name"](area.roma);
  nwr["railway"="station"]["name"](area.roma);
  way["highway"="pedestrian"]["name"](area.roma);
  node["amenity"="drinking_water"](area.roma);
);
out center tags;
`;

// Le stesse celle da ~250 m della migration 0056: devono coincidere.
const cella = (lat, lng) => `${Math.floor(lat / 0.00225)}:${Math.floor(lng / 0.003)}`;
const PER_CELLA = 3;

// Il server principale e' spesso pieno e risponde 504: si prova il prossimo.
const SERVER = [
	'https://overpass-api.de/api/interpreter',
	'https://overpass.private.coffee/api/interpreter',
	'https://maps.mail.ru/osm/tools/overpass/api/interpreter'
];

async function chiediOverpass() {
	for (const server of SERVER) {
		console.log(`Chiedo i luoghi a ${new URL(server).host} (ci mette un paio di minuti)…`);
		const r = await fetch(server, {
			method: 'POST',
			// Senza un User-Agent riconoscibile Overpass risponde 406.
			headers: { 'User-Agent': 'pachidex-importa-luoghi/1.0', Accept: 'application/json' },
			body: new URLSearchParams({ data: QUERY })
		}).catch((e) => ({ ok: false, status: e.message }));
		if (r.ok) return r.json();
		console.warn(`  risponde ${r.status}`);
	}
	throw new Error('Nessun server Overpass ha risposto');
}

const { elements } = await chiediOverpass();

const scartati = { privati: 0, senzaTipo: 0, affollati: 0 };
const perCella = new Map();

for (const e of elements) {
	const t = e.tags ?? {};
	// Privato, chiuso o dentro un recinto: fuori.
	if (['private', 'no', 'customers'].includes(t.access)) {
		scartati.privati++;
		continue;
	}
	// Delle strade entrano solo le pedonali e quelle che sono piazze. Mai
	// quelle a scorrimento veloce, anche se si chiamano "Piazzale".
	if (t.highway && t.highway !== 'pedestrian' && !PIAZZA.test(t.name ?? '')) continue;
	if (['motorway', 'trunk', 'primary', 'motorway_link', 'trunk_link'].includes(t.highway)) continue;
	const tipo = TIPI.findIndex(([, prova]) => prova(t));
	if (tipo < 0) {
		scartati.senzaTipo++;
		continue;
	}
	const lat = e.lat ?? e.center?.lat;
	const lng = e.lon ?? e.center?.lon;
	if (lat == null || lng == null) continue;

	const k = cella(lat, lng);
	const lista = perCella.get(k) ?? [];
	// I nasoni non hanno quasi mai un nome: prendono quello della cosa.
	const nome = t.name ?? 'Nasone';
	// Lo stesso posto arriva spesso due volte (il nodo e l'area, o una piazza
	// spezzata in piu' tratti di strada): un nome per cella.
	if (lista.some((l) => l.nome === nome)) continue;
	lista.push({ id: `${e.type[0]}${e.id}`, nome, lat, lng, tipo: TIPI[tipo][0], ordine: tipo });
	perCella.set(k, lista);
}

const luoghi = [];
for (const lista of perCella.values()) {
	lista.sort((a, b) => a.ordine - b.ordine);
	scartati.affollati += Math.max(0, lista.length - PER_CELLA);
	luoghi.push(...lista.slice(0, PER_CELLA).map(({ ordine, ...l }) => l));
}

console.log(
	`${elements.length} da Overpass, ${luoghi.length} tenuti in ${perCella.size} celle ` +
		`(${scartati.privati} privati, ${scartati.affollati} di troppo in celle affollate)`
);

for (let i = 0; i < luoghi.length; i += 500) {
	const r = await fetch(`${URL_DB}/rest/v1/luoghi?on_conflict=id`, {
		method: 'POST',
		headers: {
			apikey: CHIAVE,
			Authorization: `Bearer ${CHIAVE}`,
			'Content-Type': 'application/json',
			Prefer: 'resolution=merge-duplicates,return=minimal'
		},
		body: JSON.stringify(luoghi.slice(i, i + 500))
	});
	if (!r.ok) throw new Error(`Scrittura fallita: ${r.status} ${await r.text()}`);
}

console.log(`Fatto: ${luoghi.length} luoghi su ${prod ? 'produzione' : 'locale'}.`);
