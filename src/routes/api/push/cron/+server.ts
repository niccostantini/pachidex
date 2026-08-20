import { json, error } from '@sveltejs/kit';
import { CRON_SECRET } from '$env/static/private';
import { croq, db, inviaA } from '$lib/server/push';
import type { RequestHandler } from './$types';

/**
 * Le notifiche a orario, chiamate da pg_cron dentro Supabase.
 *
 * A differenza degli eventi di gioco, qui serve un segreto: nessuno deve
 * poter far partire il podio delle 22:30 a mezzogiorno per scherzo.
 */

const MEDAGLIE = ['①', '②', '③'];

/**
 * L'ora di Roma adesso. Il database vive in UTC e l'Italia cambia ora due
 * volte l'anno: pianificare "20:30 UTC" andrebbe bene solo d'estate.
 */
function oraItaliana(): number {
	return Number(
		new Intl.DateTimeFormat('it-IT', {
			timeZone: 'Europe/Rome',
			hour: 'numeric',
			hour12: false
		}).format(new Date())
	);
}

/* --- podio serale ---------------------------------------------------------- */
async function podio() {
	const { data } = await db
		.from('v_classifica')
		.select('user_id, nome, saldo, item_unici')
		.order('saldo', { ascending: false });

	const righe = (data ?? []) as {
		user_id: string;
		nome: string;
		saldo: number;
		item_unici: number;
	}[];
	if (!righe.length) return 0;

	const tre = righe.slice(0, 3);
	const testo = tre.map((r, i) => `${MEDAGLIE[i]} ${r.nome} ${croq(r.saldo)}`).join('  ');

	// A ognuno si dice anche dove sta lui: il podio da solo interessa
	// soprattutto a chi ci sta sopra.
	let inviate = 0;
	for (const r of righe) {
		const posizione = righe.findIndex((x) => x.user_id === r.user_id) + 1;
		const suo =
			posizione <= 3
				? `Sei ${posizione}°.`
				: `Sei ${posizione}° con ${croq(r.saldo)} e ${r.item_unici} pezzi.`;

		inviate += await inviaA([r.user_id], {
			titolo: 'Come siamo messi',
			corpo: `${testo} — ${suo}`,
			url: '/classifica',
			tag: 'podio',
			insisti: true
		});
	}
	return inviate;
}

/* --- promemoria voto -------------------------------------------------------- */
/**
 * Due ore prima della scadenza, a chi non ha ancora votato quella
 * contestazione. La finestra e' stretta apposta: il cron gira spesso, e senza
 * un intervallo lo stesso promemoria partirebbe a ogni giro.
 */
async function promemoria() {
	const ora = Date.now();
	const da = new Date(ora + 105 * 60 * 1000).toISOString();
	const a = new Date(ora + 135 * 60 * 1000).toISOString();

	const { data } = await db
		.from('contests')
		.select(
			'id, contestante_id, scadenza, votes(user_id), cattura:captures(user_id, item:items(nome), autore:users(nome))'
		)
		.eq('stato', 'aperta')
		.gte('scadenza', da)
		.lte('scadenza', a);

	const contestazioni = (data ?? []) as unknown as {
		id: string;
		contestante_id: string;
		votes: { user_id: string }[];
		cattura: { user_id: string; item: { nome: string }; autore: { nome: string } };
	}[];
	if (!contestazioni.length) return 0;

	const { data: utenti } = await db.from('users').select('id');
	const tutti = (utenti ?? []).map((u) => u.id as string);

	let inviate = 0;
	for (const c of contestazioni) {
		const hannoVotato = new Set((c.votes ?? []).map((v) => v.user_id));
		// Il contestato non vota, e chi ha gia' votato non va disturbato.
		const mancanti = tutti.filter(
			(id) => id !== c.cattura.user_id && !hannoVotato.has(id)
		);
		if (!mancanti.length) continue;

		inviate += await inviaA(mancanti, {
			titolo: 'Mancano due ore',
			corpo: `Non hai ancora votato sulla cattura di ${c.cattura.autore.nome} (${c.cattura.item.nome}). Senza maggioranza resta valida.`,
			url: '/',
			tag: `contest-${c.id}`,
			insisti: true
		});
	}
	return inviate;
}

export const POST: RequestHandler = async ({ request, url }) => {
	const segreto = request.headers.get('x-cron-secret');
	if (!CRON_SECRET || segreto !== CRON_SECRET) error(401, 'non autorizzato');

	const tipo = url.searchParams.get('tipo');
	const forza = url.searchParams.get('forza') === '1';

	if (tipo === 'podio') {
		// Il cron chiama a due ore diverse, una giusta d'estate e una d'inverno;
		// e' questo controllo a decidere quale delle due vale davvero, cosi' il
		// podio esce alle 22:30 italiane tutto l'anno senza doppioni.
		if (!forza && oraItaliana() !== 22) return json({ inviate: 0, saltato: 'ora sbagliata' });
		return json({ inviate: await podio() });
	}
	if (tipo === 'promemoria') return json({ inviate: await promemoria() });
	error(400, 'tipo sconosciuto');
};
