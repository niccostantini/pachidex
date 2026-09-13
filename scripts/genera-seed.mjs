/**
 * Genera supabase/seed.sql: il catalogo vero piu' una vacanza finta.
 *
 * Il catalogo si legge da supabase/catalogo.json (sono contenuti di gioco,
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

/**
 * Gli account, come in produzione: chi gioca, chi amministra e chi guarda.
 *
 * Admin e Spione stanno fuori dalla partita (`nascosto`) e non prendono parte
 * a niente. Un admin che gioca falserebbe proprio le cose che in locale si
 * vogliono provare: le maggioranze delle contestazioni, i conteggi dei set,
 * la premiazione.
 */
const ACCOUNT = [
	{ nome: 'Admin', admin: true, solaLettura: false, nascosto: true },
	...GIOCATORI.map((nome) => ({ nome, admin: false, solaLettura: false, nascosto: false })),
	{ nome: 'Spione', admin: false, solaLettura: true, nascosto: true }
];
/** Password uguale per tutti in locale: e' un ambiente di prova. */
const PAROLA = 'prova1234';
/**
 * La vacanza finta si muove col calendario, invece di stare ferma ad agosto.
 *
 * Serve perche' il seme apre anche una stagione, e una stagione e' una
 * finestra sugli ultimi giorni: con date fissate a un anno fa le catture
 * cadrebbero tutte fuori, e il locale partirebbe con una classifica vuota e
 * nessun titolo assegnato — cioe' senza niente da guardare.
 *
 * Cosi' invece si apre l'app e si trova una stagione al tredicesimo giorno su
 * quattordici: classifica piena, titoli in ballo, e la chiusura a un giorno
 * di distanza, che e' esattamente la cosa piu' scomoda da provare a mano.
 *
 * Il contenuto resta deterministico — stesso seme, stessa partita — a
 * muoversi sono solo le date.
 */
const GIORNI_STAGIONE = 14;
const APERTA_DA = 13;

const giorniFa = (quanti, ora) => {
	const d = new Date();
	d.setDate(d.getDate() - quanti);
	d.setHours(ora, 0, 0, 0);
	return d;
};
/** "2026-09-13": la data com'e' scritta in un campo date. */
const giorno = (d) =>
	`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

const INIZIO = giorniFa(APERTA_DA, 9);
const FINE = giorniFa(APERTA_DA - 4, 22);
const SCADENZA = giorniFa(APERTA_DA - GIORNI_STAGIONE, 0);

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
-- Il catalogo e' quello vero, tenuto in supabase/catalogo.json. La vacanza
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
${ACCOUNT
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
		now(), now(),
		${q(JSON.stringify({ provider: 'email', providers: ['email'], is_admin: u.admin, sola_lettura: u.solaLettura, nascosto: u.nascosto }))},
		${q(JSON.stringify({ nome: u.nome }))},
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
-- Il like si data poco dopo la foto, non al momento in cui gira il seme:
-- altrimenti cade fuori dalla stagione e "La piaciona" non la vince nessuno.
-- E' lo stesso inciampo degli scambi e della contestazione — la terza volta
-- che il seme timbrava "adesso" qualcosa che era successo durante la vacanza.
insert into reactions (capture_id, user_id, created_at)
select c.id, u.id, c.timestamp + interval '3 hours'
from captures c
join users u on u.id <> c.user_id
where (extract(epoch from c.timestamp)::bigint + length(u.nome)) % 5 = 0
on conflict do nothing;`);

// --- Fa' Oversharing --------------------------------------------------------
// Le frasi della vacanza. Datate dentro la stagione come tutto il resto — e
// i voti due ore dopo la frase, non al momento in cui gira il seme: e' lo
// stesso inciampo dei like, degli scambi e della contestazione, e a questo
// punto e' una regola: nel seme non si timbra mai "adesso".
const FRASI = [
	['Vito', 1, 10, 3, 'il bagnino mi ha guardato male perche’ ho portato la granita in acqua', [['Rosa', 'chic'], ['Nina', 'chic'], ['Turi', 'chic'], ['Ciccio', 'cheap']]],
	['Rosa', 1, 20, 7, 'ho contato quattordici gatti nella stessa piazza. quattordici.', [['Vito', 'chic'], ['Nina', 'chic'], ['Lella', 'chic'], ['Ciccio', 'chic'], ['Turi', 'chic']]],
	['Ciccio', 2, 14, 20, 'secondo me l’arancino si puo’ mangiare anche a colazione, e l’ho dimostrato', [['Vito', 'chic'], ['Rosa', 'cheap'], ['Nina', 'cheap'], ['Lella', 'chic']]],
	['Nina', 3, 8, 17, 'sveglia alle sette per vedere l’alba, vista l’alba, tornata a letto', [['Rosa', 'chic'], ['Lella', 'chic'], ['Vito', 'chic'], ['Turi', 'cheap']]],
	['Turi', 4, 23, 11, 'ragazzi il condizionatore fa un rumore che secondo me e’ un animale, @Nina vieni a sentire', [['Vito', 'cheap'], ['Rosa', 'cheap'], ['Nina', 'cheap'], ['Ciccio', 'cheap'], ['Lella', 'cheap']]],
	['Lella', 5, 13, 22, 'ho chiesto indicazioni a un signore e mi ha raccontato tutta la sua vita, bellissimo', [['Rosa', 'chic'], ['Nina', 'chic'], ['Ciccio', 'chic']]],
	['Ciccio', 6, 19, 13, 'ho perso le infradito in mare. una sola. l’altra la tengo per ricordo', [['Vito', 'chic'], ['Turi', 'chic'], ['Lella', 'cheap'], ['Nina', 'chic']]],
	['Rosa', 7, 12, 1, 'propongo una tassa di dieci croquembouche per chi lascia la sabbia in macchina, dico a te @Ciccio', [['Turi', 'cheap'], ['Ciccio', 'cheap'], ['Vito', 'chic'], ['Lella', 'chic']]],
	['Turi', 8, 17, 15, 'sto guardando due formiche che portano via una briciola piu’ grande di loro e mi commuovo', [['Nina', 'chic'], ['Lella', 'cheap'], ['Rosa', 'cheap']]],
	['Vito', 9, 22, 23, 'oggi non ho fatto niente e mi sembra il mio capolavoro', [['Rosa', 'chic'], ['Nina', 'chic'], ['Ciccio', 'chic'], ['Lella', 'chic'], ['Turi', 'chic']]]
];

scrivi(`
-- --- Fa' Oversharing --------------------------------------------------------
-- Dieci frasi, con la loro formula gia' scelta: nel gioco vero si pesca a
-- caso, qui e' fissa cosi' il seme viene sempre uguale. Due hanno dentro una
-- @menzione, che non vale Croquembouche e serve solo a far squillare un
-- telefono.`);

for (const [chi, giorniDopo, ora, formula, testo, voti] of FRASI) {
	const quando = new Date(INIZIO.getTime() + giorniDopo * 86400000 + ora * 3600000);
	const votati = new Date(quando.getTime() + 2 * 3600000);
	scrivi(`
with o as (
	insert into oversharing (user_id, testo, formula_id, created_at)
	select u.id, ${q(testo)}, (select id from formule where ordine = ${formula}),
	       timestamptz ${q(quando.toISOString())}
	from users u where u.nome = ${q(chi)}
	returning id
)
insert into oversharing_voti (oversharing_id, user_id, voto, created_at)
select o.id, u.id, v.voto, timestamptz ${q(votati.toISOString())}
from o, (values ${voti.map(([n2, v]) => `(${q(n2)}, ${q(v)})`).join(', ')}) as v(nome, voto)
join users u on u.nome = v.nome;`);
}

scrivi(`
-- --- due scambi -------------------------------------------------------------
-- Datati dentro la vacanza, non al momento in cui gira il seme: altrimenti
-- cadono fuori dalla stagione che li contiene e restano nel feed anche dopo
-- averla svuotata, che e' esattamente come si e' scoperto il problema.
insert into transfers (from_user_id, to_user_id, importo, causale, created_at)
select a.id, b.id, 25, 'per la birra', timestamptz ${q(new Date(INIZIO.getTime() + 2 * 86400000).toISOString())}
from users a, users b where a.nome = ${q(GIOCATORI[0])} and b.nome = ${q(GIOCATORI[1])};

insert into transfers (from_user_id, to_user_id, importo, causale, created_at)
select a.id, b.id, 10, 'scommessa persa', timestamptz ${q(new Date(INIZIO.getTime() + 3 * 86400000).toISOString())}
from users a, users b where a.nome = ${q(GIOCATORI[2])} and b.nome = ${q(GIOCATORI[3])};`);

scrivi(`
-- --- una contestazione gia' chiusa, cosi' si vede una cattura invalidata ----
do $$
declare v_c uuid; v_chi uuid;
begin
	select c.id into v_c from captures c
	join users u on u.id = c.user_id
	where u.nome = ${q(GIOCATORI[4])} order by c.timestamp desc limit 1;
	select id into v_chi from users where nome = ${q(GIOCATORI[1])};
	if v_c is not null then
		-- La funzione pubblica prende l'identita' da auth.uid(), che qui non
		-- c'e': il seme gira come postgres senza sessione. Si chiama quella
		-- interna, che l'autore lo riceve come parametro.
		perform apri_contestazione_interna(v_c, v_chi, 'Questa foto non convince nessuno');
		-- gli altri votano contro: la maggioranza la invalida
		insert into votes (contest_id, user_id, voto)
		select co.id, u.id, 'non_valido'
		from contests co, users u
		where co.capture_id = v_c and u.nome in (${[GIOCATORI[0], GIOCATORI[2], GIOCATORI[3]].map(q).join(', ')})
		on conflict do nothing;
		perform risolvi_contestazione((select id from contests where capture_id = v_c));

		-- E la si ridata dentro la vacanza finta, il giorno dopo la cattura
		-- che punisce. Altrimenti resta timbrata al momento in cui gira il
		-- seme: aprendo una stagione, quella penalita' di quindici cadrebbe
		-- nella settimana in corso per una cattura di dieci giorni prima, e
		-- qualcuno si ritroverebbe a -10 senza aver fatto niente. E' successo.
		update contests set
			created_at = (select c.timestamp + interval '20 hours' from captures c where c.id = v_c),
			scadenza   = (select c.timestamp + interval '44 hours' from captures c where c.id = v_c),
			risolta_at = (select c.timestamp + interval '26 hours' from captures c where c.id = v_c)
		where capture_id = v_c;
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

scrivi(`
-- --- e una stagione gia' in corso -------------------------------------------
-- Il locale si apre su una partita a meta' strada: tredici giorni su
-- quattordici, con dentro tutto quello che e' successo qui sopra. Cosi' la
-- classifica ha dei numeri, i titoli hanno un padrone, e la chiusura — con le
-- coccarde e «Queste siete» — si prova premendo un pulsante invece di
-- aspettare due settimane.
--
-- Prima la stagione zero, come farebbe apri_stagione: il passato congelato.
-- Qui e' vuota per definizione, visto che la vacanza finta comincia con la
-- stagione, ma esserci cambia la forma dei conti e vale la pena che il locale
-- abbia la stessa forma della produzione.
insert into stagioni (numero, inizio, fine, chiusa_at)
values (0, '-infinity', date '${giorno(INIZIO)}', now());
select congela_stagione(0);

insert into stagioni (numero, inizio, fine)
values (1, date '${giorno(INIZIO)}', date '${giorno(SCADENZA)}');

-- In gioco c'e' tutto il catalogo, non il terzo sorteggiato: il seme deve
-- mostrare i nove set che funzionano, e con un terzo la meta' non si
-- potrebbe chiudere. Il sorteggio vero si vede aprendo una stagione dal
-- pannello.
select sorteggia_catalogo(1, 1.0);

-- "Il primo giorno" e' un set legato a una data precisa, scritta nella 0020
-- quando la vacanza era ad agosto. Si sposta sul primo giorno di questa,
-- altrimenti resta li' a non potersi chiudere mai.
update game_sets set giorno = date '${giorno(INIZIO)}' where nome = 'Il primo giorno';`);

writeFileSync(new URL('../supabase/seed.sql', import.meta.url), righe.join('\n') + '\n');
console.log(`seed.sql scritto: ${item.length} elementi, ${catture.length} catture`);
