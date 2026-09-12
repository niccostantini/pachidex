-- ============================================================================
-- Pachino Express — la classifica di stagione, e i set che si possono chiudere
--
-- Due code della stessa faccenda.
--
-- La classifica ora ha due numeri: i punti della stagione, che sono quelli
-- della gara, e il portacroque, che e' quello che hai in tasca. In pagina si
-- ordina per punti — il saldo resta perche' serve a sapere quanto puoi
-- spendere, non a dire chi sta vincendo.
--
-- E i set: col catalogo sorteggiato puo' capitare che un requisito non abbia
-- piu' nessuna sfiziosita' che lo soddisfa — "una cosa col nome che contiene
-- Vendicari" quando Vendicari non e' uscita. Quel set diventa impossibile, e
-- un set impossibile in pagina e' peggio di un set assente: uno ci prova,
-- non capisce, e smette di fidarsi delle altre schede. Si nasconde.
-- ============================================================================

-- --- i set che questa stagione si possono davvero chiudere ------------------
-- Orario e "tutti taggati" sono sempre possibili: non dipendono dal catalogo.
-- Parola, tutte_parola e categoria si: se non c'e' niente che le soddisfa,
-- il set resta fuori.
create or replace view v_set_giocabili
with (security_invoker = true)
as
select s.id as set_id
from game_sets s
where s.attivo
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

-- --- v_set_stato, ristretta a quelli ----------------------------------------
create or replace view v_set_stato
with (security_invoker = true)
as
with totali as (
	select set_id, count(*)::int as totale from set_requisiti group by set_id
),
nel_giorno_migliore as (
	select set_id, user_id, max(n)::int as n
	from (
		select set_id, user_id, giorno, count(distinct requisito_id) as n
		from v_set_soddisfatti
		group by set_id, user_id, giorno
	) x
	group by set_id, user_id
),
in_tutto as (
	select set_id, user_id, count(distinct requisito_id)::int as n
	from v_set_soddisfatti
	group by set_id, user_id
)
select
	s.id as set_id,
	u.id as user_id,
	case
		when s.stesso_giorno or s.giorno is not null then coalesce(g.n, 0)
		else coalesce(a.n, 0)
	end as fatti,
	t.totale,
	case
		when s.stesso_giorno or s.giorno is not null then coalesce(g.n, 0)
		else coalesce(a.n, 0)
	end >= t.totale as completo
from game_sets s
join v_set_giocabili gi on gi.set_id = s.id
join totali t on t.set_id = s.id
join users u on in_partita(u.id)
left join nel_giorno_migliore g on g.set_id = s.id and g.user_id = u.id
left join in_tutto a on a.set_id = s.id and a.user_id = u.id
where s.attivo;

-- --- la classifica ----------------------------------------------------------
-- Collezione e catture si contano nella finestra come tutto il resto: a fine
-- stagione le catture spariscono davvero, e prima di allora e' giusto che il
-- conto dica quello che hai fatto in queste due settimane.
-- Va buttata e rifatta: "create or replace" non sa infilare una colonna in
-- mezzo alle altre, prova a rinominare quelle che ci sono gia'.
drop view if exists v_classifica;

create view v_classifica
with (security_invoker = true)
as
select
	p.user_id,
	p.nome,
	p.punti,
	p.acquisiti,
	p.penalita,
	s.saldo,
	s.guadagnati,
	coalesce(d.unici, 0) as item_unici,
	coalesce(d.catture, 0) as catture_totali
from v_punti_stagione p
join v_saldi s on s.user_id = p.user_id
left join (
	select cr.user_id,
	       count(distinct cr.item_id)::int as unici,
	       count(*)::int as catture
	from v_crediti cr, finestra_corrente() f
	where (cr.timestamp at time zone 'Europe/Rome')::date >= f.da
	  and (cr.timestamp at time zone 'Europe/Rome')::date < f.a
	group by cr.user_id
) d on d.user_id = p.user_id;
