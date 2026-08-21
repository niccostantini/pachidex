-- ============================================================================
-- Pachino Express — foto di riferimento
--
-- Non tutti sanno com'e' fatta una folaga. Ogni elemento puo' avere una foto
-- di riferimento — utile soprattutto per gli animali — che si vede prima di
-- averlo catturato, cioe' proprio quando serve capire cosa si sta guardando.
--
-- La colonna tiene solo un NOME, non un URL: i file vivono nel repo sotto
-- src/assets/riferimenti/ e Vite li impacchetta col resto. Cosi' il service
-- worker li precarica e restano leggibili anche senza campo, che dalle parti
-- della riserva e' la norma piu' che l'eccezione.
-- ============================================================================

alter table items add column if not exists riferimento text;

comment on column items.riferimento is
	'Nome del file (senza estensione) in src/assets/riferimenti/, non un URL';

-- La vista del PachiDex deve portarselo dietro: la griglia legge da qui.
-- Va ricreata e non sostituita: `create or replace view` non sa infilare una
-- colonna in mezzo alle altre, prova a rinominare quelle che gia' ci sono.
drop view if exists v_dex;

create view v_dex as
select
	i.id as item_id,
	i.nome,
	i.categoria,
	i.rarita,
	i.croquembouche,
	i.ripetibile,
	i.validazione,
	i.note,
	i.lat,
	i.lng,
	i.riferimento,
	f.foto_url as prima_foto,
	f.user_id as primo_scopritore,
	f.timestamp as prima_volta,
	coalesce(st.catture_gruppo, 0) as catture_gruppo,
	coalesce(st.scopritori, 0) as scopritori
from items i
left join lateral (
	select c.foto_url, c.user_id, c.timestamp
	from captures c
	where c.item_id = i.id and c.stato <> 'invalidato'
	order by c.timestamp asc
	limit 1
) f on true
left join lateral (
	select count(*)::int as catture_gruppo, count(distinct c.user_id)::int as scopritori
	from captures c
	where c.item_id = i.id and c.stato <> 'invalidato'
) st on true
where i.attivo;

alter view v_dex set (security_invoker = true);
