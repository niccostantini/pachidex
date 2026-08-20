-- ============================================================================
-- Pachino Express — azzeramento compatibile con safeupdate
--
-- Il ruolo `authenticator`, quello con cui PostgREST esegue ogni chiamata
-- dell'app, carica l'estensione `safeupdate`: una DELETE senza WHERE viene
-- rifiutata con "DELETE requires a WHERE clause". E' una rete di sicurezza
-- di Supabase contro le cancellazioni di massa per sbaglio.
--
-- Le migration invece girano come `postgres`, che non ha quella protezione:
-- per questo la 0008 si era applicata senza un lamento e l'errore e' saltato
-- fuori solo premendo il pulsante dall'app.
--
-- `where true` e' il modo previsto per dire "so cosa sto facendo": qui la
-- cancellazione totale e' esattamente l'intenzione.
-- ============================================================================

create or replace function azzera_gioco()
returns table (tabella text, cancellate int)
language plpgsql
set search_path = public
as $$
declare
	n_catture int;
	n_contestazioni int;
	n_voti int;
	n_reazioni int;
	n_scambi int;
	n_item int;
begin
	select count(*) into n_voti from votes;
	delete from votes where true;

	select count(*) into n_contestazioni from contests;
	delete from contests where true;

	select count(*) into n_reazioni from reactions;
	delete from reactions where true;

	select count(*) into n_catture from captures;
	delete from captures where true;

	select count(*) into n_scambi from transfers;
	delete from transfers where true;

	select count(*) into n_item from items;
	delete from items where true;

	return query
	select * from (
		values
			('sfiziosita', n_item),
			('catture', n_catture),
			('contestazioni', n_contestazioni),
			('voti', n_voti),
			('reazioni', n_reazioni),
			('scambi', n_scambi)
	) as t(tabella, cancellate);
end;
$$;
