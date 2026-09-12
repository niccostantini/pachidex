-- ============================================================================
-- Pachino Express — una contestazione sta tutta nella sua stagione
--
-- Aprendo la prima stagione, un giocatore e' partito a -10: una penalita' di
-- quindici presa per una cattura del primo settembre, finita nel conto di una
-- stagione cominciata il tredici. Nel seme era un artefatto — la
-- contestazione la si crea al momento del reset — ma il problema sotto e'
-- vero: una contestazione dura fino a ventiquattr'ore, quindi puo' nascere in
-- una stagione e chiudersi in quella dopo, e la penalita' cadeva nella
-- seconda per un fatto della prima.
--
-- Due mosse.
--
-- La prima: costo, penalita' e premio si datano a quando la contestazione e'
-- stata APERTA, non a quando si e' risolta. E' un evento solo e le sue
-- conseguenze stanno insieme, nella stagione in cui la lite e' nata.
--
-- La seconda: chiudere una stagione risolve le contestazioni ancora aperte,
-- con i voti che hanno. E' quello che fa gia' avvia_finale prima della
-- premiazione, per la stessa ragione — non si chiude un conto lasciando una
-- partita in sospeso. Ed e' anche cio' che rende sicura la prima mossa:
-- nessuna contestazione sopravvive alla chiusura, quindi datarla all'apertura
-- non puo' mai scrivere dentro una stagione gia' congelata.
-- ============================================================================

create or replace view v_movimenti
with (security_invoker = true)
as
-- entrate
select cr.user_id, (cr.timestamp at time zone 'Europe/Rome')::date as giorno,
       'cattura'::text as tipo, cr.croquembouche as importo
from v_crediti cr
union all
select p.user_id, p.giorno, 'presenza', p.croquembouche
from presenze p
union all
select co.contestante_id, (co.created_at at time zone 'Europe/Rome')::date,
       'contestazione_vinta', co.costo_pagato * 2
from contests co where co.stato = 'chiusa_non_valido'
union all
select e.vincitore_id, (e.assegnato_at at time zone 'Europe/Rome')::date,
       'premio', pr.croquembouche
from premi_esiti e join premi pr on pr.id = e.premio_id
where e.vincitore_id is not null
-- uscite: la penalita' e' un conto a parte perche' pesa anche in classifica
union all
select cap.user_id, (co.created_at at time zone 'Europe/Rome')::date,
       'penalita', -co.penalita
from contests co join captures cap on cap.id = co.capture_id
where co.stato = 'chiusa_non_valido'
union all
select co.contestante_id, (co.created_at at time zone 'Europe/Rome')::date,
       'penalita', -co.penalita
from contests co where co.stato = 'chiusa_valido'
union all
select co.contestante_id, (co.created_at at time zone 'Europe/Rome')::date,
       'spesa', -co.costo_pagato
from contests co
-- scambi: entrano nel portacroque, non nella classifica
union all
select t.from_user_id, (t.created_at at time zone 'Europe/Rome')::date, 'scambio', -t.importo
from transfers t where not t.annullato
union all
select t.to_user_id, (t.created_at at time zone 'Europe/Rome')::date, 'scambio', t.importo
from transfers t where not t.annullato;

-- --- chiudere risolve cio' che e' rimasto in sospeso -------------------------
create or replace function chiudi_stagione(p_giorni int default 14)
returns int language plpgsql security definer set search_path = public as $$
declare v_numero int; v_aperta record;
begin
	perform esigi_admin();
	select numero into v_numero from stagioni where chiusa_at is null;
	if v_numero is null then
		raise exception 'Non c''e'' nessuna stagione aperta';
	end if;
	if oggi_a_pachino() <= (select inizio from stagioni where numero = v_numero) then
		raise exception 'Questa stagione e'' cominciata oggi: chiuderla adesso lascerebbe i conti a meta''';
	end if;

	-- Le contestazioni ancora aperte si risolvono adesso, con i voti che
	-- hanno: lasciarle in sospeso vorrebbe dire congelare un conto che puo'
	-- ancora cambiare, e una penalita' che arriva a stagione chiusa non
	-- troverebbe piu' nessun posto dove andare.
	for v_aperta in select id from contests where stato = 'aperta' loop
		perform risolvi_contestazione(v_aperta.id);
	end loop;

	-- L'ordine conta: la finestra si stringe a oggi, poi il conto si congela,
	-- poi le coccarde (che leggono i titoli, e i titoli vivono nella
	-- finestra), poi le foto da tenere — che vanno prese finche' le catture
	-- ci sono ancora. Solo alla fine la stagione risulta chiusa.
	update stagioni set fine = oggi_a_pachino() where numero = v_numero;
	perform congela_stagione(v_numero);
	perform assegna_coccarde(v_numero);
	perform tieni_le_foto(v_numero);
	update stagioni set chiusa_at = now() where numero = v_numero;

	return apri_stagione(p_giorni);
end;
$$;

revoke all on function chiudi_stagione(int) from public, anon;
grant execute on function chiudi_stagione(int) to authenticated;
