-- ============================================================================
-- Pachino Express — chiusura automatica delle contestazioni scadute
--
-- OPZIONALE. Il client chiama comunque chiudi_contestazioni_scadute() a ogni
-- apertura del feed, quindi le scadenze funzionano anche senza cron: questo
-- serve solo perche' una contestazione si chiuda pure se nessuno apre l'app.
-- Se pg_cron non e' attivabile sul progetto, salta pure questa migration.
-- ============================================================================

create extension if not exists pg_cron;

select cron.schedule(
	'chiudi-contestazioni-scadute',
	'*/5 * * * *',
	$$ select chiudi_contestazioni_scadute() $$
);
