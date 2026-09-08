-- ============================================================================
-- Pachino Express — via i capitoli della storia
--
-- Un amico aveva scritto una storia in otto capitoli che si sbloccavano
-- riempiendo una barra collettiva. Serviva a quella vacanza; adesso non piu'.
--
-- Se ne va tutto: la tabella dei capitoli, la vista dei punti, le funzioni
-- che li sbloccavano, e i "puntini" che i set regalavano oltre ai
-- Croquembouche. I set restano e continuano a valere: solo che adesso valgono
-- una moneta sola.
-- ============================================================================

drop function if exists sblocca_capitoli() cascade;
drop function if exists capitoli() cascade;
drop function if exists capitoli_admin() cascade;
-- La firma vera ha quattro argomenti: la 0016 ci ha aggiunto il flag per
-- ripulire il titolo, e una drop con la firma sbagliata non toglie niente.
drop function if exists imposta_capitolo(int, int, text, boolean) cascade;
drop view if exists v_punti_storia cascade;
drop table if exists story_chapters cascade;

-- --- i set non danno piu' puntini -------------------------------------------
-- v_set_premi restituiva due monete, croquembouche e puntini. Va rifatta con
-- una colonna in meno, e v_saldi con lei perche' ci si appoggia.
drop view if exists v_saldi cascade;
drop view if exists v_set_premi cascade;

alter table game_sets drop column if exists punti_storia;

create or replace view v_set_premi
with (security_invoker = true)
as
select st.user_id, sum(s.croquembouche)::int as croq
from v_set_stato st
join game_sets s on s.id = st.set_id
where st.completo
group by st.user_id;

create or replace view v_saldi as
with guadagni as (
	select user_id, sum(croquembouche)::int as croq from v_crediti group by user_id
),
costi as (
	select contestante_id as user_id, sum(costo_pagato)::int as croq from contests group by contestante_id
),
premi_contestazioni as (
	select contestante_id as user_id, sum(costo_pagato * 2)::int as croq
	from contests where stato = 'chiusa_non_valido' group by contestante_id
),
penalita as (
	select user_id, sum(croq)::int as croq
	from (
		select cap.user_id, co.penalita as croq
		from contests co join captures cap on cap.id = co.capture_id
		where co.stato = 'chiusa_non_valido'
		union all
		select co.contestante_id, co.penalita from contests co where co.stato = 'chiusa_valido'
	) x group by user_id
),
scambi as (
	select user_id, sum(croq)::int as croq
	from (
		select from_user_id as user_id, -importo as croq from transfers where not annullato
		union all
		select to_user_id, importo from transfers where not annullato
	) x group by user_id
)
select
	u.id as user_id,
	u.nome,
	coalesce(g.croq, 0) + coalesce(b.croq, 0) + coalesce(pc.croq, 0) + coalesce(pf.croq, 0) as guadagnati,
	coalesce(c.croq, 0) as spesi_in_contestazioni,
	coalesce(p.croq, 0) as penalita,
	coalesce(s.croq, 0) as saldo_scambi,
	coalesce(g.croq, 0) + coalesce(b.croq, 0) + coalesce(pc.croq, 0) + coalesce(pf.croq, 0)
		- coalesce(c.croq, 0) - coalesce(p.croq, 0) + coalesce(s.croq, 0) as saldo
from users u
left join guadagni g on g.user_id = u.id
left join costi c on c.user_id = u.id
left join premi_contestazioni pc on pc.user_id = u.id
left join penalita p on p.user_id = u.id
left join scambi s on s.user_id = u.id
left join v_set_premi b on b.user_id = u.id
left join v_premi_vinti pf on pf.user_id = u.id;

-- v_classifica cadeva insieme a v_saldi: si rifa' com'era, Spione escluso.
create or replace view v_classifica as
select s.user_id, s.nome, s.saldo, s.guadagnati,
       coalesce(d.unici, 0) as item_unici, coalesce(d.catture, 0) as catture_totali
from v_saldi s
join users u on u.id = s.user_id and not u.nascosto
left join (
	select user_id, count(distinct item_id)::int as unici, count(*)::int as catture
	from v_crediti group by user_id
) d on d.user_id = s.user_id;

alter view v_classifica set (security_invoker = true);

-- Il commento della colonna parlava ancora della barra: si aggiorna qui
-- invece di riscrivere la 0027, che e' gia' passata.
comment on column users.nascosto is
	'Fuori da classifica e titoli: guarda la partita da fuori.';
