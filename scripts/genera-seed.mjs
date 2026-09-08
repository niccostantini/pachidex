/**
 * Genera supabase/seed.sql: il catalogo vero piu' una vacanza finta.
 *
 * Il catalogo si scarica dall'API di produzione (sono contenuti di gioco,
 * niente di personale) cosi' l'ambiente locale ha le stesse 136 sfiziosita' e
 * i set e i titoli hanno qualcosa su cui lavorare davvero.
 *
 * L'attivita' invece e' inventata, ma deterministica: stesso seme, stessi
 * dati. Cosi' due persone che fanno "npm run db:reset" vedono la stessa
 * partita e possono parlarne.
 *
 *   node scripts/genera-seed.mjs
 */
import { readFileSync, writeFileSync } from 'node:fs';

/**
 * Nomi inventati apposta: seed.sql sta nel repository, e il repository puo'
 * diventare pubblico. I giocatori veri li crei dal pannello.
 */
const GIOCATORI = ['Vito', 'Rosa', 'Turi', 'Nina', 'Ciccio', 'Lella'];
/** Password uguale per tutti in locale: e' un ambiente di prova. */
const PAROLA = 'prova1234';
const INIZIO = new Date('2026-08-28T09:00:00+02:00');
const FINE = new Date('2026-09-01T22:00:00+02:00');

/** Numeri a caso ma sempre gli stessi: un generatore con seme. */
let seme = 20260828;
const caso = () => ((seme = (seme * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
const fra = (a, b) => a + Math.floor(caso() * (b - a));
const scegli = (a) => a[fra(0, a.length)];

const q = (v) => (v === null || v === undefined || v === '' ? 'null' : `'${String(v).replace(/'/g, "''")}'`);
const n = (v) => (v === null || v === undefined || v === '' ? 'null' : Number(v));

/**
 * Il catalogo si legge da un file e non piu' dalla produzione: quel progetto
 * Supabase non esiste piu', e comunque un generatore che ha bisogno della
 * rete per fare un ambiente locale e' un controsenso.
 */
function catalogo() {
	return JSON.parse(readFileSync(new URL('../supabase/catalogo.json', import.meta.url), 'utf8'));
}

const righe = [];
const scrivi = (s = '') => righe.push(s);

const item = catalogo();
if (!item.length) throw new Error('Catalogo vuoto: controlla .env');

scrivi(`-- ============================================================================
-- Pachino Express — dati per l'ambiente locale
--
-- GENERATO DA scripts/genera-seed.mjs — non modificarlo a mano, si rifa'.
--
-- Il catalogo e' quello vero, scaricato dall'API di produzione. La vacanza
-- qui sotto e' inventata ma deterministica: stesso seme, stessa partita.
--
-- Le foto puntano a un'icona statica servita dal dev server: cosi' il feed
-- funziona anche senza rete e senza credenziali R2.
-- ============================================================================

-- I giocatori nascono da account veri: dalla 0027 ogni riga di users e'
-- figlia di auth.users, quindi qui si creano prima gli account.
--
-- Password di tutti in locale: ${PAROLA}
-- Si entra col NOME UTENTE: l'email tecnica non la vede nessuno.

-- --- gli account ------------------------------------------------------------
${[...GIOCATORI.map((g) => ({ nome: g, admin: g === 'Vito', spia: false })),
   { nome: 'Spione', admin: false, spia: true }]
	.map(
		(u) => `
with nuovo as (
	insert into auth.users (
		instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
		created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
		-- Queste colonne vanno a stringa vuota e non a NULL: chi legge gli
		-- account le mette in campi di testo non nullable e su NULL si pianta
		-- con un "Database error querying schema" che non dice niente.
		confirmation_token, recovery_token, email_change_token_new, email_change,
		email_change_token_current, phone_change, phone_change_token, reauthentication_token
	) values (
		'00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated',
		${q(u.nome.toLowerCase() + '@pachidex.local')}, crypt(${q(PAROLA)}, gen_salt('bf')), now(),
		now(), now(), '{"provider":"email","providers":["email"]}',
		${q(JSON.stringify({ nome: u.nome, is_admin: u.admin, sola_lettura: u.spia, nascosto: u.spia }))},
		'', '', '', '', '', '', '', ''
	)
	returning id, email
)
insert into auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), n.id,
       json_build_object('sub', n.id::text, 'email', n.email)::jsonb,
       'email', n.id::text, now(), now(), now()
from nuovo n;`
	)
	.join('\n')}

-- --- il catalogo ------------------------------------------------------------`);

for (const i of item) {
	scrivi(
		`insert into items (nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng, riferimento) values (` +
			[q(i.nome), q(i.categoria), q(i.rarita), n(i.croquembouche), i.ripetibile ? 'true' : 'false',
			 q(i.validazione), q(i.note), n(i.lat), n(i.lng), q(i.riferimento)].join(', ') +
			`) on conflict do nothing;`
	);
}

// --- la vacanza finta -------------------------------------------------------
// Ogni giocatore prende un pugno di elementi diversi: i non ripetibili non si
// possono duplicare (c'e' un trigger apposta) quindi si tiene il conto.
const presi = new Map(GIOCATORI.map((g) => [g, new Set()]));
const catture = [];
const durata = FINE - INIZIO;

for (const chi of GIOCATORI) {
	const quante = fra(9, 18);
	for (let k = 0; k < quante; k++) {
		const it = scegli(item);
		if (presi.get(chi).has(it.nome) && !it.ripetibile) continue;
		presi.get(chi).add(it.nome);
		const quando = new Date(INIZIO.getTime() + Math.floor(caso() * durata));
		catture.push({ chi, nome: it.nome, quando });
	}
}
catture.sort((a, b) => a.quando - b.quando);

scrivi(`
-- --- la vacanza -------------------------------------------------------------
-- ${catture.length} catture fra il 28 agosto e il primo settembre.`);

catture.forEach((c, idx) => {
	// Un terzo delle catture tagga qualcun altro: serve a provare i crediti da
	// tag, i set di gruppo e il feed "vale anche per".
	const compagni = caso() < 0.34 ? [scegli(GIOCATORI.filter((g) => g !== c.chi))] : [];
	scrivi(`
with c as (
	insert into captures (user_id, item_id, foto_url, nota, timestamp, stato)
	select u.id, i.id, '/icon-512.png', ${compagni.length ? q('Con @' + compagni[0]) : 'null'},
	       timestamptz ${q(c.quando.toISOString())}, 'valido'
	from users u, items i
	where u.nome = ${q(c.chi)} and i.nome = ${q(c.nome)}
	returning id
)${
		compagni.length
			? `
insert into capture_tags (capture_id, user_id)
select c.id, u.id from c, users u where u.nome = ${q(compagni[0])};`
			: `
select id from c;`
	}`);
});

// Qualche like sparso, per la "piaciona" e per la foto del giorno.
scrivi(`
-- --- like -------------------------------------------------------------------
insert into reactions (capture_id, user_id)
select c.id, u.id
from captures c
join users u on u.id <> c.user_id
where (extract(epoch from c.timestamp)::bigint + length(u.nome)) % 5 = 0
on conflict do nothing;`);

scrivi(`
-- --- due scambi -------------------------------------------------------------
insert into transfers (from_user_id, to_user_id, importo, causale)
select a.id, b.id, 25, 'per la birra'
from users a, users b where a.nome = 'Gu' and b.nome = 'BF';

insert into transfers (from_user_id, to_user_id, importo, causale)
select a.id, b.id, 10, 'scommessa persa'
from users a, users b where a.nome = 'Nicco' and b.nome = 'Aliona';`);

scrivi(`
-- --- una contestazione gia' chiusa, cosi' si vede una cattura invalidata ----
do $$
declare v_c uuid; v_chi uuid;
begin
	select c.id into v_c from captures c
	join users u on u.id = c.user_id
	where u.nome = 'MirkoTheBest' order by c.timestamp desc limit 1;
	select id into v_chi from users where nome = 'BF';
	if v_c is not null then
		perform apri_contestazione(v_c, v_chi, 'Questa foto non convince nessuno');
		-- gli altri votano contro: la maggioranza la invalida
		insert into votes (contest_id, user_id, voto)
		select co.id, u.id, 'non_valido'
		from contests co, users u
		where co.capture_id = v_c and u.nome in ('Nicco', 'Gu', 'Aliona')
		on conflict do nothing;
		perform risolvi_contestazione((select id from contests where capture_id = v_c));
	end if;
end $$;`);

scrivi(`
-- --- i premi della cerimonia ------------------------------------------------
-- Segnaposto per provare la premiazione in locale: quelli veri si scrivono
-- dal pannello.
insert into premi (numero, domanda, croquembouche) values
	(1, 'CHI HA CUCINATO DI PIÙ?', 40),
	(2, 'CHI HA FATTO LA FOTO PIÙ BELLA?', 40),
	(3, 'CHI SI È SVEGLIATO SEMPRE PER ULTIMO?', 40),
	(4, 'CHI SI È LAMENTATO DI PIÙ?', 40),
	(5, 'CHI HA GUIDATO DI PIÙ?', 40),
	(6, 'CHI HA DETTO LA COSA PIÙ SCEMA?', 40),
	(7, 'CHI CI HA TENUTI INSIEME?', 60)
on conflict (numero) do nothing;`);

writeFileSync(new URL('../supabase/seed.sql', import.meta.url), righe.join('\n') + '\n');
console.log(`seed.sql scritto: ${item.length} elementi, ${catture.length} catture`);
