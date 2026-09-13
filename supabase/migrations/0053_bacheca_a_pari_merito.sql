-- ============================================================================
-- Pachino Express — il pari merito si vede anche mentre si gioca
--
-- La 0052 lo aveva sistemato solo alla fine: la coccarda andava a tutte
-- quelle arrivate allo stesso punto, ma durante la stagione la bacheca ne
-- mostrava comunque una sola — quella che c'era arrivata prima. Era la regola
-- della cintura: il titolo ce l'ha una persona alla volta, e si soffia.
--
-- Il guaio e' che le due cose non si parlavano. Per due settimane leggevi che
-- «La ghiottona» era Ciccio, e all'ultimo giorno la coccarda la prendevano
-- Ciccio e Nina. Chi era in parita' non vedeva da nessuna parte di esserci
-- — e a sette pietanze pari non c'e' niente da soffiare a nessuno: sei gia'
-- li'.
--
-- Quindi la bacheca dice la verita' che dira' anche la premiazione: tutte
-- quelle che stanno in testa. La sfida resta — chi e' a sei ne cattura una e
-- entra anche lei — solo che adesso entrarci si vede.
--
-- E il taglio e' uno solo, qui: assegna_coccarde smette di rifarsi il conto
-- per conto suo e legge la stessa vista. Due definizioni della stessa cosa
-- sono due cose che prima o poi divergono.
-- ============================================================================

create or replace view v_titoli
with (security_invoker = true)
as
select t.titolo, t.user_id, t.conteggio
from v_titoli_tutti t
where t.conteggio = (
	select max(x.conteggio) from v_titoli_tutti x where x.titolo = t.titolo
);

-- --- le coccarde leggono la bacheca ----------------------------------------
create or replace function assegna_coccarde(p_stagione int)
returns int language plpgsql security definer set search_path = public as $$
declare v_quante int; v_totali int := 0;
begin
	delete from coccarde where stagione = p_stagione;

	-- Il podio. Solo chi ha fatto punti: una stagione in cui non hai giocato
	-- non ti mette terzo per assenza degli altri.
	insert into coccarde (user_id, stagione, tipo, chiave, etichetta, quanto)
	select ss.user_id, p_stagione, 'podio', ss.posizione::text,
	       case ss.posizione when 1 then 'Prima in classifica'
	                         when 2 then 'Seconda in classifica'
	                         else 'Terza in classifica' end,
	       ss.punti
	from stagione_saldi ss
	where ss.stagione = p_stagione and ss.posizione <= 3 and ss.punti > 0;
	get diagnostics v_quante = row_count;
	v_totali := v_totali + v_quante;

	-- I titoli: quelli che la bacheca dava per vincenti l'ultimo giorno, che
	-- adesso sono gia' tutti quelli in testa.
	insert into coccarde (user_id, stagione, tipo, chiave, etichetta, quanto)
	select t.user_id, p_stagione, 'titolo', t.titolo,
	       case t.titolo
	           when 'ghiottona' then 'La ghiottona'
	           when 'birdwatcher' then 'La birdwatcher'
	           when 'camminatrice' then 'La camminatrice'
	           when 'scopritrice' then 'La scopritrice'
	           when 'businessperson' then 'La businessperson'
	           when 'piaciona' then 'La piaciona'
	           else t.titolo
	       end,
	       t.conteggio
	from v_titoli t;
	get diagnostics v_quante = row_count;
	return v_totali + v_quante;
end;
$$;

revoke all on function assegna_coccarde(int) from public, anon, authenticated;
