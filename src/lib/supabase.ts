import { createClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_ANON_KEY, PUBLIC_SUPABASE_URL } from '$env/static/public';

export const supabase = createClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY, {
	// Nessun login: non c'e' sessione da conservare ne' token da rinfrescare.
	auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
	// Rete mobile ballerina: meglio non farsi sommergere di eventi.
	realtime: { params: { eventsPerSecond: 5 } }
});

/** Messaggio d'errore leggibile: Postgres parla, noi traduciamo poco. */
export function messaggioErrore(e: unknown): string {
	if (!e) return 'Qualcosa e andato storto';
	const err = e as { message?: string; error_description?: string };
	const raw = err.message ?? err.error_description ?? String(e);
	if (raw.includes('Failed to fetch') || raw.includes('NetworkError')) {
		return 'Niente connessione';
	}
	return raw;
}
