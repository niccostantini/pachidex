-- ============================================================================
-- Pachino Express — schema
-- ============================================================================

create extension if not exists "pgcrypto";

-- --- giocatori --------------------------------------------------------------
create table users (
	id uuid primary key default gen_random_uuid(),
	nome text not null unique,
	avatar text,                       -- url dello sprite pixel su Storage
	colore text not null default '#4A5578',  -- ripiego a iniziali quando manca lo sprite
	is_admin boolean not null default false,
	created_at timestamptz not null default now()
);

-- --- elementi del PachiDex ("sfiziosita'") ----------------------------------
create table items (
	id uuid primary key default gen_random_uuid(),
	nome text not null,
	categoria text not null check (categoria in ('posto', 'pietanza', 'animale', 'attivita')),
	rarita text not null check (rarita in ('comune', 'raro', 'leggendario')),
	croquembouche int not null check (croquembouche >= 0),
	ripetibile boolean not null default false,
	validazione text not null check (validazione in ('auto_gps', 'foto')),
	note text,
	lat double precision,
	lng double precision,
	attivo boolean not null default true,
	created_at timestamptz not null default now(),

	-- Il GPS vale solo per i posti, e un posto senza coordinate non e' catturabile.
	constraint gps_solo_per_posti check (validazione <> 'auto_gps' or categoria = 'posto'),
	constraint posto_gps_ha_coordinate check (
		validazione <> 'auto_gps' or (lat is not null and lng is not null)
	)
);

create index items_attivi_idx on items (attivo, categoria);
-- Stesso nome ammesso in categorie diverse (il tonno e' animale e pietanza).
create unique index items_nome_unico_idx on items (lower(nome), categoria);

-- --- catture ----------------------------------------------------------------
create table captures (
	id uuid primary key default gen_random_uuid(),
	user_id uuid not null references users (id) on delete cascade,
	item_id uuid not null references items (id) on delete cascade,
	foto_url text not null,
	nota text,                         -- didascalia libera, stile post
	lat double precision,              -- dove e' avvenuta la cattura
	lng double precision,
	timestamp timestamptz not null default now(),
	stato text not null default 'valido'
		check (stato in ('valido', 'in_contestazione', 'invalidato'))
);

create index captures_feed_idx on captures (timestamp desc);
create index captures_user_idx on captures (user_id);
create index captures_item_idx on captures (item_id, timestamp);

-- Un item non ripetibile si cattura una volta sola per giocatore. Serve un
-- trigger e non un indice parziale, perche' la condizione vive su items.
create or replace function blocca_doppioni() returns trigger as $$
begin
	if exists (
		select 1 from items i
		where i.id = new.item_id and i.ripetibile = false
	) and exists (
		select 1 from captures c
		where c.user_id = new.user_id
		  and c.item_id = new.item_id
		  and c.stato <> 'invalidato'
		  and c.id <> new.id
	) then
		raise exception 'Questo elemento non e'' ripetibile e l''hai gia'' catturato'
			using errcode = 'unique_violation';
	end if;
	return new;
end;
$$ language plpgsql;

create trigger captures_no_doppioni
	before insert or update of item_id, user_id on captures
	for each row execute function blocca_doppioni();

-- --- reazioni ---------------------------------------------------------------
create table reactions (
	id uuid primary key default gen_random_uuid(),
	capture_id uuid not null references captures (id) on delete cascade,
	user_id uuid not null references users (id) on delete cascade,
	created_at timestamptz not null default now(),
	unique (capture_id, user_id)
);

create index reactions_capture_idx on reactions (capture_id);
create index reactions_user_idx on reactions (user_id);

-- --- contestazioni ----------------------------------------------------------
create table contests (
	id uuid primary key default gen_random_uuid(),
	capture_id uuid not null references captures (id) on delete cascade,
	contestante_id uuid not null references users (id) on delete cascade,
	stato text not null default 'aperta'
		check (stato in ('aperta', 'chiusa_valido', 'chiusa_non_valido', 'scaduta')),
	-- Costo e penalita' congelati all'apertura: se l'admin ritocca la config
	-- a meta' vacanza, le contestazioni gia' aperte restano alle vecchie regole.
	costo_pagato int not null,
	penalita int not null,
	motivo text,
	scadenza timestamptz not null,
	risolta_at timestamptz,
	created_at timestamptz not null default now()
);

-- Una sola contestazione aperta per cattura.
create unique index contests_una_aperta_idx on contests (capture_id) where stato = 'aperta';
create index contests_stato_idx on contests (stato, scadenza);
-- L'indice parziale qui sopra copre solo le aperte: per i join sull'archivio
-- e per le cascate serve comunque l'indice pieno.
create index contests_capture_idx on contests (capture_id);
create index contests_contestante_idx on contests (contestante_id);

-- --- voti -------------------------------------------------------------------
create table votes (
	id uuid primary key default gen_random_uuid(),
	contest_id uuid not null references contests (id) on delete cascade,
	user_id uuid not null references users (id) on delete cascade,
	voto text not null check (voto in ('valido', 'non_valido')),
	created_at timestamptz not null default now(),
	unique (contest_id, user_id)
);

-- Il vincolo unique indicizza gia' contest_id; user_id serve per le cascate.
create index votes_user_idx on votes (user_id);

-- --- trasferimenti di Croquembouche ----------------------------------------
create table transfers (
	id uuid primary key default gen_random_uuid(),
	from_user_id uuid not null references users (id) on delete cascade,
	to_user_id uuid not null references users (id) on delete cascade,
	importo int not null check (importo > 0),
	causale text,
	annullato boolean not null default false,   -- l'admin puo' revocare uno scambio
	created_at timestamptz not null default now(),
	constraint niente_autoscambio check (from_user_id <> to_user_id)
);

create index transfers_feed_idx on transfers (created_at desc);
-- v_saldi raggruppa su entrambi i lati dello scambio.
create index transfers_from_idx on transfers (from_user_id);
create index transfers_to_idx on transfers (to_user_id);

-- --- configurazione ---------------------------------------------------------
create table game_config (
	chiave text primary key,
	valore int not null,
	descrizione text
);
