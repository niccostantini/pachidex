/**
 * Collaudo end-to-end contro il database vero.
 *
 *   node scripts/verifica.mjs
 *
 * Percorre l'intero giro di gioco — cattura, contestazione, votazione,
 * penalita', scambio — controllando che i conti tornino, poi cancella tutto
 * quello che ha creato. Non tocca i dati di gioco esistenti: lavora su un
 * elemento temporaneo riconoscibile e lo rimuove alla fine.
 *
 * Serve un .env riempito con URL e anon key.
 */
import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'node:fs';

/* --- ambiente ------------------------------------------------------------ */
const env = Object.fromEntries(
	readFileSync('.env', 'utf8')
		.split('\n')
		.filter((r) => r.trim() && !r.trim().startsWith('#'))
		.map((r) => {
			const i = r.indexOf('=');
			return [r.slice(0, i).trim(), r.slice(i + 1).trim().replace(/^["']|["']$/g, '')];
		})
);

const url = env.PUBLIC_SUPABASE_URL;
const key = env.PUBLIC_SUPABASE_ANON_KEY;

if (!url || !key || url.includes('xxxx')) {
	console.error('\n  Il .env non e ancora riempito con URL e anon key veri.\n');
	process.exit(1);
}

const db = createClient(url, key, {
	auth: { persistSession: false, autoRefreshToken: false }
});

/* --- strumenti ----------------------------------------------------------- */
let passati = 0;
let falliti = 0;
const problemi = [];

function ok(nome, dettaglio = '') {
	passati++;
	console.log(`  \x1b[32m✓\x1b[0m ${nome}${dettaglio ? ` \x1b[2m— ${dettaglio}\x1b[0m` : ''}`);
}

function ko(nome, motivo) {
	falliti++;
	problemi.push(`${nome}: ${motivo}`);
	console.log(`  \x1b[31m✗\x1b[0m ${nome}\n    \x1b[31m${motivo}\x1b[0m`);
}

function verifica(nome, condizione, dettaglio = '') {
	condizione ? ok(nome, dettaglio) : ko(nome, dettaglio || 'condizione non soddisfatta');
	return condizione;
}

const titolo = (t) => console.log(`\n\x1b[1m${t}\x1b[0m`);

const saldoDi = async (id) => {
	const { data } = await db.from('v_saldi').select('saldo').eq('user_id', id).single();
	return data?.saldo ?? null;
};

/* --- stato del collaudo --------------------------------------------------- */
const creato = { itemId: null, captureId: null, transferId: null, file: null };

try {
	/* --- 1. lo schema c'e'? ---------------------------------------------- */
	titolo('Schema');

	for (const t of [
		'users',
		'items',
		'captures',
		'reactions',
		'contests',
		'votes',
		'transfers',
		'game_config'
	]) {
		const { error } = await db.from(t).select('*', { head: true, count: 'exact' });
		error ? ko(`tabella ${t}`, error.message) : ok(`tabella ${t}`);
	}

	for (const v of ['v_saldi', 'v_classifica', 'v_dex']) {
		const { error } = await db.from(v).select('*', { head: true, count: 'exact' });
		error ? ko(`vista ${v}`, error.message) : ok(`vista ${v}`);
	}

	/* --- 2. i giocatori --------------------------------------------------- */
	titolo('Giocatori e configurazione');

	const { data: utenti, error: errU } = await db.from('users').select('*').order('created_at');
	if (errU) throw new Error(`non riesco a leggere gli utenti: ${errU.message}`);

	verifica('sei profili seminati', utenti.length === 6, `trovati ${utenti.length}`);
	verifica('Nicco e amministratore', utenti.some((u) => u.nome === 'Nicco' && u.is_admin));

	if (utenti.length < 4) throw new Error('servono almeno 4 profili per collaudare una votazione');

	const [autore, contestante, terzo, quarto] = utenti;

	const { data: cfg } = await db.from('game_config').select('*');
	const config = Object.fromEntries(cfg.map((r) => [r.chiave, r.valore]));
	verifica('configurazione presente', Object.keys(config).length >= 7, `${cfg.length} chiavi`);

	const saldiIniziali = Object.fromEntries(
		await Promise.all(utenti.map(async (u) => [u.id, await saldoDi(u.id)]))
	);

	/* --- 3. elemento di prova --------------------------------------------- */
	titolo('Cattura');

	const { data: item, error: errI } = await db
		.from('items')
		.insert({
			nome: `«collaudo» ${Date.now()}`,
			categoria: 'pietanza',
			rarita: 'raro',
			croquembouche: 25,
			ripetibile: false,
			validazione: 'foto',
			note: 'Elemento temporaneo del collaudo, si cancella da solo'
		})
		.select()
		.single();
	if (errI) throw new Error(`insert item: ${errI.message}`);
	creato.itemId = item.id;
	ok('elemento di prova creato');

	// Foto vera su Storage: cosi' si collauda anche il bucket e i permessi.
	const png = readFileSync('static/favicon.png');
	creato.file = `collaudo/${Date.now()}.png`;
	const { error: errS } = await db.storage
		.from('catture')
		.upload(creato.file, png, { contentType: 'image/png', upsert: true });
	errS ? ko('upload su Storage', errS.message) : ok('upload su Storage');

	const { data: pub } = db.storage.from('catture').getPublicUrl(creato.file);

	const { data: capId, error: errC } = await db.rpc('registra_cattura', {
		p_user: autore.id,
		p_item: item.id,
		p_foto: pub.publicUrl,
		p_nota: 'collaudo automatico',
		p_lat: null,
		p_lng: null
	});
	if (errC) throw new Error(`registra_cattura: ${errC.message}`);
	creato.captureId = capId;
	ok('cattura registrata');

	verifica(
		'il saldo cresce del valore dell elemento',
		(await saldoDi(autore.id)) === saldiIniziali[autore.id] + 25,
		`${saldiIniziali[autore.id]} → ${await saldoDi(autore.id)}`
	);

	// Il doppione deve essere respinto: l'elemento non e' ripetibile.
	const { error: errDoppio } = await db.rpc('registra_cattura', {
		p_user: autore.id,
		p_item: item.id,
		p_foto: pub.publicUrl,
		p_nota: null,
		p_lat: null,
		p_lng: null
	});
	verifica('il doppione viene respinto', !!errDoppio, errDoppio?.message ?? 'e passato!');

	/* --- 4. le query del feed --------------------------------------------- */
	titolo('Query del feed');

	const { error: errFeed } = await db
		.from('captures')
		.select('*, item:items(*), autore:users(*), reactions(user_id), contestazioni:contests(*)')
		.order('timestamp', { ascending: false })
		.limit(5);
	errFeed ? ko('innesti della cattura', errFeed.message) : ok('innesti della cattura');

	const { error: errScambi } = await db
		.from('transfers')
		.select(
			'*, mittente:users!transfers_from_user_id_fkey(*), destinatario:users!transfers_to_user_id_fkey(*)'
		)
		.limit(5);
	errScambi ? ko('innesti degli scambi', errScambi.message) : ok('innesti degli scambi');

	const { error: errCont } = await db
		.from('contests')
		.select(
			'*, contestante:users!contests_contestante_id_fkey(*), votes(*), cattura:captures(*, item:items(*), autore:users(*), reactions(user_id))'
		)
		.limit(5);
	errCont ? ko('innesti delle contestazioni', errCont.message) : ok('innesti delle contestazioni');

	const { data: dex, error: errDex } = await db.from('v_dex').select('*').eq('item_id', item.id);
	errDex
		? ko('vista PachiDex', errDex.message)
		: verifica(
				'il PachiDex mostra la prima foto del gruppo',
				dex?.[0]?.prima_foto === pub.publicUrl,
				dex?.[0]?.prima_foto ? 'foto collegata' : 'nessuna foto'
			);

	/* --- 5. contestazione -------------------------------------------------- */
	titolo('Contestazione');

	const saldoContestantePrima = await saldoDi(contestante.id);

	const { data: contestId, error: errApri } = await db.rpc('apri_contestazione', {
		p_capture: creato.captureId,
		p_contestante: contestante.id,
		p_motivo: 'collaudo: quella foto non prova niente'
	});
	if (errApri) throw new Error(`apri_contestazione: ${errApri.message}`);
	ok('contestazione aperta');

	const { data: capDopo } = await db
		.from('captures')
		.select('stato')
		.eq('id', creato.captureId)
		.single();
	verifica('la cattura passa in contestazione', capDopo.stato === 'in_contestazione', capDopo.stato);

	verifica(
		'chi contesta paga subito il costo fisso',
		(await saldoDi(contestante.id)) === saldoContestantePrima - config.costo_apertura_contestazione,
		`-${config.costo_apertura_contestazione}`
	);

	verifica(
		'i punti restano al contestato finche non si decide',
		(await saldoDi(autore.id)) === saldiIniziali[autore.id] + 25,
		'nessun ballo del saldo'
	);

	// L'autore non deve poter votare sulla propria cattura.
	const { error: errAutoVoto } = await db.rpc('vota_contestazione', {
		p_contest: contestId,
		p_user: autore.id,
		p_voto: 'valido'
	});
	verifica('il contestato non vota', !!errAutoVoto, errAutoVoto?.message ?? 'ha votato!');

	// Il contestante ha gia' votato "non valido" in automatico: con sei
	// profili la maggioranza e' 3, quindi bastano altri due voti contrari.
	for (const chi of [terzo, quarto]) {
		const { error } = await db.rpc('vota_contestazione', {
			p_contest: contestId,
			p_user: chi.id,
			p_voto: 'non_valido'
		});
		if (error) ko(`voto di ${chi.nome}`, error.message);
	}
	ok('due voti contrari espressi');

	const { data: contestFinale } = await db
		.from('contests')
		.select('stato')
		.eq('id', contestId)
		.single();
	verifica(
		'la maggioranza chiude la contestazione',
		contestFinale.stato === 'chiusa_non_valido',
		contestFinale.stato
	);

	const { data: capFinale } = await db
		.from('captures')
		.select('stato')
		.eq('id', creato.captureId)
		.single();
	verifica('la cattura viene invalidata', capFinale.stato === 'invalidato', capFinale.stato);

	verifica(
		'il contestato perde valore e penalita',
		(await saldoDi(autore.id)) === saldiIniziali[autore.id] - config.penalita_extra_contestazione,
		`-25 di cattura, -${config.penalita_extra_contestazione} di penalita`
	);

	/* --- 6. scambio -------------------------------------------------------- */
	titolo('Scambio di Croquembouche');

	const saldoTerzoPrima = await saldoDi(terzo.id);
	const saldoQuartoPrima = await saldoDi(quarto.id);

	const { error: errTroppo } = await db.rpc('invia_croquembouche', {
		p_from: terzo.id,
		p_to: quarto.id,
		p_importo: saldoTerzoPrima + 1000,
		p_causale: null
	});
	verifica('non si manda piu di quanto si ha', !!errTroppo, errTroppo?.message ?? 'e passato!');

	const { error: errSe } = await db.rpc('invia_croquembouche', {
		p_from: terzo.id,
		p_to: terzo.id,
		p_importo: 1,
		p_causale: null
	});
	verifica('non si manda a se stessi', !!errSe, errSe?.message ?? 'e passato!');

	if (saldoTerzoPrima >= 5) {
		const { data: trId, error: errT } = await db.rpc('invia_croquembouche', {
			p_from: terzo.id,
			p_to: quarto.id,
			p_importo: 5,
			p_causale: 'collaudo'
		});
		if (errT) ko('scambio valido', errT.message);
		else {
			creato.transferId = trId;
			ok('scambio eseguito');
			verifica(
				'i Croquembouche si spostano davvero',
				(await saldoDi(terzo.id)) === saldoTerzoPrima - 5 &&
					(await saldoDi(quarto.id)) === saldoQuartoPrima + 5,
				'-5 da una parte, +5 dall altra'
			);
		}
	} else {
		console.log('  \x1b[2m· scambio saltato: nessun saldo da muovere\x1b[0m');
	}

	/* --- 7. classifica ----------------------------------------------------- */
	titolo('Classifica');

	const { data: cl, error: errCl } = await db.from('v_classifica').select('*');
	errCl
		? ko('vista classifica', errCl.message)
		: verifica('la classifica risponde per tutti', cl.length === utenti.length, `${cl.length} righe`);
} catch (e) {
	ko('collaudo interrotto', e.message ?? String(e));
} finally {
	/* --- pulizia ----------------------------------------------------------- */
	titolo('Pulizia');

	if (creato.transferId) {
		await db.from('transfers').delete().eq('id', creato.transferId);
		ok('scambio di prova rimosso');
	}
	if (creato.itemId) {
		// Cancellare l'elemento porta via a cascata cattura, contestazione e voti.
		await db.from('items').delete().eq('id', creato.itemId);
		ok('elemento di prova rimosso (con cattura e contestazione)');
	}
	if (creato.file) {
		await db.storage.from('catture').remove([creato.file]);
		ok('foto di prova rimossa');
	}

	console.log(
		`\n\x1b[1m${passati} controlli passati, ${falliti} falliti\x1b[0m\n`
	);
	if (problemi.length) {
		console.log('Da guardare:');
		for (const p of problemi) console.log(`  · ${p}`);
		console.log();
	}
	process.exit(falliti ? 1 : 0);
}
