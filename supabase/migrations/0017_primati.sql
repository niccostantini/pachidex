-- ============================================================================
-- Pachino Express — i primati
--
-- Chi scopre per primo un elemento per tutto il gruppo merita che si sappia.
-- Il dato c'era gia' dentro v_dex (primo_scopritore), ma serviva sapere
-- QUALE cattura e' stata la prima, non solo chi l'ha fatta: il feed deve
-- poter timbrare quel singolo post.
--
-- Una riga per elemento, quindi al massimo quante sono le sfiziosita': si
-- carica tutta insieme al feed senza pesare.
-- ============================================================================

create or replace view v_primati as
select distinct on (c.item_id)
	c.id as capture_id,
	c.item_id,
	c.user_id,
	c.timestamp
from captures c
where c.stato <> 'invalidato'
order by c.item_id, c.timestamp asc;

alter view v_primati set (security_invoker = true);
