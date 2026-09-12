-- ============================================================================
-- Pachino Express — un set con la data sbagliata non si mostra
--
-- v_set_giocabili guardava solo il catalogo: spariva il set i cui elementi
-- non erano stati sorteggiati, ma restava quello legato a una data che nella
-- stagione non c'e' — "Il primo giorno", per dirne uno, che vuole una cattura
-- del 28 agosto mentre la stagione parte a settembre.
--
-- E' lo stesso difetto di prima: un set impossibile in pagina e' peggio di un
-- set assente, perche' uno ci prova, non capisce, e smette di fidarsi anche
-- delle altre schede.
-- ============================================================================

create or replace view v_set_giocabili
with (security_invoker = true)
as
select s.id as set_id
from game_sets s, finestra_corrente() f
where s.attivo
  -- Un set a data fissa vale solo se quel giorno cade dentro la stagione.
  and (s.giorno is null or (s.giorno >= f.da and s.giorno < f.a))
  and not exists (
	select 1
	from set_requisiti r
	where r.set_id = s.id
	  and r.tipo in ('parola', 'tutte_parola', 'categoria')
	  and not exists (
		select 1 from v_items_stagione i
		where (r.tipo in ('parola', 'tutte_parola') and i.nome ilike '%' || r.valore || '%')
		   or (r.tipo = 'categoria' and i.categoria = r.valore)
	  )
  );
