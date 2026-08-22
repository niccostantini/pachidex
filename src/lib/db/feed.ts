import { supabase } from '$lib/supabase';
import type {
	Contest,
	PostCattura,
	PostContestazione,
	PostFeed,
	PostScambio,
	User,
	Vote
} from '$lib/types';

const SELECT_CATTURA = `
	*,
	item:items(*),
	autore:users(*),
	reactions(user_id),
	tag:capture_tags(utente:users(*)),
	contestazioni:contests(*)
`;

/**
 * Variante senza il ramo contests: serve quando la cattura viene innestata
 * dentro una contestazione, altrimenti si chiederebbe a PostgREST
 * contests -> captures -> contests, cioe' un giro su se stesso.
 */
const SELECT_CATTURA_NUDA = `
	*,
	item:items(*),
	autore:users(*),
	reactions(user_id),
	tag:capture_tags(utente:users(*))
`;

interface RigaCattura {
	reactions: { user_id: string }[];
	tag: { utente: User }[];
	contestazioni: Contest[];
	[k: string]: unknown;
}

function aPostCattura(riga: RigaCattura, ioId: string | null): PostCattura {
	const reactions = riga.reactions ?? [];
	const contestazioni = riga.contestazioni ?? [];
	return {
		...(riga as unknown as PostCattura),
		tipo: 'cattura',
		likes: reactions.length,
		ho_messo_like: !!ioId && reactions.some((r) => r.user_id === ioId),
		taggati: (riga.tag ?? []).map((t) => t.utente).filter(Boolean),
		// La piu' recente: una cattura ne ha al massimo una aperta per volta.
		contestazione:
			[...contestazioni].sort((a, b) => b.created_at.localeCompare(a.created_at))[0] ?? null,
		// Riempito da caricaFeed(): qui non si sa ancora.
		primato: false,
		at: (riga as unknown as PostCattura).timestamp
	};
}

export async function caricaCatture(ioId: string | null, limite = 60): Promise<PostCattura[]> {
	const { data, error } = await supabase
		.from('captures')
		.select(SELECT_CATTURA)
		.order('timestamp', { ascending: false })
		.limit(limite);
	if (error) throw error;
	return ((data ?? []) as unknown as RigaCattura[]).map((r) => aPostCattura(r, ioId));
}

export async function caricaScambi(limite = 40): Promise<PostScambio[]> {
	const { data, error } = await supabase
		.from('transfers')
		.select(
			'*, mittente:users!transfers_from_user_id_fkey(*), destinatario:users!transfers_to_user_id_fkey(*)'
		)
		.eq('annullato', false)
		.order('created_at', { ascending: false })
		.limit(limite);
	if (error) throw error;
	return ((data ?? []) as unknown as PostScambio[]).map((t) => ({
		...t,
		tipo: 'scambio',
		at: t.created_at
	}));
}

export async function caricaContestazioni(
	ioId: string | null,
	limite = 30
): Promise<PostContestazione[]> {
	const { data, error } = await supabase
		.from('contests')
		.select(
			`*,
			 contestante:users!contests_contestante_id_fkey(*),
			 votes(*),
			 cattura:captures(${SELECT_CATTURA_NUDA})`
		)
		.order('created_at', { ascending: false })
		.limit(limite);
	if (error) throw error;

	return ((data ?? []) as unknown as (Contest & {
		contestante: User;
		votes: Vote[];
		cattura: RigaCattura;
	})[])
		.filter((c) => c.cattura)
		.map((c) => ({
			tipo: 'contestazione' as const,
			id: c.id,
			contest: c as Contest,
			cattura: aPostCattura(c.cattura, ioId),
			contestante: c.contestante,
			voti: c.votes ?? [],
			// Una contestazione aperta vive nel presente: si ordina sulla scadenza
			// che scorre, non sul momento in cui e' stata aperta.
			at: c.created_at
		}));
}

/**
 * Il feed completo: catture, scambi e contestazioni in un'unica cronaca.
 * Le contestazioni aperte restano fissate in cima finche' non si chiudono,
 * poi scivolano al loro posto in cronologia e ci restano per sempre.
 */
/**
 * Le catture che hanno scoperto un elemento per prime nel gruppo.
 * Una riga per elemento, quindi al massimo quante sono le sfiziosita':
 * si porta dietro tutto il feed senza pesare.
 */
async function idPrimati(): Promise<Set<string>> {
	const { data, error } = await supabase.from('v_primati').select('capture_id');
	if (error) return new Set();
	return new Set((data ?? []).map((r) => (r as { capture_id: string }).capture_id));
}

export async function caricaFeed(ioId: string | null): Promise<{
	fissati: PostContestazione[];
	timeline: PostFeed[];
}> {
	const [catture, scambi, contestazioni, primati] = await Promise.all([
		caricaCatture(ioId),
		caricaScambi(),
		caricaContestazioni(ioId),
		idPrimati()
	]);

	for (const c of catture) c.primato = primati.has(c.id);
	for (const c of contestazioni) c.cattura.primato = primati.has(c.cattura.id);

	const fissati = contestazioni.filter((c) => c.contest.stato === 'aperta');
	const chiuse = contestazioni.filter((c) => c.contest.stato !== 'aperta');

	const timeline = [...catture, ...scambi, ...chiuse].sort((a, b) => b.at.localeCompare(a.at));

	return { fissati, timeline };
}

/** Le contestazioni scadute si chiudono anche senza cron, appena qualcuno guarda. */
export async function chiudiScadute() {
	await supabase.rpc('chiudi_contestazioni_scadute');
}

/**
 * Realtime su tutto cio' che genera cronaca. Un solo canale: meno socket
 * aperti, meno batteria, meno traffico su una rete gia' incerta.
 */
export function sottoscriviFeed(onCambio: () => void) {
	const canale = supabase.channel('cronaca');
	for (const table of ['captures', 'transfers', 'contests', 'votes', 'reactions']) {
		canale.on('postgres_changes', { event: '*', schema: 'public', table }, onCambio);
	}
	canale.subscribe();
	return () => {
		void supabase.removeChannel(canale);
	};
}

/** Like on/off. */
export async function alternaLike(captureId: string, userId: string, attivo: boolean) {
	if (attivo) {
		const { error } = await supabase
			.from('reactions')
			.delete()
			.eq('capture_id', captureId)
			.eq('user_id', userId);
		if (error) throw error;
	} else {
		const { error } = await supabase
			.from('reactions')
			.insert({ capture_id: captureId, user_id: userId });
		if (error) throw error;
	}
}
