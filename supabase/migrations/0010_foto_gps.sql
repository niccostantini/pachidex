-- ============================================================================
-- Pachino Express — i posti si validano con foto E GPS, e sono contestabili
--
-- Il nome `auto_gps` raccontava una cosa falsa: sembrava dire "basta il GPS,
-- niente foto", mentre la foto e' sempre stata obbligatoria (foto_url e' NOT
-- NULL e l'interfaccia non lascia pubblicare senza scatto). Diventa
-- `foto_gps`, che dice quello che succede davvero.
--
-- Cambia anche una regola di gioco: finora una cattura su checkpoint era
-- inattaccabile perche' il GPS "dimostrava" la presenza. Ma se la foto fa
-- parte della validazione, allora anche un posto puo' essere contestato —
-- essere sul posto e fotografarsi il pollice non e' catturare Vendicari.
-- ============================================================================

-- --- 1. il nuovo nome -------------------------------------------------------
-- I vincoli vanno tolti prima: impediscono la riscrittura dei valori.
alter table items drop constraint if exists items_validazione_check;
alter table items drop constraint if exists gps_solo_per_posti;
alter table items drop constraint if exists posto_gps_ha_coordinate;

update items set validazione = 'foto_gps' where validazione = 'auto_gps';

alter table items
	add constraint items_validazione_check
	check (validazione in ('foto_gps', 'foto'));

alter table items
	add constraint gps_solo_per_posti
	check (validazione <> 'foto_gps' or categoria = 'posto');

alter table items
	add constraint posto_gps_ha_coordinate
	check (validazione <> 'foto_gps' or (lat is not null and lng is not null));

-- --- 2. la cattura conosce il nuovo nome ------------------------------------
create or replace function registra_cattura(
	p_user uuid,
	p_item uuid,
	p_foto text,
	p_nota text default null,
	p_lat double precision default null,
	p_lng double precision default null
) returns uuid
language plpgsql
set search_path = public
as $$
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

	if v_item.validazione = 'foto_gps' then
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
$$;

-- --- 3. anche i posti si contestano -----------------------------------------
create or replace function apri_contestazione(
	p_capture uuid, p_contestante uuid, p_motivo text default null
) returns uuid
language plpgsql
set search_path = public
as $$
declare
	v_id uuid;
	v_autore uuid;
	v_stato text;
	v_costo int;
	v_pen int;
	v_ore int;
begin
	select c.user_id, c.stato
	into v_autore, v_stato
	from captures c
	where c.id = p_capture;

	if v_autore is null then
		raise exception 'Questa cattura non esiste';
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
$$;
