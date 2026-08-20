-- ============================================================================
-- Pachino Express — indurimento di sicurezza
-- Corregge due avvisi del linter Supabase emersi dopo il primo deploy.
-- ============================================================================

-- Le viste in Postgres girano di default con i permessi di chi le ha create
-- (SECURITY DEFINER "implicito"), bypassando le RLS di chi le interroga.
-- Oggi le RLS sono permissive apposta, quindi non cambia nulla in pratica —
-- ma se un domani si stringesse la sicurezza (es. Supabase Auth), queste
-- viste continuerebbero a bypassarla in silenzio. Meglio fissarlo ora.
alter view v_saldi set (security_invoker = true);
alter view v_classifica set (security_invoker = true);
alter view v_dex set (security_invoker = true);

-- Un search_path di sessione manomesso potrebbe in teoria dirottare le
-- chiamate non qualificate dentro le funzioni. Si fissa a schema('public'),
-- non vuoto: le funzioni referenziano tabelle senza prefisso e un
-- search_path vuoto le romperebbe tutte.
alter function metri_tra(double precision, double precision, double precision, double precision)
	set search_path = public;
alter function blocca_doppioni() set search_path = public;
alter function risolvi_contestazione(uuid) set search_path = public;
alter function apri_contestazione(uuid, uuid, text) set search_path = public;
alter function vota_contestazione(uuid, uuid, text) set search_path = public;
alter function chiudi_contestazioni_scadute() set search_path = public;
alter function registra_cattura(uuid, uuid, text, text, double precision, double precision)
	set search_path = public;
alter function invia_croquembouche(uuid, uuid, int, text) set search_path = public;
