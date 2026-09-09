import { createClient } from '@supabase/supabase-js';
import { error, json } from '@sveltejs/kit';
import { PUBLIC_SUPABASE_ANON_KEY, PUBLIC_SUPABASE_URL } from '$env/static/public';
import { SUPABASE_SERVICE_ROLE_KEY } from '$env/static/private';
import type { RequestHandler } from './$types';

/**
 * Crea un account. Solo un admin puo' chiamarlo.
 *
 * Sta lato server perche' creare utenti richiede la chiave di servizio, che
 * scavalca tutte le RLS: nel bundle client sarebbe la fine di ogni permesso
 * scritto finora.
 *
 * Nessuno si iscrive da solo: gli account li fa chi tiene il gioco e passa la
 * password a voce. Per una cerchia e' la difesa piu' efficace che ci sia —
 * meta' dei problemi non esiste se non si puo' entrare.
 */
const DOMINIO = 'pachidex.local';
const NOME = /^[A-Za-z0-9À-ÿ' _-]{2,30}$/;

export const POST: RequestHandler = async ({ request }) => {
	if (!SUPABASE_SERVICE_ROLE_KEY) error(500, 'Manca SUPABASE_SERVICE_ROLE_KEY');

	// Chi chiama deve essere un admin, e lo si verifica col SUO token: non ci
	// si fida di niente che arrivi nel corpo della richiesta.
	const autorizzazione = request.headers.get('Authorization') ?? '';
	if (!autorizzazione.startsWith('Bearer ')) error(401, 'Non sei entrato');

	const comeChiama = createClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY, {
		global: { headers: { Authorization: autorizzazione } },
		auth: { persistSession: false }
	});
	const { data: admin } = await comeChiama.rpc('sono_admin');
	if (admin !== true) error(403, 'Serve un account admin');

	const corpo = await request.json().catch(() => null);
	const nome: string = (corpo?.nome ?? '').trim();
	const password: string = corpo?.password ?? '';

	if (!NOME.test(nome)) error(400, 'Nome utente non valido');
	// Otto caratteri e' poco per il mondo, abbastanza per una cerchia in cui
	// la password si passa a voce e non si puo' provare a indovinare in massa.
	if (password.length < 8) error(400, 'La password deve avere almeno 8 caratteri');

	const servizio = createClient(PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
		auth: { persistSession: false, autoRefreshToken: false }
	});

	const { data, error: errore } = await servizio.auth.admin.createUser({
		email: `${nome.toLowerCase().replace(/\s+/g, '')}@${DOMINIO}`,
		password,
		// Niente conferma: l'indirizzo e' tecnico e non esiste una casella.
		email_confirm: true,
		// Il nome sta nei metadati dell'utente, i privilegi in quelli
		// dell'applicazione: questi ultimi li scrive solo chi ha la chiave di
		// servizio, quindi non c'e' modo di dichiararsi admin iscrivendosi.
		user_metadata: { nome },
		app_metadata: {
			is_admin: corpo?.is_admin === true,
			sola_lettura: corpo?.sola_lettura === true,
			nascosto: corpo?.nascosto === true
		}
	});

	if (errore) {
		const gia = /already|duplicate/i.test(errore.message);
		error(gia ? 409 : 400, gia ? 'Esiste gia un account con questo nome' : errore.message);
	}

	// Il profilo lo crea il trigger su auth.users: qui si restituisce solo
	// l'id, il resto lo rilegge il pannello.
	return json({ id: data.user?.id });
};
