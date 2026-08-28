-- ============================================================================
-- Pachino Express — rimette i tag dentro il saldo
--
-- Regressione introdotta da 0019: per aggiungere il bonus dei set ho
-- riscritto v_saldi partendo dalla versione di 0002, che contava le catture.
-- Ma 0011 l'aveva gia' corretta per contare i CREDITI, cioe' anche gli
-- elementi sbloccati facendosi taggare.
--
-- Effetto: chi veniva taggato si vedeva l'elemento comparire nel PachiDex ma
-- non prendeva un Croquembouche, mentre la schermata di cattura promette
-- l'esatto contrario — "scrivi @ per dare i punti anche a chi era con te".
--
-- Qui si torna ai crediti e si tiene il bonus dei set. Nessun dato da
-- sistemare: essendo tutte viste calcolate, i punti arretrati ricompaiono da
-- soli appena si rilegge.
-- ============================================================================

create or replace view v_saldi as
with guadagni as (
	-- Dai crediti, non dalle catture: cosi' i tag contano e i doppioni sui
	-- non ripetibili no, senza doverlo ripetere in ogni query.
	select user_id, sum(croquembouche)::int as croq
	from v_crediti
	group by user_id
),
costi as (
	-- Aprire una contestazione costa sempre, comunque vada.
	select contestante_id as user_id, sum(costo_pagato)::int as croq
	from contests
	group by contestante_id
),
penalita as (
	select user_id, sum(croq)::int as croq
	from (
		-- La penalita' la paga chi ha pubblicato, non chi e' stato taggato:
		-- e' lui che ha messo la faccia sulla foto.
		select cap.user_id, co.penalita as croq
		from contests co
		join captures cap on cap.id = co.capture_id
		where co.stato = 'chiusa_non_valido'
		union all
		-- Il contestante paga quando la cattura regge.
		select co.contestante_id, co.penalita
		from contests co
		where co.stato = 'chiusa_valido'
	) x
	group by user_id
),
scambi as (
	select user_id, sum(croq)::int as croq
	from (
		select from_user_id as user_id, -importo as croq from transfers where not annullato
		union all
		select to_user_id, importo from transfers where not annullato
	) x
	group by user_id
)
select
	u.id as user_id,
	u.nome,
	coalesce(g.croq, 0) + coalesce(b.croq, 0) as guadagnati,
	coalesce(c.croq, 0) as spesi_in_contestazioni,
	coalesce(p.croq, 0) as penalita,
	coalesce(s.croq, 0) as saldo_scambi,
	coalesce(g.croq, 0) + coalesce(b.croq, 0)
		- coalesce(c.croq, 0) - coalesce(p.croq, 0) + coalesce(s.croq, 0) as saldo
from users u
left join guadagni g on g.user_id = u.id
left join costi c on c.user_id = u.id
left join penalita p on p.user_id = u.id
left join scambi s on s.user_id = u.id
left join v_set_premi b on b.user_id = u.id;

-- Nessun alter su security_invoker: v_saldi non l'ha mai avuto e cambiarlo
-- adesso, a vacanza cominciata, sarebbe un rischio gratuito.
