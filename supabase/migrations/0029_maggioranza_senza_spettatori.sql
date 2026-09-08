-- ============================================================================
-- Pachino Express — chi guarda non fa maggioranza
--
-- Aggiungendo l'account di sola lettura si e' rotta la contestazione: il
-- calcolo della maggioranza contava tutti gli utenti, quindi uno spettatore
-- che non puo' votare alzava lo stesso l'asticella. Con sei giocatori e uno
-- spettatore servivano quattro voti su sei votanti possibili invece di tre
-- su cinque.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.risolvi_contestazione(p_contest uuid)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
	v_capture uuid;
	v_scadenza timestamptz;
	v_autore uuid;
	v_votanti int;
	v_maggioranza int;
	v_non int;
	v_val int;
	v_nuovo text;
begin
	select co.capture_id, co.scadenza into v_capture, v_scadenza
	from contests co
	where co.id = p_contest and co.stato = 'aperta';

	if v_capture is null then
		return null; -- gia' chiusa, o inesistente
	end if;

	select user_id into v_autore from captures where id = v_capture;

	-- Vota chiunque tranne l'autore della cattura. Con 6 profili fanno 5 voti,
	-- sempre dispari: la parita' non puo' verificarsi.
	-- Chi puo' solo guardare non vota, quindi non deve nemmeno contare: se
	-- entrasse nel totale alzerebbe la maggioranza necessaria e renderebbe le
	-- contestazioni piu' difficili da chiudere, o impossibili con pochi
	-- giocatori. Con un account di sola lettura in giro succedeva davvero.
	select count(*)::int into v_votanti
	from users where id <> v_autore and not sola_lettura;
	v_maggioranza := v_votanti / 2 + 1;

	select
		count(*) filter (where voto = 'non_valido')::int,
		count(*) filter (where voto = 'valido')::int
	into v_non, v_val
	from votes
	where contest_id = p_contest;

	if v_non >= v_maggioranza then
		v_nuovo := 'chiusa_non_valido';
	elsif v_val >= v_maggioranza then
		v_nuovo := 'chiusa_valido';
	elsif now() >= v_scadenza then
		v_nuovo := 'scaduta';
	else
		return 'aperta';
	end if;

	update contests set stato = v_nuovo, risolta_at = now() where id = p_contest;
	update captures
	set stato = case when v_nuovo = 'chiusa_non_valido' then 'invalidato' else 'valido' end
	where id = v_capture;

	return v_nuovo;
end;
$function$

;
