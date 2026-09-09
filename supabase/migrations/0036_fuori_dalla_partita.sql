-- ============================================================================
-- Pachino Express — chi sta fuori sta fuori da tutto
--
-- Dentro users non ci sono solo giocatori: c'e' Admin, che tiene il gioco, e
-- c'e' Spione, che guarda per vedere com'e' fatto. La 0027 aveva gia' due
-- flag, ma ognuno copriva meta' del problema:
--
--   sola_lettura  non puo' scrivere niente
--   nascosto      non entra in classifica ne' nei titoli
--
-- Admin ha solo il secondo, quindi finora poteva catturare, mettere like,
-- aprire contestazioni, votarle e passare Croquembouche: tutto quello che fa
-- un giocatore, tranne comparire in classifica. E contava come votante,
-- alzando la maggioranza di una contestazione con un voto che non sarebbe
-- mai arrivato.
--
-- Qui le due domande diventano esplicite e si rispondono in un posto solo:
--
--   in_partita(id)  conta come giocatore?
--   puo_agire(id)   e' in partita e puo' anche scrivere?
--
-- E si applicano dove il gioco le stava dando per scontate.
-- ============================================================================

-- --- le due domande ---------------------------------------------------------
-- In partita c'e' chi non e' nascosto: e' gia' il significato che nascosto ha
-- in classifica, nei titoli e — dalla 0035 — nelle menzioni e nella foto di
-- gruppo.
create or replace function in_partita(p_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
	select coalesce((select not nascosto from users where id = p_id), false);
$$;

comment on function in_partita(uuid) is
	'Conta come giocatore: sta in classifica, si menziona, riceve Croquembouche.';

-- Agisce chi e' in partita e non e' un account di sola lettura.
create or replace function puo_agire(p_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
	select coalesce((select not nascosto and not sola_lettura from users where id = p_id), false);
$$;

comment on function puo_agire(uuid) is
	'E'' in partita e puo'' anche scrivere: cattura, vota, contesta, scambia.';

-- --- il cancello di tutte le scritture --------------------------------------
-- chi_agisce() sta davanti a cattura, scambio, contestazione, voto della
-- contestazione e voto dei premi: aggiungerci il controllo qui li copre tutti
-- insieme, senza toccarne uno per uno.
create or replace function chi_agisce() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare v_id uuid; v_ferma boolean; v_fuori boolean;
begin
	v_id := auth.uid();
	if v_id is null then
		raise exception 'Devi entrare per fare questo';
	end if;
	select sola_lettura, nascosto into v_ferma, v_fuori from users where id = v_id;
	if v_ferma is null then
		raise exception 'Questo account non e'' un giocatore';
	end if;
	if v_fuori then
		raise exception 'Questo account guarda la partita da fuori';
	end if;
	if v_ferma then
		raise exception 'Questo account puo'' solo guardare';
	end if;
	return v_id;
end;
$$;

-- I like sono l'unica scrittura che il client fa da solo: la policy chiede a
-- questa funzione, quindi anche i cuoricini seguono la stessa regola.
create or replace function posso_scrivere() returns boolean
language sql stable security definer set search_path = public as $$
	select puo_agire(auth.uid());
$$;

-- --- la maggioranza la fanno quelli che possono votare ----------------------
-- La 0029 aveva gia' tolto dal conto gli account di sola lettura. Restava
-- dentro Admin, che non e' di sola lettura ma non vota: con due giocatori e
-- due account di servizio servivano due voti su tre invece di uno su uno.
create or replace function risolvi_contestazione(p_contest uuid)
returns text language plpgsql set search_path to 'public' as $function$
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

	-- Vota chiunque sia in partita tranne l'autore della cattura.
	select count(*)::int into v_votanti
	from users where id <> v_autore and puo_agire(id);
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
$function$;

-- --- e nemmeno si ricevono ---------------------------------------------------
-- Finora si potevano passare Croquembouche ad Admin, o votarlo come "quello
-- che ha mangiato di piu'": sparivano dal gioco, perche' chi li riceve non e'
-- in classifica.
create or replace function invia_croquembouche(
	p_to uuid, p_importo integer, p_causale text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_da uuid;
begin
	v_da := chi_agisce();
	if not in_partita(p_to) then
		raise exception 'Questo account non e'' in partita';
	end if;
	return invia_croquembouche_interna(v_da, p_to, p_importo, p_causale);
end;
$$;

create or replace function vota_premio(p_finale uuid, p_premio uuid, p_votato uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_chi uuid;
begin
	v_chi := chi_agisce();
	if not in_partita(p_votato) then
		raise exception 'Questo account non e'' in partita';
	end if;
	perform vota_premio_interna(p_finale, p_premio, v_chi, p_votato);
end;
$$;

-- --- il via ai premi ---------------------------------------------------------
-- La 0033 lo lasciava a qualunque giocatore vero, perche' durante la cerimonia
-- lo preme chi e' pronto. Ma il bottone nell'app lo vede solo chi amministra,
-- e adesso chi amministra non passa piu' da chi_agisce(): vanno bene tutti e
-- due, altrimenti quel bottone non lo puo' premere nessuno.
create or replace function comincia_premi(p_finale uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
	if auth.uid() is null then
		raise exception 'Devi entrare per fare questo';
	end if;
	if not (sono_admin() or puo_agire(auth.uid())) then
		raise exception 'Il via ai premi lo da'' un giocatore, o chi amministra';
	end if;
	perform comincia_premi_interna(p_finale);
end;
$$;

-- --- i set sono roba da giocatori -------------------------------------------
-- La vista incrociava i set con tutte le righe di users: Admin e Spione
-- comparivano a zero requisiti su nove, come due giocatori fermi al palo.
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
join totali t on t.set_id = s.id
join users u on in_partita(u.id)
left join nel_giorno_migliore g on g.set_id = s.id and g.user_id = u.id
left join in_tutto a on a.set_id = s.id and a.user_id = u.id
where s.attivo;
