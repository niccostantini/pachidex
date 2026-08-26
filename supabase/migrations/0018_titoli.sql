-- ============================================================================
-- Pachino Express — i titoli contesi
--
-- Non sono medaglie: sono cinture. Una sola per titolo, sempre a chi e' in
-- testa adesso, e si perdono. Una medaglia la prendi il terzo giorno e da li'
-- in poi e' arredamento; un titolo che qualcuno ti puo' soffiare resta vivo
-- fino al 6 settembre.
--
-- Nessuna tabella nuova: e' tutto gia' scritto da qualche parte. La vista si
-- ricalcola a ogni lettura, quindi non c'e' niente da tenere aggiornato e
-- niente che possa andare fuori sincrono.
--
-- A parita' di conteggio vince chi ci e' arrivato prima. Il criterio e'
-- "ordina per conteggio decrescente, poi per ultimo evento crescente": se due
-- stanno entrambe a 7, quella il cui settimo e' piu' vecchio ci e' arrivata
-- prima. E' esattamente la regola della cintura.
-- ============================================================================

create or replace view v_titoli
with (security_invoker = true)
as
with
-- Per le categorie si contano elementi DIVERSI, non scatti: cinque arancine
-- restano una pietanza sola. Senza questo il titolo lo vincerebbe chi ha piu'
-- pazienza di rifotografare la stessa cosa.
--
-- Si parte da v_crediti e non da captures perche' un elemento si sblocca anche
-- facendosi taggare nella foto di qualcun altro: se eravate al tavolo insieme
-- avete mangiato insieme.
primi_crediti as (
	select cr.user_id, cr.item_id, min(cr.timestamp) as quando
	from v_crediti cr
	group by cr.user_id, cr.item_id
),
per_categoria as (
	select
		case i.categoria
			when 'pietanza' then 'ghiottona'
			when 'animale' then 'birdwatcher'
			when 'posto' then 'camminatrice'
		end as titolo,
		p.user_id,
		count(*)::int as conteggio,
		max(p.quando) as ultimo
	from primi_crediti p
	join items i on i.id = p.item_id
	where i.categoria in ('pietanza', 'animale', 'posto')
	group by i.categoria, p.user_id
),
scoperte as (
	select 'scopritrice' as titolo, pr.user_id, count(*)::int as conteggio, max(pr.timestamp) as ultimo
	from v_primati pr
	group by pr.user_id
),
-- Quanti Croquembouche ha fatto uscire dalle proprie tasche. Gli scambi
-- annullati dall'admin non contano: non sono mai avvenuti.
affari as (
	select 'businessperson' as titolo, t.from_user_id as user_id, sum(t.importo)::int as conteggio,
	       max(t.created_at) as ultimo
	from transfers t
	where not t.annullato
	group by t.from_user_id
),
-- I like ricevuti sulle proprie catture. Quelli che uno mette a se' stesso
-- non contano, altrimenti il titolo lo vince chi ha meno pudore.
gradimento as (
	select 'piaciona' as titolo, c.user_id, count(*)::int as conteggio, max(r.created_at) as ultimo
	from reactions r
	join captures c on c.id = r.capture_id
	where c.stato <> 'invalidato'
	  and r.user_id <> c.user_id
	group by c.user_id
),
tutte as (
	select titolo, user_id, conteggio, ultimo from per_categoria
	union all select titolo, user_id, conteggio, ultimo from scoperte
	union all select titolo, user_id, conteggio, ultimo from affari
	union all select titolo, user_id, conteggio, ultimo from gradimento
)
select distinct on (titolo)
	titolo,
	user_id,
	conteggio
from tutte
where conteggio > 0
order by titolo, conteggio desc, ultimo asc;
