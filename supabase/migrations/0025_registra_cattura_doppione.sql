-- ============================================================================
-- Pachino Express — via il doppione di registra_cattura
--
-- La 0023 ha aggiunto p_scattata cambiando la firma della funzione. In
-- Postgres "create or replace function" con una firma diversa non sostituisce
-- niente: crea una SECONDA funzione. Quella vecchia a sette argomenti e'
-- rimasta in piedi senza limite di ritmo e, dopo la 0024, senza nemmeno il
-- congelamento del gioco.
--
-- Una chiamata con sette argomenti nominati corrispondeva esattamente alla
-- vecchia e Postgres sceglieva quella: bastava un telefono con l'app non
-- aggiornata per scavalcare tutti e due i controlli.
--
-- Si toglie. Quella a otto argomenti ha il default su p_scattata, quindi
-- accetta lo stesso le chiamate corte — verificato.
-- ============================================================================

drop function if exists registra_cattura(
	uuid, uuid, text, text, double precision, double precision, uuid[]
);

-- --- l'orologio buono -------------------------------------------------------
-- La cerimonia si regge su istanti condivisi: se il telefono di qualcuno va
-- avanti di due minuti, quello vede scadere il tempo di voto mentre gli altri
-- stanno ancora scegliendo. Ogni telefono chiede una volta che ore sono al
-- server e da li' in poi corregge il proprio orologio.
create or replace function adesso() returns timestamptz
language sql stable set search_path = public as $$ select now() $$;
