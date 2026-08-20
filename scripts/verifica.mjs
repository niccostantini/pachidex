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
 * Serve un .env riempito con URL e anon key di Supabase. Se ci sono anche le
 * credenziali R2 vere (non i placeholder xxxx...), collauda pure upload e
 * lettura pubblica delle foto con la stessa firma che usa l'app; altrimenti
 * salta quella parte e usa un URL finto solo per non bloccare il resto.
 */
import { createClient } from '@supabase/supabase-js';
import { AwsClient } from 'aws4fetch';
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

const r2Pronto =
	env.R2_ACCOUNT_ID &&
	env.R2_ACCESS_KEY_ID &&
	env.R2_SECRET_ACCESS_KEY &&
	env.R2_BUCKET &&
	env.R2_PUBLIC_BASE_URL &&
	!env.R2_ACCOUNT_ID.startsWith('xxxx');

// La stessa identica firma che fa src/routes/api/upload-url/+server.ts:
// se questa funziona, l'endpoint funziona.
const r2 = r2Pronto
	? new AwsClient({
			accessKeyId: env.R2_ACCESS_KEY_ID,
			secretAccessKey: env.R2_SECRET_ACCESS_KEY,
			service: 's3',
			region: 'auto'
		})
	: null;

// Stesso host che costruisce l'endpoint server, giurisdizione inclusa.
const r2Host = `${env.R2_ACCOUNT_ID}.${env.R2_JURISDICTION ? env.R2_JURISDICTION + '.' : ''}r2.cloudflarestorage.com`;

const r2Endpoint = (chiave) => new URL(`https://${r2Host}/${env.R2_BUCKET}/${chiave}`);

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
const creato = {
	itemId: null,
	itemTagId: null,
	checkpointId: null,
	captureId: null,
	captureTagId: null,
	captureTag2Id: null,
	transferId: null,
	file: null
};

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

	// Foto vera su R2, con la stessa firma SigV4 che usa l'endpoint server:
	// se il caricamento e la lettura pubblica funzionano qui, funzionano
	// anche nell'app.
	let fotoUrl = `https://esempio.invalid/collaudo.png`; // ripiego se R2 non e' configurato
	if (r2Pronto) {
		const png = readFileSync('static/favicon.png');
		creato.file = `collaudo/${Date.now()}.png`;
		const endpoint = r2Endpoint(creato.file);
		endpoint.searchParams.set('X-Amz-Expires', '60');

		const firmata = await r2.sign(endpoint, {
			method: 'PUT',
			headers: { 'Content-Type': 'image/png' },
			aws: { signQuery: true }
		});
		const rispPut = await fetch(firmata.url, {
			method: 'PUT',
			headers: { 'Content-Type': 'image/png' },
			body: png
		});
		let dettaglio = `HTTP ${rispPut.status}`;
		if (!rispPut.ok) {
			const corpo = await rispPut.text().catch(() => '');
			const codice = corpo.match(/<Code>([^<]+)<\/Code>/)?.[1];
			if (codice) dettaglio += ` ${codice}`;
			// AccessDenied da R2 e' ambiguo: dice la stessa cosa per una chiave
			// sbagliata e per un bucket che sta su un'altra giurisdizione.
			if (codice === 'AccessDenied') {
				dettaglio +=
					env.R2_JURISDICTION
						? ` — con giurisdizione "${env.R2_JURISDICTION}"; se il bucket e' standard, svuota R2_JURISDICTION`
						: ' — se il bucket ha giurisdizione EU, imposta R2_JURISDICTION="eu"; altrimenti controlla i permessi del token';
			}
		}
		verifica('upload su R2', rispPut.ok, dettaglio);

		fotoUrl = `${env.R2_PUBLIC_BASE_URL}/${creato.file}`;
		const rispGet = await fetch(fotoUrl);
		verifica(
			'la foto si legge dal dominio pubblico',
			rispGet.ok,
			rispGet.ok ? fotoUrl : `HTTP ${rispGet.status} — dominio custom configurato?`
		);
	} else {
		console.log(
			'  \x1b[2m· R2 non configurato nel .env: salto upload e lettura, uso un URL finto\x1b[0m'
		);
	}

	const { data: capId, error: errC } = await db.rpc('registra_cattura', {
		p_user: autore.id,
		p_item: item.id,
		p_foto: fotoUrl,
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
		p_foto: fotoUrl,
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
				dex?.[0]?.prima_foto === fotoUrl,
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

	/* --- 5ter. tag @menzione ----------------------------------------------- */
	titolo('Tag (@menzione)');

	const { data: itemTag, error: errIt } = await db
		.from('items')
		.insert({
			nome: `«collaudo tag» ${Date.now()}`,
			categoria: 'pietanza',
			rarita: 'comune',
			croquembouche: 10,
			ripetibile: false,
			validazione: 'foto'
		})
		.select()
		.single();

	if (errIt) {
		ko('creazione elemento per i tag', errIt.message);
	} else {
		creato.itemTagId = itemTag.id;

		const primaTerzo = await saldoDi(terzo.id);
		const primaQuarto = await saldoDi(quarto.id);

		// Il quarto scatta e tagga il terzo, piu' se stesso (che va ignorato)
		// e un id inventato (che va lasciato cadere senza far fallire tutto).
		const { data: capTag, error: errCapTag } = await db.rpc('registra_cattura', {
			p_user: quarto.id,
			p_item: itemTag.id,
			p_foto: fotoUrl,
			p_nota: `con @${terzo.nome}`,
			p_lat: null,
			p_lng: null,
			p_taggati: [terzo.id, quarto.id, '00000000-0000-4000-8000-000000000000']
		});

		if (errCapTag) {
			ko('cattura con taggati', errCapTag.message);
		} else {
			creato.captureTagId = capTag;
			ok('cattura con taggati registrata');

			const { data: tag } = await db
				.from('capture_tags')
				.select('user_id')
				.eq('capture_id', capTag);

			verifica(
				'chi scatta non si tagga da solo, gli id inesistenti cadono',
				tag?.length === 1 && tag[0].user_id === terzo.id,
				`${tag?.length ?? 0} tag salvati`
			);

			verifica(
				'il taggato prende i Croquembouche',
				(await saldoDi(terzo.id)) === primaTerzo + 10,
				`${primaTerzo} → ${await saldoDi(terzo.id)}`
			);
			verifica(
				'chi scatta li prende comunque',
				(await saldoDi(quarto.id)) === primaQuarto + 10,
				`${primaQuarto} → ${await saldoDi(quarto.id)}`
			);

			const { data: crediti } = await db
				.from('v_crediti')
				.select('user_id, da_tag')
				.eq('item_id', itemTag.id);
			verifica(
				'il taggato lo sblocca nel PachiDex',
				crediti?.some((c) => c.user_id === terzo.id && c.da_tag === true),
				'credito da tag presente'
			);

			// Doppione: il terzo viene taggato di nuovo sullo stesso elemento
			// non ripetibile. Il tag si salva ma non deve valere un secondo.
			const saldoPrimaDoppione = await saldoDi(terzo.id);
			const { data: cap2, error: errCap2 } = await db.rpc('registra_cattura', {
				p_user: contestante.id,
				p_item: itemTag.id,
				p_foto: fotoUrl,
				p_nota: `di nuovo con @${terzo.nome}`,
				p_lat: null,
				p_lng: null,
				p_taggati: [terzo.id]
			});
			if (errCap2) {
				ko('seconda cattura con lo stesso taggato', errCap2.message);
			} else {
				creato.captureTag2Id = cap2;
				verifica(
					'un non ripetibile non paga due volte al taggato',
					(await saldoDi(terzo.id)) === saldoPrimaDoppione,
					`resta a ${await saldoDi(terzo.id)}`
				);
			}
		}
	}

	/* --- 5bis. checkpoint foto + GPS --------------------------------------- */
	titolo('Checkpoint (foto + GPS)');

	const LAT = 36.8106;
	const LNG = 15.1042;

	const { data: checkpoint, error: errCk } = await db
		.from('items')
		.insert({
			nome: `«collaudo checkpoint» ${Date.now()}`,
			categoria: 'posto',
			rarita: 'comune',
			croquembouche: 10,
			ripetibile: false,
			validazione: 'foto_gps',
			lat: LAT,
			lng: LNG
		})
		.select()
		.single();

	if (errCk) {
		ko('creazione checkpoint foto_gps', errCk.message);
	} else {
		creato.checkpointId = checkpoint.id;
		ok('checkpoint foto_gps accettato dal vincolo');

		// Lontano dal posto: deve rifiutare, il GPS e' meta' della validazione.
		const { error: errLontano } = await db.rpc('registra_cattura', {
			p_user: terzo.id,
			p_item: checkpoint.id,
			p_foto: fotoUrl,
			p_nota: null,
			p_lat: 45.4642, // Milano
			p_lng: 9.19
		});
		verifica('da lontano il checkpoint rifiuta', !!errLontano, errLontano?.message ?? 'e passato!');

		// Senza posizione: idem.
		const { error: errSenzaPos } = await db.rpc('registra_cattura', {
			p_user: terzo.id,
			p_item: checkpoint.id,
			p_foto: fotoUrl,
			p_nota: null,
			p_lat: null,
			p_lng: null
		});
		verifica('senza posizione il checkpoint rifiuta', !!errSenzaPos, errSenzaPos?.message ?? 'e passato!');

		// Sul posto e con foto: passa.
		const { data: capCk, error: errCap } = await db.rpc('registra_cattura', {
			p_user: terzo.id,
			p_item: checkpoint.id,
			p_foto: fotoUrl,
			p_nota: 'collaudo checkpoint',
			p_lat: LAT,
			p_lng: LNG
		});
		if (errCap) {
			ko('sul posto con foto il checkpoint accetta', errCap.message);
		} else {
			ok('sul posto con foto il checkpoint accetta');

			// La regola cambiata: adesso anche un posto si contesta.
			const { error: errCont2 } = await db.rpc('apri_contestazione', {
				p_capture: capCk,
				p_contestante: quarto.id,
				p_motivo: 'collaudo: anche i checkpoint si contestano'
			});
			verifica(
				'un checkpoint ora e contestabile',
				!errCont2,
				errCont2?.message ?? 'contestazione aperta'
			);
		}
	}

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
	if (creato.itemTagId) {
		// Cancellare l'elemento porta via a cascata catture e tag.
		await db.from('items').delete().eq('id', creato.itemTagId);
		ok('elemento dei tag rimosso');
	}
	if (creato.checkpointId) {
		await db.from('items').delete().eq('id', creato.checkpointId);
		ok('checkpoint di prova rimosso');
	}
	if (creato.itemId) {
		// Cancellare l'elemento porta via a cascata cattura, contestazione e voti.
		await db.from('items').delete().eq('id', creato.itemId);
		ok('elemento di prova rimosso (con cattura e contestazione)');
	}
	if (creato.file && r2) {
		const endpoint = r2Endpoint(creato.file);
		const firmata = await r2.sign(endpoint, { method: 'DELETE', aws: { signQuery: true } });
		await fetch(firmata.url, { method: 'DELETE' });
		ok('foto di prova rimossa da R2');
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
