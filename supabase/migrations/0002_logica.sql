-- ============================================================================
-- Pachino Express — viste e regole di gioco
-- Le regole stanno qui e non nel client: il saldo si calcola sempre dagli
-- eventi, cosi' non puo' andare in drift come farebbe un contatore salvato.
-- ============================================================================

-- --- distanza in metri, senza PostGIS ---------------------------------------
create or replace function metri_tra(
	lat1 double precision, lng1 double precision,
	lat2 double precision, lng2 double precision
) returns double precision as $$
	select 2 * 6371000 * asin(sqrt(
		power(sin(radians(lat2 - lat1) / 2), 2) +
		cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)
	));
$$ language sql immutable;

-- --- saldo Croquembouche ----------------------------------------------------
create or replace view v_saldi as
with guadagni as (
	-- Una cattura sotto contestazione vale finche' non e' smentita: i punti
	-- non ballano ogni volta che qualcuno apre una votazione.
	select c.user_id, sum(i.croquembouche)::int as croq
	from captures c
	join items i on i.id = c.item_id
	where c.stato in ('valido', 'in_contestazione')
	group by c.user_id
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
		-- Il contestato paga quando la cattura viene invalidata.
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
	coalesce(g.croq, 0) as guadagnati,
	coalesce(c.croq, 0) as spesi_in_contestazioni,
	coalesce(p.croq, 0) as penalita,
	coalesce(s.croq, 0) as saldo_scambi,
	coalesce(g.croq, 0) - coalesce(c.croq, 0) - coalesce(p.croq, 0) + coalesce(s.croq, 0) as saldo
from users u
left join guadagni g on g.user_id = u.id
left join costi c on c.user_id = u.id
left join penalita p on p.user_id = u.id
left join scambi s on s.user_id = u.id;

-- --- classifica -------------------------------------------------------------
create or replace view v_classifica as
select
	s.user_id,
	s.nome,
	s.saldo,
	s.guadagnati,
	coalesce(d.unici, 0) as item_unici,
	coalesce(d.catture, 0) as catture_totali
from v_saldi s
left join (
	select user_id, count(distinct item_id)::int as unici, count(*)::int as catture
	from captures
	where stato in ('valido', 'in_contestazione')
	group by user_id
) d on d.user_id = s.user_id;

-- --- PachiDex ---------------------------------------------------------------
-- Una sola query per l'intera griglia: identica per tutti i giocatori (la
-- foto mostrata e' la prima del gruppo), quindi si puo' cachare senza pensieri.
create or replace view v_dex as
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

-- --- contestazioni ----------------------------------------------------------
create or replace function risolvi_contestazione(p_contest uuid) returns text as $$
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
	select count(*)::int into v_votanti from users where id <> v_autore;
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
$$ language plpgsql;

create or replace function apri_contestazione(
	p_capture uuid, p_contestante uuid, p_motivo text default null
) returns uuid as $$
declare
	v_id uuid;
	v_autore uuid;
	v_stato text;
	v_validazione text;
	v_costo int;
	v_pen int;
	v_ore int;
begin
	select c.user_id, c.stato, i.validazione
	into v_autore, v_stato, v_validazione
	from captures c
	join items i on i.id = c.item_id
	where c.id = p_capture;

	if v_autore is null then
		raise exception 'Questa cattura non esiste';
	end if;
	if v_validazione = 'auto_gps' then
		raise exception 'Le catture validate dal GPS non sono contestabili';
	end if;
	if v_autore = p_contestante then
		raise exception 'Non puoi contestare una cattura tua';
	end if;
	if v_stato <> 'valido' then
		raise exception 'Questa cattura non e'' contestabile adesso';
	end if;

	select valore into v_costo from game_config where chiave = 'costo_apertura_contestazione';
	select valore into v_pen from game_config where chiave = 'penalita_extra_contestazione';
	select valore into v_ore from game_config where chiave = 'durata_contestazione_ore';

	insert into contests (capture_id, contestante_id, costo_pagato, penalita, motivo, scadenza)
	values (
		p_capture, p_contestante,
		coalesce(v_costo, 1), coalesce(v_pen, 15), p_motivo,
		now() + make_interval(hours => coalesce(v_ore, 24))
	)
	returning id into v_id;

	update captures set stato = 'in_contestazione' where id = p_capture;

	-- Chi contesta ha gia' espresso la sua opinione.
	insert into votes (contest_id, user_id, voto) values (v_id, p_contestante, 'non_valido');

	perform risolvi_contestazione(v_id);
	return v_id;
end;
$$ language plpgsql;

create or replace function vota_contestazione(
	p_contest uuid, p_user uuid, p_voto text
) returns text as $$
declare
	v_autore uuid;
begin
	select cap.user_id into v_autore
	from contests co
	join captures cap on cap.id = co.capture_id
	where co.id = p_contest and co.stato = 'aperta';

	if v_autore is null then
		raise exception 'Questa contestazione non e'' piu'' aperta';
	end if;
	if v_autore = p_user then
		raise exception 'Chi e'' sotto contestazione non vota';
	end if;

	insert into votes (contest_id, user_id, voto)
	values (p_contest, p_user, p_voto)
	on conflict (contest_id, user_id) do update set voto = excluded.voto;

	return risolvi_contestazione(p_contest);
end;
$$ language plpgsql;

-- Chiamata da pg_cron se disponibile, e comunque dal client all'apertura del
-- feed: cosi' le scadenze funzionano anche senza cron.
create or replace function chiudi_contestazioni_scadute() returns int as $$
declare
	v_n int := 0;
	r record;
begin
	for r in select id from contests where stato = 'aperta' and now() >= scadenza loop
		perform risolvi_contestazione(r.id);
		v_n := v_n + 1;
	end loop;
	return v_n;
end;
$$ language plpgsql;

-- --- cattura ----------------------------------------------------------------
create or replace function registra_cattura(
	p_user uuid,
	p_item uuid,
	p_foto text,
	p_nota text default null,
	p_lat double precision default null,
	p_lng double precision default null
) returns uuid as $$
declare
	v_item items;
	v_raggio int;
	v_dist double precision;
	v_id uuid;
begin
	select * into v_item from items where id = p_item and attivo;
	if v_item.id is null then
		raise exception 'Questo elemento non e'' disponibile';
	end if;

	if v_item.validazione = 'auto_gps' then
		if p_lat is null or p_lng is null then
			raise exception 'Serve la posizione per validare questo checkpoint';
		end if;
		select valore into v_raggio from game_config where chiave = 'raggio_gps_metri';
		v_dist := metri_tra(p_lat, p_lng, v_item.lat, v_item.lng);
		if v_dist > coalesce(v_raggio, 100) then
			raise exception 'Sei a % metri dal checkpoint: troppo lontano', round(v_dist);
		end if;
	end if;

	insert into captures (user_id, item_id, foto_url, nota, lat, lng)
	values (p_user, p_item, p_foto, p_nota, p_lat, p_lng)
	returning id into v_id;

	return v_id;
end;
$$ language plpgsql;

-- --- scambi -----------------------------------------------------------------
create or replace function invia_croquembouche(
	p_from uuid, p_to uuid, p_importo int, p_causale text default null
) returns uuid as $$
declare
	v_saldo int;
	v_id uuid;
begin
	if p_importo <= 0 then
		raise exception 'L''importo dev''essere positivo';
	end if;
	if p_from = p_to then
		raise exception 'Non puoi mandare Croquembouche a te stesso';
	end if;

	select saldo into v_saldo from v_saldi where user_id = p_from;
	if coalesce(v_saldo, 0) < p_importo then
		raise exception 'Hai solo % Croquembouche', coalesce(v_saldo, 0);
	end if;

	insert into transfers (from_user_id, to_user_id, importo, causale)
	values (p_from, p_to, p_importo, p_causale)
	returning id into v_id;

	return v_id;
end;
$$ language plpgsql;
