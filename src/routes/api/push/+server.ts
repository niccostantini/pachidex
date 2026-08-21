import { json, error } from '@sveltejs/kit';
import { croq, db, inviaA, tuttiTranne } from '$lib/server/push';
import type { RequestHandler } from './$types';

/**
 * Un evento e' successo: decidi chi avvisare e cosa dirgli.
 *
 * Il client manda solo il tipo e un id. Tutto il resto — nomi, valori,
 * destinatari — si rilegge dal database, perche' il testo di una notifica
 * che arriva a cinque telefoni non puo' dipendere da cosa scrive il mittente.
 */

type Evento =
	| { tipo: 'cattura'; id: string }
	| { tipo: 'contestazione_aperta'; id: string }
	| { tipo: 'contestazione_chiusa'; id: string }
	| { tipo: 'scambio'; id: string };

/* --- cattura pubblicata --------------------------------------------------- */
async function cattura(captureId: string) {
	const { data } = await db
		.from('captures')
		.select('id, user_id, autore:users(nome), item:items(nome, croquembouche), tag:capture_tags(user_id)')
		.eq('id', captureId)
		.single();
	if (!data) return 0;

	const c = data as unknown as {
		user_id: string;
		autore: { nome: string };
		item: { nome: string; croquembouche: number };
		tag: { user_id: string }[];
	};

	const taggati = (c.tag ?? []).map((t) => t.user_id);
	const valore = croq(c.item.croquembouche);
	let inviate = 0;

	// A chi e' stato taggato arriva il messaggio suo, non quello generico.
	if (taggati.length) {
		inviate += await inviaA(taggati, {
			titolo: 'Ti hanno taggato',
			corpo: `${c.autore.nome} ti ha taggato su ${c.item.nome}: hai guadagnato ${valore}!`,
			url: '/',
			tag: `cattura-${captureId}`,
			// Questa riguarda te: deve farsi notare anche se ne era arrivata
			// un'altra un attimo prima.
			insisti: true
		});
	}

	// Gli altri ricevono la cronaca generica, accorpata sotto un tag comune
	// perche' una cena a Marzamemi non diventi una raffica.
	const altri = await tuttiTranne([c.user_id, ...taggati]);
	const chi =
		taggati.length > 0
			? `${c.autore.nome} ed altri ${taggati.length} hanno`
			: `${c.autore.nome} ha`;

	inviate += await inviaA(altri, {
		titolo: 'Nuova cattura',
		corpo: `${chi} ottenuto ${valore} — ${c.item.nome}`,
		url: '/',
		tag: 'catture'
	});

	return inviate;
}

/* --- contestazione aperta -------------------------------------------------- */
async function contestazioneAperta(contestId: string) {
	const { data } = await db
		.from('contests')
		.select(
			'id, contestante_id, motivo, contestante:users!contests_contestante_id_fkey(nome), cattura:captures(user_id, item:items(nome), autore:users(nome))'
		)
		.eq('id', contestId)
		.single();
	if (!data) return 0;

	const c = data as unknown as {
		contestante_id: string;
		motivo: string | null;
		contestante: { nome: string };
		cattura: { user_id: string; item: { nome: string }; autore: { nome: string } };
	};

	let inviate = 0;

	// Al contestato, che non puo' votare e deve saperlo.
	inviate += await inviaA([c.cattura.user_id], {
		titolo: 'Sei sotto contestazione',
		corpo: `${c.contestante.nome} contesta la tua cattura di ${c.cattura.item.nome}${
			c.motivo ? `: "${c.motivo}"` : ''
		}`,
		url: '/',
		tag: `contest-${contestId}`,
		insisti: true
	});

	// A tutti gli altri, che devono votare: senza questa la contestazione
	// scade in silenzio e la meccanica non funziona.
	const giudici = await tuttiTranne([c.cattura.user_id, c.contestante_id]);
	inviate += await inviaA(giudici, {
		titolo: 'Si vota',
		corpo: `${c.contestante.nome} contesta la cattura di ${c.cattura.autore.nome} (${c.cattura.item.nome}). Hai 24 ore per votare.`,
		url: '/',
		tag: `contest-${contestId}`,
		insisti: true
	});

	return inviate;
}

/* --- contestazione chiusa -------------------------------------------------- */
async function contestazioneChiusa(contestId: string) {
	const { data } = await db
		.from('contests')
		.select(
			'id, stato, penalita, contestante_id, contestante:users!contests_contestante_id_fkey(nome), cattura:captures(user_id, item:items(nome), autore:users(nome))'
		)
		.eq('id', contestId)
		.single();
	if (!data) return 0;

	const c = data as unknown as {
		stato: string;
		penalita: number;
		contestante_id: string;
		contestante: { nome: string };
		cattura: { user_id: string; item: { nome: string }; autore: { nome: string } };
	};
	if (c.stato === 'aperta') return 0;

	const esiti: Record<string, { titolo: string; corpo: string }> = {
		chiusa_non_valido: {
			titolo: 'Cattura invalidata',
			corpo: `Il gruppo ha dato ragione a ${c.contestante.nome}: ${c.cattura.autore.nome} perde ${c.cattura.item.nome} e ${croq(c.penalita)} di penalita.`
		},
		chiusa_valido: {
			titolo: 'Cattura confermata',
			corpo: `${c.cattura.item.nome} di ${c.cattura.autore.nome} regge. ${c.contestante.nome} paga ${croq(c.penalita)} di penalita.`
		},
		scaduta: {
			titolo: 'Contestazione scaduta',
			corpo: `Non sono arrivati abbastanza voti: ${c.cattura.item.nome} di ${c.cattura.autore.nome} resta valida.`
		}
	};

	const m = esiti[c.stato];
	if (!m) return 0;

	// L'esito interessa tutti, protagonisti compresi.
	const { data: utenti } = await db.from('users').select('id');
	return inviaA((utenti ?? []).map((u) => u.id as string), {
		...m,
		url: '/',
		tag: `contest-${contestId}`,
		insisti: true
	});
}

/* --- scambio --------------------------------------------------------------- */
async function scambio(transferId: string) {
	const { data } = await db
		.from('transfers')
		.select(
			'id, importo, causale, to_user_id, mittente:users!transfers_from_user_id_fkey(nome)'
		)
		.eq('id', transferId)
		.single();
	if (!data) return 0;

	const t = data as unknown as {
		importo: number;
		causale: string | null;
		to_user_id: string;
		mittente: { nome: string };
	};

	return inviaA([t.to_user_id], {
		titolo: 'Croquembouche in arrivo',
		corpo: `${t.mittente.nome} ti ha passato ${croq(t.importo)}${t.causale ? ` — ${t.causale}` : ''}`,
		url: '/classifica',
		tag: `scambio-${transferId}`,
		insisti: true
	});
}

/* --- sorpassi -------------------------------------------------------------- */
/** Da chiamare dopo ogni evento che muove i saldi. */
/**
 * Capitoli appena sbloccati. Il titolo arriva dal database ma NON si mette
 * nella notifica: si vede solo aprendo l'app, che e' il momento della
 * rivelazione. La notifica dice quanti e basta.
 */
async function capitoli() {
	const { data } = await db.rpc('sblocca_capitoli');
	const nuovi = (data ?? []) as { numero: number; titolo: string | null }[];
	if (!nuovi.length) return 0;

	const tutti = await tuttiTranne([]);

	// Piu' capitoli insieme sono un evento solo: una giornata grossa non deve
	// far arrivare tre notifiche in fila.
	const m =
		nuovi.length === 1
			? {
					titolo: `Capitolo ${nuovi[0].numero} sbloccato!`,
					corpo: 'La storia continua. Apri per vedere quale.',
					url: '/storia',
					tag: 'storia'
				}
			: {
					titolo: `${nuovi.length} capitoli sbloccati!`,
					corpo: `Dal ${nuovi[0].numero} al ${nuovi[nuovi.length - 1].numero}. Che giornata.`,
					url: '/storia',
					tag: 'storia'
				};

	return inviaA(tutti, m);
}

async function sorpassi() {
	const { data } = await db.rpc('registra_sorpassi');
	const righe = (data ?? []) as { superato: string; superante: string }[];
	if (!righe.length) return 0;

	const { data: utenti } = await db.from('users').select('id, nome');
	const nome = new Map((utenti ?? []).map((u) => [u.id as string, u.nome as string]));

	let inviate = 0;
	for (const r of righe) {
		inviate += await inviaA([r.superato], {
			titolo: 'Ti hanno superato',
			corpo: `${nome.get(r.superante) ?? 'Qualcuno'} ti e' passato davanti in classifica.`,
			url: '/classifica',
			tag: 'sorpasso'
		});
	}
	return inviate;
}

export const POST: RequestHandler = async ({ request }) => {
	const evento = (await request.json().catch(() => null)) as Evento | null;
	if (!evento?.tipo || typeof evento.id !== 'string') error(400, 'evento non valido');

	let inviate = 0;
	switch (evento.tipo) {
		case 'cattura':
			inviate = await cattura(evento.id);
			break;
		case 'contestazione_aperta':
			inviate = await contestazioneAperta(evento.id);
			break;
		case 'contestazione_chiusa':
			inviate = await contestazioneChiusa(evento.id);
			break;
		case 'scambio':
			inviate = await scambio(evento.id);
			break;
		default:
			error(400, 'tipo sconosciuto');
	}

	// Ogni evento qui sopra muove i saldi, quindi puo' aver ribaltato la
	// classifica: si controlla sempre, subito dopo.
	inviate += await sorpassi();

	// E puo' aver riempito la barra della storia. Si controlla sempre anche
	// questo: sblocca_capitoli() non fa niente se non c'e' niente da
	// sbloccare, e cosi' nessun percorso puo' dimenticarsene.
	inviate += await capitoli();

	return json({ inviate });
};
