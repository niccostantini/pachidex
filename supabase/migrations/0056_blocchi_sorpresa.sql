-- ============================================================================
-- Pachino Express — i blocchi «?» per le strade di Roma
--
-- Come in Pokemon Go: su piazze, parchi e monumenti compaiono dei blocchi. Il
-- primo che ci arriva lo apre e tira un d20. Il colore dice quanto c'e' in
-- gioco, non se e' un premio o una trappola: col premio, se il tiro batte la
-- CD si incassa; con la trappola, se non la batte si perde la posta.
--
-- --- TRE SCELTE CHE REGGONO TUTTO IL RESTO ---------------------------------
--
-- 1. Nessuna tabella degli spawn e nessun cron. Il tempo e' diviso in fasce
--    (un giorno di default) e la mappa in celle da circa 250 m. In ogni fascia
--    una cella e' accesa o spenta secondo un hash di (segreto, cella, fascia),
--    e dallo stesso hash escono il luogo, la posta e il segno. E' un calcolo,
--    non uno stato: niente da riempire, niente da ripulire, e la densita' si
--    regola con un numero solo in game_config.
--
-- 2. Lo spawn e' per cella, non per luogo. Il centro ha dieci monumenti ogni
--    cento metri, la periferia uno ogni chilometro: contando i luoghi, i
--    blocchi finirebbero tutti fra il Pantheon e piazza Navona. Contando le
--    celle, ogni quartiere ha la stessa probabilita' di vederne uno.
--
-- 3. Il segreto sta in una tabella che il client non puo' leggere. Senza,
--    chiunque potrebbe rifare l'hash sul telefono e sapere dove sara' il
--    prossimo blocco — e se e' una trappola.
-- ============================================================================

-- --- i luoghi dove un blocco puo' comparire ---------------------------------
-- Li porta scripts/importa-luoghi.mjs da OpenStreetMap, gia' filtrati: solo
-- posti pubblici e pedonali.
create table if not exists luoghi (
	/** L'id di OpenStreetMap, "n123" o "w456": rilanciare l'import aggiorna invece di duplicare. */
	id text primary key,
	nome text not null,
	lat double precision not null,
	lng double precision not null,
	tipo text not null,
	attivo boolean not null default true,
	-- Circa 250 m per lato a Roma. Due colonne intere e non un testo: una
	-- concatenazione non e' immutabile, e una colonna generata deve esserlo.
	cella_lat int generated always as (floor(lat / 0.00225)::int) stored,
	cella_lng int generated always as (floor(lng / 0.003)::int) stored,
	created_at timestamptz not null default now()
);

create index if not exists luoghi_posizione on luoghi (lat, lng);
create index if not exists luoghi_cella on luoghi (cella_lat, cella_lng);

-- --- quanto c'e' in gioco ---------------------------------------------------
-- Una tabella come presenze_scala: si ritocca dal pannello senza migration.
create table if not exists blocchi_poste (
	posta text primary key check (posta in ('piccola', 'media', 'grossa', 'enorme')),
	croquembouche int not null check (croquembouche > 0),
	cd int not null check (cd between 1 and 20),
	/** Quanto spesso esce, rispetto alle altre. */
	peso int not null check (peso >= 0)
);

insert into blocchi_poste (posta, croquembouche, cd, peso)
values ('piccola', 10, 6, 50), ('media', 25, 10, 30), ('grossa', 50, 14, 15), ('enorme', 100, 18, 5)
on conflict (posta) do nothing;

insert into game_config (chiave, valore, descrizione)
values
	('blocchi_attivi', 1, 'Blocchi «?» sulla mappa: 1 accesi, 0 spenti'),
	('blocchi_percento_celle', 12, 'Su 100 celle da 250 m con almeno un luogo, quante hanno un blocco in ogni fascia'),
	('blocchi_trappole_percento', 35, 'Su 100 blocchi, quanti sono trappole'),
	('blocchi_durata_minuti', 1440, 'Quanto dura una fascia: allo scadere i blocchi cambiano posto. 1440 = un giorno')
on conflict (chiave) do nothing;

-- --- il segreto -------------------------------------------------------------
-- Una riga sola. RLS accesa e nessuna policy: la leggono solo le funzioni qui
-- sotto, che girano come proprietario.
create table if not exists blocchi_segreto (
	id boolean primary key default true check (id),
	segreto text not null default gen_random_uuid()::text
);
insert into blocchi_segreto default values on conflict (id) do nothing;
alter table blocchi_segreto enable row level security;
revoke all on table blocchi_segreto from anon, authenticated;

-- --- i blocchi aperti -------------------------------------------------------
-- Il premio si SCRIVE, come per le presenze: se domani la CD della posta
-- grossa scende a 12, chi ha perso ieri con un 13 ha perso lo stesso.
-- La chiave (cella, fascia) e' il "primo che arriva": due giocatori che
-- aprono lo stesso blocco nello stesso istante, uno solo entra.
create table if not exists blocchi_aperti (
	cella_lat int not null,
	cella_lng int not null,
	fascia bigint not null,
	-- Niente chiave esterna: se il luogo sparisce dall'import, i Croquembouche
	-- vinti li' non devono sparire con lui. Il nome si copia per lo stesso motivo.
	luogo_id text not null,
	luogo_nome text not null,
	user_id uuid not null references users(id) on delete cascade,
	posta text not null,
	trappola boolean not null,
	cd int not null,
	tiro int not null check (tiro between 1 and 20),
	/** Con il segno: positivo se ha vinto il premio, negativo se e' caduto nella trappola. */
	croquembouche int not null,
	created_at timestamptz not null default now(),
	primary key (cella_lat, cella_lng, fascia)
);

create index if not exists blocchi_aperti_utente on blocchi_aperti (user_id, created_at desc);

-- --- chi dice che un posto non va -------------------------------------------
-- OpenStreetMap non sa che quella piazzetta la sera e' un posto brutto. Chi ci
-- passa si': due segnalazioni e il luogo esce dal gioco, l'admin lo rimette.
create table if not exists luoghi_segnalazioni (
	luogo_id text not null references luoghi(id) on delete cascade,
	user_id uuid not null references users(id) on delete cascade,
	created_at timestamptz not null default now(),
	primary key (luogo_id, user_id)
);

insert into game_config (chiave, valore, descrizione)
values ('luoghi_segnalazioni_soglia', 2, 'Quante segnalazioni tolgono un luogo dai blocchi')
on conflict (chiave) do nothing;

-- --- permessi ---------------------------------------------------------------
alter table luoghi enable row level security;
alter table blocchi_poste enable row level security;
alter table blocchi_aperti enable row level security;
alter table luoghi_segnalazioni enable row level security;

drop policy if exists lettura_luoghi on luoghi;
create policy lettura_luoghi on luoghi for select to authenticated using (true);
drop policy if exists admin_luoghi on luoghi;
create policy admin_luoghi on luoghi
	for all to authenticated using (sono_admin()) with check (sono_admin());

drop policy if exists lettura_blocchi_poste on blocchi_poste;
create policy lettura_blocchi_poste on blocchi_poste for select to authenticated using (true);
drop policy if exists admin_blocchi_poste on blocchi_poste;
create policy admin_blocchi_poste on blocchi_poste
	for all to authenticated using (sono_admin()) with check (sono_admin());

-- Si scrive solo da apri_blocco: letto si', ma il segno di un blocco gia'
-- aperto non rivela piu' niente.
drop policy if exists lettura_blocchi_aperti on blocchi_aperti;
create policy lettura_blocchi_aperti on blocchi_aperti for select to authenticated using (true);
drop policy if exists admin_blocchi_aperti on blocchi_aperti;
create policy admin_blocchi_aperti on blocchi_aperti
	for all to authenticated using (sono_admin()) with check (sono_admin());

drop policy if exists admin_luoghi_segnalazioni on luoghi_segnalazioni;
create policy admin_luoghi_segnalazioni on luoghi_segnalazioni
	for all to authenticated using (sono_admin()) with check (sono_admin());

-- --- il dado ----------------------------------------------------------------
-- Un testo diventa un numero in [0, 1). hashtext non e' crittografico, ma non
-- serve che lo sia: quello che tiene il segreto e' il segreto.
create or replace function blocchi_dado(p_testo text) returns double precision
language sql immutable set search_path = public as $$
	select (hashtext(p_testo)::bigint + 2147483648) / 4294967296.0;
$$;

revoke all on function blocchi_dado(text) from public, anon, authenticated;

-- --- quali blocchi ci sono adesso in un riquadro ----------------------------
-- Con il segno dentro: per questo NON e' concessa ai giocatori. Da fuori si
-- passa da blocchi_vicini, che il segno lo lascia qui.
create or replace function blocchi_in(p_sud double precision, p_ovest double precision,
                                      p_nord double precision, p_est double precision)
returns table (luogo_id text, nome text, lat double precision, lng double precision,
               cella_lat int, cella_lng int, fascia bigint, posta text, trappola boolean,
               scade_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare
	v_segreto text;
	v_durata int;
	v_celle double precision;
	v_trappole double precision;
	v_fascia bigint;
	v_ora int;
begin
	if coalesce((select c.valore from game_config c where c.chiave = 'blocchi_attivi'), 0) = 0 then
		return;
	end if;

	select s.segreto into v_segreto from blocchi_segreto s;
	v_durata := greatest(coalesce((select c.valore from game_config c where c.chiave = 'blocchi_durata_minuti'), 1440), 5);
	v_celle := coalesce((select c.valore from game_config c where c.chiave = 'blocchi_percento_celle'), 12) / 100.0;
	v_trappole := coalesce((select c.valore from game_config c where c.chiave = 'blocchi_trappole_percento'), 35) / 100.0;
	-- Le fasce si contano sull'orologio di Roma, non su UTC: con la durata di
	-- un giorno i blocchi cambiano a mezzanotte, non alle due di notte.
	v_fascia := floor(extract(epoch from (now() at time zone 'Europe/Rome')) / (v_durata * 60))::bigint;
	v_ora := extract(hour from now() at time zone 'Europe/Rome')::int;

	return query
	with celle as (
		-- Le celle toccate dal riquadro, poi TUTTI i loro luoghi: se il bordo
		-- tagliasse una cella a meta', il luogo scelto dipenderebbe da come
		-- e' inquadrata la mappa, e aprire non troverebbe cio' che si vede.
		select distinct l.cella_lat, l.cella_lng
		from luoghi l
		where l.lat between p_sud and p_nord and l.lng between p_ovest and p_est
	),
	candidati as (
		select l.*,
		       format('%s:%s:%s:%s', v_segreto, l.cella_lat, l.cella_lng, v_fascia) as chiave
		from luoghi l
		join celle c on c.cella_lat = l.cella_lat and c.cella_lng = l.cella_lng
		where l.attivo
		  -- I parchi di notte sono chiusi o bui.
		  and (l.tipo <> 'parco' or v_ora between 8 and 19)
	),
	accese as (
		select distinct on (c.cella_lat, c.cella_lng) c.*
		from candidati c
		where blocchi_dado(c.chiave || ':cella') < v_celle
		order by c.cella_lat, c.cella_lng, blocchi_dado(c.chiave || ':' || c.id)
	),
	poste as (
		select p.posta,
		       sum(p.peso) over (order by p.croquembouche) as fino,
		       sum(p.peso) over () as totale
		from blocchi_poste p
		where p.peso > 0
	)
	select a.id, a.nome, a.lat, a.lng, a.cella_lat, a.cella_lng, v_fascia, ps.posta,
	       blocchi_dado(a.chiave || ':segno') < v_trappole,
	       (to_timestamp((v_fascia + 1) * v_durata * 60) at time zone 'UTC') at time zone 'Europe/Rome'
	from accese a
	cross join lateral (
		select p.posta from poste p
		where p.fino > blocchi_dado(a.chiave || ':posta') * p.totale
		order by p.fino
		limit 1
	) ps
	where not exists (
		select 1 from blocchi_aperti b
		where b.cella_lat = a.cella_lat and b.cella_lng = a.cella_lng and b.fascia = v_fascia
	)
	and a.lat between p_sud and p_nord and a.lng between p_ovest and p_est;
end;
$$;

revoke all on function blocchi_in(double precision, double precision, double precision, double precision)
	from public, anon, authenticated;

-- --- quello che vede la mappa -----------------------------------------------
-- Il riquadro ha un tetto (circa 10 km per lato): a zoom di citta' intera
-- sarebbero migliaia di pin, e la mappa li chiede solo da vicino.
create or replace function blocchi_vicini(p_sud double precision, p_ovest double precision,
                                          p_nord double precision, p_est double precision)
returns table (luogo_id text, nome text, lat double precision, lng double precision,
               posta text, croquembouche int, cd int, scade_at timestamptz)
language sql stable security definer set search_path = public as $$
	select b.luogo_id, b.nome, b.lat, b.lng, b.posta, p.croquembouche, p.cd, b.scade_at
	from blocchi_in(p_sud, p_ovest, p_nord, p_est) b
	join blocchi_poste p on p.posta = b.posta
	where auth.uid() is not null
	  and p_nord - p_sud <= 0.1 and p_est - p_ovest <= 0.13;
$$;

revoke all on function blocchi_vicini(double precision, double precision, double precision, double precision)
	from public, anon;
grant execute on function blocchi_vicini(double precision, double precision, double precision, double precision)
	to authenticated;

-- --- aprire un blocco -------------------------------------------------------
-- Il tiro si fa qui e non sul telefono: il telefono anima il dado con il
-- numero che gli torna indietro. Aprire obbliga a tirare: la posta si vede
-- prima, e avvicinarsi e' gia' la scelta.
drop function if exists apri_blocco(text, double precision, double precision);
create or replace function apri_blocco(p_luogo text, p_lat double precision, p_lng double precision)
returns table (tiro int, cd int, posta text, trappola boolean, riuscito boolean, croquembouche int)
language plpgsql volatile security definer set search_path = public as $$
declare
	v_id uuid;
	v_luogo luoghi;
	v_blocco record;
	v_posta blocchi_poste;
	v_raggio int;
	v_dist double precision;
	v_tiro int;
	v_riuscito boolean;
	v_croq int;
begin
	v_id := auth.uid();
	if v_id is null or not puo_agire(v_id) then
		raise exception 'Solo chi gioca puo'' aprire un blocco';
	end if;
	if gioco_congelato() then
		raise exception 'Durante la premiazione i blocchi restano chiusi';
	end if;

	select * into v_luogo from luoghi l where l.id = p_luogo;
	if v_luogo.id is null then
		raise exception 'Questo luogo non esiste';
	end if;

	select valore into v_raggio from game_config where chiave = 'raggio_gps_metri';
	v_dist := metri_tra(p_lat, p_lng, v_luogo.lat, v_luogo.lng);
	if v_dist > coalesce(v_raggio, 100) then
		raise exception 'Sei a % metri dal blocco: troppo lontano', round(v_dist);
	end if;

	select * into v_blocco
	from blocchi_in(v_luogo.lat - 0.0001, v_luogo.lng - 0.0001, v_luogo.lat + 0.0001, v_luogo.lng + 0.0001) b
	where b.luogo_id = p_luogo;
	if v_blocco.luogo_id is null then
		raise exception 'Il blocco non c''e'' piu'': aperto da qualcun altro o scaduto';
	end if;

	select * into v_posta from blocchi_poste p where p.posta = v_blocco.posta;

	v_tiro := 1 + floor(random() * 20)::int;
	v_riuscito := v_tiro >= v_posta.cd;
	v_croq := case
		when not v_blocco.trappola and v_riuscito then v_posta.croquembouche
		when v_blocco.trappola and not v_riuscito then -v_posta.croquembouche
		else 0
	end;

	insert into blocchi_aperti (cella_lat, cella_lng, fascia, luogo_id, luogo_nome, user_id,
	                            posta, trappola, cd, tiro, croquembouche)
	values (v_blocco.cella_lat, v_blocco.cella_lng, v_blocco.fascia, v_luogo.id, v_luogo.nome, v_id,
	        v_posta.posta, v_blocco.trappola, v_posta.cd, v_tiro, v_croq)
	on conflict do nothing;
	if not found then
		raise exception 'Qualcuno e'' arrivato prima di te';
	end if;

	return query select v_tiro, v_posta.cd, v_posta.posta, v_blocco.trappola, v_riuscito, v_croq;
end;
$$;

revoke all on function apri_blocco(text, double precision, double precision) from public, anon;
grant execute on function apri_blocco(text, double precision, double precision) to authenticated;

-- --- segnalare un posto -----------------------------------------------------
create or replace function segnala_luogo(p_luogo text)
returns void language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_quante int;
begin
	v_id := auth.uid();
	if v_id is null or not puo_agire(v_id) then
		raise exception 'Solo chi gioca puo'' segnalare un luogo';
	end if;

	insert into luoghi_segnalazioni (luogo_id, user_id) values (p_luogo, v_id)
	on conflict do nothing;

	select count(*) into v_quante from luoghi_segnalazioni s where s.luogo_id = p_luogo;
	if v_quante >= coalesce((select c.valore from game_config c where c.chiave = 'luoghi_segnalazioni_soglia'), 2) then
		update luoghi set attivo = false where id = p_luogo;
	end if;
end;
$$;

revoke all on function segnala_luogo(text) from public, anon;
grant execute on function segnala_luogo(text) to authenticated;

-- --- i blocchi entrano nel conto --------------------------------------------
-- Come le presenze: pesano sul portacroque e sulla classifica, nel bene e nel
-- male. Una trappola non e' una penalita' da contestazione, e' un tiro andato
-- storto, quindi sta fra gli acquisiti con il segno meno.
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
select b.user_id, (b.created_at at time zone 'Europe/Rome')::date, 'blocco', b.croquembouche
from blocchi_aperti b where b.croquembouche <> 0
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

create or replace function conto_stagione(p_da date, p_a date)
returns table (user_id uuid, acquisiti int, penalita int, spesi int, scambi int)
language sql stable security definer set search_path = public as $$
	with mov as (
		select m.user_id,
		       coalesce(sum(m.importo) filter (
		           where m.tipo in ('cattura','presenza','blocco','contestazione_vinta','premio')), 0)::int as acquisiti,
		       coalesce(-sum(m.importo) filter (where m.tipo = 'penalita'), 0)::int as penalita,
		       coalesce(-sum(m.importo) filter (where m.tipo = 'spesa'), 0)::int as spesi,
		       coalesce(sum(m.importo) filter (where m.tipo = 'scambio'), 0)::int as scambi
		from v_movimenti m
		where m.giorno >= p_da and m.giorno < p_a
		group by m.user_id
	),
	set_premi as (
		select p.user_id, sum(p.importo)::int as croq
		from v_premi_set_datati p
		where p.giorno >= p_da and p.giorno < p_a
		group by p.user_id
	)
	select
		u.id,
		coalesce(mov.acquisiti, 0) + coalesce(sp.croq, 0),
		coalesce(mov.penalita, 0),
		coalesce(mov.spesi, 0),
		coalesce(mov.scambi, 0)
	from users u
	left join mov on mov.user_id = u.id
	left join set_premi sp on sp.user_id = u.id;
$$;

-- --- ricominciando da capo se ne vanno anche i blocchi aperti ---------------
-- I luoghi no: sono la mappa, come le formule sono arredamento.
create or replace function azzera_gioco_interna()
returns table (tabella text, cancellate int)
language plpgsql set search_path to 'public' as $function$
declare
	n_catture int; n_contestazioni int; n_voti int; n_reazioni int;
	n_scambi int; n_item int; n_presenze int; n_frasi int; n_blocchi int;
begin
	select count(*) into n_voti from votes;
	delete from votes where true;

	select count(*) into n_contestazioni from contests;
	delete from contests where true;

	select count(*) into n_reazioni from reactions;
	delete from reactions where true;

	select count(*) into n_catture from captures;
	delete from captures where true;

	select count(*) into n_scambi from transfers;
	delete from transfers where true;

	select count(*) into n_presenze from presenze;
	delete from presenze where true;

	select count(*) into n_frasi from oversharing;
	delete from oversharing where true;

	select count(*) into n_blocchi from blocchi_aperti;
	delete from blocchi_aperti where true;

	select count(*) into n_item from items;
	delete from items where true;

	return query
	select * from (
		values
			('sfiziosita', n_item),
			('catture', n_catture),
			('contestazioni', n_contestazioni),
			('voti', n_voti),
			('reazioni', n_reazioni),
			('scambi', n_scambi),
			('presenze', n_presenze),
			('oversharing', n_frasi),
			('blocchi', n_blocchi)
	) as t(tabella, cancellate);
end;
$function$;

revoke all on function azzera_gioco_interna() from public, anon, authenticated;

-- --- svuotando una stagione se ne vanno anche i blocchi aperti ---------------
-- Nel feed sono cronaca come gli scambi: senza il resto della stagione
-- parlano di niente. Il conto e' gia' congelato, quindi non si muove nulla.
create or replace function svuota_stagione(p_stagione int)
returns int language plpgsql security definer set search_path = public as $$
declare v_catture int; v_scambi int; v_frasi int; v_blocchi int;
begin
	perform esigi_svuotabile(p_stagione);

	delete from captures c
	using stagioni s
	where s.numero = p_stagione
	  and (c.timestamp at time zone 'Europe/Rome')::date >= s.inizio
	  and (c.timestamp at time zone 'Europe/Rome')::date < s.fine;
	get diagnostics v_catture = row_count;

	delete from transfers t
	using stagioni s
	where s.numero = p_stagione
	  and (t.created_at at time zone 'Europe/Rome')::date >= s.inizio
	  and (t.created_at at time zone 'Europe/Rome')::date < s.fine;
	get diagnostics v_scambi = row_count;

	delete from oversharing o
	using stagioni s
	where s.numero = p_stagione
	  and (o.created_at at time zone 'Europe/Rome')::date >= s.inizio
	  and (o.created_at at time zone 'Europe/Rome')::date < s.fine;
	get diagnostics v_frasi = row_count;

	delete from blocchi_aperti b
	using stagioni s
	where s.numero = p_stagione
	  and (b.created_at at time zone 'Europe/Rome')::date >= s.inizio
	  and (b.created_at at time zone 'Europe/Rome')::date < s.fine;
	get diagnostics v_blocchi = row_count;

	update stagioni set foto_cancellate_at = now() where numero = p_stagione;
	return v_catture + v_scambi + v_frasi + v_blocchi;
end;
$$;

revoke all on function svuota_stagione(int) from public, anon, authenticated;

drop view if exists v_da_svuotare;

create view v_da_svuotare
with (security_invoker = true)
as
select
	s.numero as stagione,
	s.chiusa_at,
	s.chiusa_at + interval '24 hours' as scade,
	(select count(*)::int from wrapped_visto w where w.stagione = s.numero) as visto_da,
	(select count(*)::int from users u where in_partita(u.id)) as giocatori,
	(
		(select count(*) from wrapped_visto w where w.stagione = s.numero)
			>= (select count(*) from users u where in_partita(u.id))
		or now() >= s.chiusa_at + interval '24 hours'
	) as pronta,
	(select count(*)::int
	 from captures c
	 where (c.timestamp at time zone 'Europe/Rome')::date >= s.inizio
	   and (c.timestamp at time zone 'Europe/Rome')::date < s.fine
	) + (select count(*)::int
	 from transfers t
	 where (t.created_at at time zone 'Europe/Rome')::date >= s.inizio
	   and (t.created_at at time zone 'Europe/Rome')::date < s.fine
	) + (select count(*)::int
	 from oversharing o
	 where (o.created_at at time zone 'Europe/Rome')::date >= s.inizio
	   and (o.created_at at time zone 'Europe/Rome')::date < s.fine
	) + (select count(*)::int
	 from blocchi_aperti b
	 where (b.created_at at time zone 'Europe/Rome')::date >= s.inizio
	   and (b.created_at at time zone 'Europe/Rome')::date < s.fine
	) as catture
from stagioni s
where s.chiusa_at is not null
  and s.foto_cancellate_at is null
  and s.numero > 0
order by s.numero;

-- --- il pannello rimette in gioco un luogo segnalato ------------------------
-- Una funzione e non due scritture dal client: riattivarlo senza cancellare
-- le segnalazioni lo farebbe ricadere alla prossima.
create or replace function rimetti_luogo(p_luogo text)
returns void language plpgsql security definer set search_path = public as $$
begin
	perform esigi_admin();
	delete from luoghi_segnalazioni where luogo_id = p_luogo;
	update luoghi set attivo = true where id = p_luogo;
end;
$$;

revoke all on function rimetti_luogo(text) from public, anon;
grant execute on function rimetti_luogo(text) to authenticated;

-- Per il pannello: i luoghi segnalati o spenti, con quante segnalazioni.
create or replace view v_luoghi_segnalati
with (security_invoker = true)
as
select l.id, l.nome, l.tipo, l.lat, l.lng, l.attivo,
       count(s.user_id)::int as segnalazioni,
       max(s.created_at) as ultima
from luoghi l
left join luoghi_segnalazioni s on s.luogo_id = l.id
group by l.id
having count(s.user_id) > 0 or not l.attivo;
