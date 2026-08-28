-- ============================================================================
-- Pachino Express — chi contesta e vince ci guadagna
--
-- Prima aprire una contestazione costava 5 e basta: anche vincendola non si
-- rivedevano. Ma contestare la foto di un amico e' una cosa che si paga in
-- faccia, non in Croquembouche, e se uno ha ragione deve convenirgli averla
-- detta — altrimenti nessuno contesta piu' niente e le regole le fa chi bara.
--
-- Ora chi vince si riprende quello che ha speso piu' altrettanto: con il
-- costo a 5 fanno 10. Si moltiplica il costo effettivamente pagato, tenuto
-- sulla riga della contestazione, e non il valore di configurazione attuale:
-- cosi' una contestazione vecchia resta regolata dal prezzo che aveva quando
-- e' stata aperta, come gia' vale per la penalita'.
--
-- Chi contesta e perde continua a pagare tutto, costo e penalita'.
--
-- Retroattivo, essendo una vista calcolata: la contestazione gia' chiusa si
-- sistema da sola.
-- ============================================================================

create or replace view v_saldi as
with guadagni as (
	-- Dai crediti, non dalle catture: cosi' i tag contano e i doppioni sui
	-- non ripetibili no.
	select user_id, sum(croquembouche)::int as croq
	from v_crediti
	group by user_id
),
costi as (
	-- Aprire costa sempre, sul momento. Se poi si vince, sotto si riprende.
	select contestante_id as user_id, sum(costo_pagato)::int as croq
	from contests
	group by contestante_id
),
premi as (
	-- Aveva ragione: si riprende la posta e altrettanto di premio.
	select contestante_id as user_id, sum(costo_pagato * 2)::int as croq
	from contests
	where stato = 'chiusa_non_valido'
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
	coalesce(g.croq, 0) + coalesce(b.croq, 0) + coalesce(pr.croq, 0) as guadagnati,
	coalesce(c.croq, 0) as spesi_in_contestazioni,
	coalesce(p.croq, 0) as penalita,
	coalesce(s.croq, 0) as saldo_scambi,
	coalesce(g.croq, 0) + coalesce(b.croq, 0) + coalesce(pr.croq, 0)
		- coalesce(c.croq, 0) - coalesce(p.croq, 0) + coalesce(s.croq, 0) as saldo
from users u
left join guadagni g on g.user_id = u.id
left join costi c on c.user_id = u.id
left join premi pr on pr.user_id = u.id
left join penalita p on p.user_id = u.id
left join scambi s on s.user_id = u.id
left join v_set_premi b on b.user_id = u.id;

-- La descrizione diceva "comunque vada", che adesso non e' piu' vero.
update game_config
set descrizione = 'Croquembouche che paga chi apre una contestazione; se poi vince si riprende il doppio'
where chiave = 'costo_apertura_contestazione';
