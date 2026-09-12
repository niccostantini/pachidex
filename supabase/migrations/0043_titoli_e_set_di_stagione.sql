-- ============================================================================
-- Pachino Express — titoli e set seguono la stagione
--
-- "I titoli si azzerano, i set anche." Qui le due viste smettono di guardare
-- tutta la storia e guardano solo la finestra aperta.
--
-- I set in piu' cambiano catalogo: contano le sfiziosita' in gioco adesso, il
-- terzo sorteggiato. E' anche il modo in cui i set dinamici restano sensati —
-- "tutte le spiagge" diventa "tutte le spiagge di questa stagione" invece di
-- una cosa impossibile perche' meta' delle spiagge non e' sorteggiata.
--
-- Le due viste si riscrivono per intero perche' non si estendono. Il corpo e'
-- quello di prima: cambia da dove pescano e il filtro sulla finestra.
--
-- Senza stagioni aperte la finestra e' infinita e il catalogo e' tutto: si
-- comportano come hanno sempre fatto.
-- ============================================================================

-- --- i sei titoli, di questa stagione ---------------------------------------
-- Likes e scambi vanno filtrati come le catture: non si cancellano a fine
-- stagione, quindi senza finestra "La piaciona" e "La businessperson"
-- resterebbero appese a chi le ha prese la prima volta.
create or replace view v_titoli
with (security_invoker = true)
as
WITH primi_crediti AS (
         SELECT cr.user_id,
            cr.item_id,
            min(cr."timestamp") AS quando
           FROM v_crediti cr
             JOIN users u ON u.id = cr.user_id AND NOT u.nascosto,
             finestra_corrente() f
          WHERE (cr."timestamp" AT TIME ZONE 'Europe/Rome')::date >= f.da
            AND (cr."timestamp" AT TIME ZONE 'Europe/Rome')::date < f.a
          GROUP BY cr.user_id, cr.item_id
        ), per_categoria AS (
         SELECT
                CASE i.categoria
                    WHEN 'pietanza'::text THEN 'ghiottona'::text
                    WHEN 'animale'::text THEN 'birdwatcher'::text
                    WHEN 'posto'::text THEN 'camminatrice'::text
                    ELSE NULL::text
                END AS titolo,
            p.user_id,
            count(*)::integer AS conteggio,
            max(p.quando) AS ultimo
           FROM primi_crediti p
             JOIN items i ON i.id = p.item_id
          WHERE i.categoria = ANY (ARRAY['pietanza'::text, 'animale'::text, 'posto'::text])
          GROUP BY i.categoria, p.user_id
        ), scoperte AS (
         SELECT 'scopritrice'::text AS titolo,
            pr.user_id,
            count(*)::integer AS conteggio,
            max(pr."timestamp") AS ultimo
           FROM v_primati pr
             JOIN users u ON u.id = pr.user_id AND NOT u.nascosto,
             finestra_corrente() f
          WHERE (pr."timestamp" AT TIME ZONE 'Europe/Rome')::date >= f.da
            AND (pr."timestamp" AT TIME ZONE 'Europe/Rome')::date < f.a
          GROUP BY pr.user_id
        ), affari AS (
         SELECT 'businessperson'::text AS titolo,
            t.from_user_id AS user_id,
            sum(t.importo)::integer AS conteggio,
            max(t.created_at) AS ultimo
           FROM transfers t
             JOIN users u ON u.id = t.from_user_id AND NOT u.nascosto,
             finestra_corrente() f
          WHERE NOT t.annullato
            AND (t.created_at AT TIME ZONE 'Europe/Rome')::date >= f.da
            AND (t.created_at AT TIME ZONE 'Europe/Rome')::date < f.a
          GROUP BY t.from_user_id
        ), gradimento AS (
         SELECT 'piaciona'::text AS titolo,
            c.user_id,
            count(*)::integer AS conteggio,
            max(r.created_at) AS ultimo
           FROM reactions r
             JOIN captures c ON c.id = r.capture_id
             JOIN users u ON u.id = c.user_id AND NOT u.nascosto,
             finestra_corrente() f
          WHERE c.stato <> 'invalidato'::text AND r.user_id <> c.user_id
            AND (r.created_at AT TIME ZONE 'Europe/Rome')::date >= f.da
            AND (r.created_at AT TIME ZONE 'Europe/Rome')::date < f.a
          GROUP BY c.user_id
        ), tutte AS (
         SELECT per_categoria.titolo,
            per_categoria.user_id,
            per_categoria.conteggio,
            per_categoria.ultimo
           FROM per_categoria
        UNION ALL
         SELECT scoperte.titolo,
            scoperte.user_id,
            scoperte.conteggio,
            scoperte.ultimo
           FROM scoperte
        UNION ALL
         SELECT affari.titolo,
            affari.user_id,
            affari.conteggio,
            affari.ultimo
           FROM affari
        UNION ALL
         SELECT gradimento.titolo,
            gradimento.user_id,
            gradimento.conteggio,
            gradimento.ultimo
           FROM gradimento
        )
 SELECT DISTINCT ON (titolo) titolo,
    user_id,
    conteggio
   FROM tutte
  WHERE conteggio > 0
  ORDER BY titolo, conteggio DESC, ultimo;;


-- --- i set, di questa stagione ----------------------------------------------
create or replace view v_set_soddisfatti
with (security_invoker = true)
as
with crediti as (
	-- Giorno e ora vanno letti nell'ora di Pachino, non in UTC: una granita
	-- delle 23:30 in UTC sarebbe gia' del giorno dopo, e "prima delle 8"
	-- diventerebbe un orario a caso.
	select
		cr.user_id,
		cr.item_id,
		(cr.timestamp at time zone 'Europe/Rome')::date as giorno,
		extract(hour from cr.timestamp at time zone 'Europe/Rome')::int as ora
	from v_crediti cr, finestra_corrente() f
	where (cr.timestamp at time zone 'Europe/Rome')::date >= f.da
	  and (cr.timestamp at time zone 'Europe/Rome')::date < f.a
),
-- Catture in cui c'e' tutto il gruppo: l'autore piu' i taggati. Chi guarda da
-- fuori non conta nel totale, altrimenti la foto di gruppo la chiuderebbe solo
-- una fotografia impossibile.
al_completo as (
	select
		c.id as capture_id,
		(c.timestamp at time zone 'Europe/Rome')::date as giorno,
		c.user_id as autore
	from captures c, finestra_corrente() f
	where c.stato in ('valido', 'in_contestazione')
	  and (c.timestamp at time zone 'Europe/Rome')::date >= f.da
	  and (c.timestamp at time zone 'Europe/Rome')::date < f.a
	  and (select count(*) from capture_tags t where t.capture_id = c.id) + 1
	      >= (select count(*) from users where not nascosto)
),
-- Il requisito lo chiudono tutti quelli che erano nella foto, non solo chi
-- l'ha scattata: "ci siete tutti" vale per tutti.
presenti as (
	select a.capture_id, a.giorno, a.autore as user_id from al_completo a
	union
	select a.capture_id, a.giorno, t.user_id
	from al_completo a
	join capture_tags t on t.capture_id = a.capture_id
),
per_parola as (
	select r.id as requisito_id, r.set_id, c.user_id, c.giorno
	from set_requisiti r
	join v_items_stagione i on i.nome ilike '%' || r.valore || '%'
	join crediti c on c.item_id = i.id
	where r.tipo = 'parola'
),
per_categoria as (
	select r.id as requisito_id, r.set_id, c.user_id, c.giorno
	from set_requisiti r
	join v_items_stagione i on i.categoria = r.valore
	join crediti c on c.item_id = i.id
	where r.tipo = 'categoria'
),
per_orario as (
	select r.id as requisito_id, r.set_id, c.user_id, c.giorno
	from set_requisiti r
	join crediti c on c.ora >= r.ora_da and c.ora < r.ora_a
	where r.tipo = 'orario'
),
per_gruppo as (
	select r.id as requisito_id, r.set_id, p.user_id, p.giorno
	from set_requisiti r
	cross join presenti p
	where r.tipo = 'tutti_taggati'
),
-- "tutte_parola" non si accontenta di uno: servono tutti gli elementi che
-- contengono quella parola. Il giorno buono e' quello in cui si e' chiuso il
-- conto, cosi' anche questo requisito sa dire quando e' stato soddisfatto.
bersaglio as (
	select r.id as requisito_id, count(*) as quanti
	from set_requisiti r
	join v_items_stagione i on i.nome ilike '%' || r.valore || '%'
	where r.tipo = 'tutte_parola'
	group by r.id
),
raccolti as (
	select r.id as requisito_id, r.set_id, c.user_id,
	       count(distinct i.id) as presi, max(c.giorno) as giorno
	from set_requisiti r
	join v_items_stagione i on i.nome ilike '%' || r.valore || '%'
	join crediti c on c.item_id = i.id
	where r.tipo = 'tutte_parola'
	group by r.id, r.set_id, c.user_id
),
per_tutte as (
	select rc.requisito_id, rc.set_id, rc.user_id, rc.giorno
	from raccolti rc
	join bersaglio b on b.requisito_id = rc.requisito_id
	where rc.presi >= b.quanti
),
tutto as (
	select requisito_id, set_id, user_id, giorno from per_parola
	union all select requisito_id, set_id, user_id, giorno from per_categoria
	union all select requisito_id, set_id, user_id, giorno from per_orario
	union all select requisito_id, set_id, user_id, giorno from per_gruppo
	union all select requisito_id, set_id, user_id, giorno from per_tutte
)
select distinct t.requisito_id, t.set_id, t.user_id, t.giorno
from tutto t
join game_sets s on s.id = t.set_id
-- Un set a data fissa guarda solo quel giorno: il selfie del 28 fatto il 30
-- non conta, altrimenti non era il primo giorno.
where s.attivo and (s.giorno is null or t.giorno = s.giorno);
