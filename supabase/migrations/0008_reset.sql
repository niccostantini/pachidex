-- ============================================================================
-- Pachino Express — azzeramento del gioco
--
-- Serve per ricominciare da capo: cancella tutta la cronaca (catture,
-- contestazioni, voti, reazioni, scambi) e anche le sfiziosita' del PachiDex.
-- Restano solo i giocatori e la configurazione, cioe' l'ossatura dell'app.
--
-- E' una funzione e non una sequenza di DELETE dal client perche' cosi' o
-- passa tutto o non passa niente: un azzeramento a meta', con le catture
-- sparite e le contestazioni ancora li', lascerebbe il gioco in uno stato
-- che nessuna schermata sa raccontare.
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
	-- L'ordine segue le dipendenze, anche se le cascate farebbero da sole:
	-- contarle una per una serve a dire all'admin cosa e' stato buttato.
	select count(*) into n_voti from votes;
	delete from votes;

	select count(*) into n_contestazioni from contests;
	delete from contests;

	select count(*) into n_reazioni from reactions;
	delete from reactions;

	select count(*) into n_catture from captures;
	delete from captures;

	select count(*) into n_scambi from transfers;
	delete from transfers;

	select count(*) into n_item from items;
	delete from items;

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
