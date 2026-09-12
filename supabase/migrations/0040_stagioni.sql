-- ============================================================================
-- Pachino Express — le stagioni
--
-- Ogni due settimane la classifica riparte da zero, ma i Croquembouche
-- restano. Si guadagnano una volta e si tengono per sempre; a ripartire e'
-- solo il punteggio della gara.
--
-- --- PERCHE' UNA TABELLA E NON UNA FORMULA ----------------------------------
-- La finestra si potrebbe calcolare — "giorni dall'inizio diviso quattordici"
-- — e per un po' e' quello che avevo in mente. Non regge, per un motivo che
-- viene dopo: a fine stagione le foto e le catture si cancellano. Nel momento
-- in cui sparisce l'evento, sparisce anche il credito che ne veniva, e un
-- portacroque ricalcolato da zero perderebbe i soldi che uno ha gia' speso.
--
-- Quindi alla chiusura il conto della stagione si SCRIVE — quanto hai
-- acquisito, quanto hai pagato, dove sei arrivato — e da li' in poi non si
-- ricalcola piu'. E' la stessa ragione per cui i premi delle presenze si
-- scrivono invece di rifarsi a ogni lettura: un fatto avvenuto in un giorno
-- preciso non si rinegozia.
--
-- Il portacroque diventa: somma delle stagioni chiuse, piu' quello che stai
-- acquisendo adesso, meno tutto quello che hai speso.
--
-- --- FINCHE' NON SI APRE LA PRIMA STAGIONE ----------------------------------
-- Senza nessuna stagione la finestra e' "da sempre a sempre": l'app si
-- comporta esattamente come prima, e la classifica e' quella di tutta la
-- storia. Cosi' questa migrazione si puo' applicare senza cambiare niente
-- fino al giorno in cui si decide di cominciare davvero.
-- ============================================================================

-- --- le stagioni ------------------------------------------------------------
create table if not exists stagioni (
	numero int primary key,
	/** Finestra [inizio, fine): il giorno di fine appartiene alla stagione dopo. */
	inizio date not null,
	fine date not null check (fine > inizio),
	/** null finche' e' in corso. Al massimo una stagione aperta per volta. */
	chiusa_at timestamptz,
	created_at timestamptz not null default now()
);

create unique index if not exists una_stagione_aperta
	on stagioni ((chiusa_at is null)) where chiusa_at is null;

-- --- il catalogo di stagione ------------------------------------------------
-- Un terzo delle sfiziosita', sorteggiato per categoria. Si scrive
-- all'apertura e per due settimane e' quello: sorteggiarlo a ogni lettura
-- vorrebbe dire due telefoni con due cataloghi diversi, e un elemento che
-- sparisce mentre uno ci sta andando.
create table if not exists stagione_items (
	stagione int not null references stagioni(numero) on delete cascade,
	item_id uuid not null references items(id) on delete cascade,
	primary key (stagione, item_id)
);

-- --- il conto congelato -----------------------------------------------------
create table if not exists stagione_saldi (
	stagione int not null references stagioni(numero) on delete cascade,
	user_id uuid not null references users(id) on delete cascade,
	/** Quello che e' entrato: catture, tag, set, contestazioni vinte, presenze. */
	acquisiti int not null default 0,
	/** Le penalita' pagate. Contano anche in classifica: contestare a vanvera deve costare. */
	penalita int not null default 0,
	/** Quello che e' uscito: costi delle contestazioni, e un giorno lo shop. */
	spesi int not null default 0,
	/** Saldo degli scambi: ricevuti meno dati. Non conta in classifica. */
	scambi int not null default 0,
	/** Il punteggio della gara: acquisiti meno penalita'. */
	punti int not null default 0,
	posizione int not null,
	primary key (stagione, user_id)
);

alter table stagioni enable row level security;
alter table stagione_items enable row level security;
alter table stagione_saldi enable row level security;

do $$
declare t text;
begin
	foreach t in array array['stagioni', 'stagione_items', 'stagione_saldi'] loop
		execute format('drop policy if exists %I on public.%I', 'lettura_' || t, t);
		execute format(
			'create policy %I on public.%I for select to authenticated using (true)', 'lettura_' || t, t);
		execute format('drop policy if exists %I on public.%I', 'admin_' || t, t);
		execute format(
			'create policy %I on public.%I for all to authenticated using (sono_admin()) with check (sono_admin())',
			'admin_' || t, t);
	end loop;
end $$;

-- --- la finestra di adesso --------------------------------------------------
/**
 * Da quando a quando conta cio' che si fa oggi.
 *
 * Senza stagioni aperte la finestra e' infinita in tutte e due le direzioni:
 * e' il comportamento di prima, e serve a non rompere niente finche' la
 * prima stagione non viene aperta davvero.
 */
create or replace function finestra_corrente()
returns table (numero int, da date, a date)
language sql stable security definer set search_path = public as $$
	select s.numero, s.inizio, s.fine from stagioni s where s.chiusa_at is null
	union all
	select null::int, '-infinity'::date, 'infinity'::date
	where not exists (select 1 from stagioni where chiusa_at is null)
$$;

/** Il numero della stagione in corso, null se non ce n'e' una. */
create or replace function stagione_corrente() returns int
language sql stable security definer set search_path = public as $$
	select numero from finestra_corrente();
$$;

-- --- cosa e' successo dentro la finestra ------------------------------------
-- Ogni fonte di Croquembouche porta la sua data, quindi la stagione non e'
-- altro che un filtro. Il giorno e' quello di Pachino, come nel resto del
-- gioco: una granita delle 23:30 e' di stasera.
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
select co.contestante_id, (co.risolta_at at time zone 'Europe/Rome')::date,
       'contestazione_vinta', co.costo_pagato * 2
from contests co where co.stato = 'chiusa_non_valido' and co.risolta_at is not null
union all
select e.vincitore_id, (e.assegnato_at at time zone 'Europe/Rome')::date,
       'premio', pr.croquembouche
from premi_esiti e join premi pr on pr.id = e.premio_id
where e.vincitore_id is not null
-- uscite: la penalita' e' un conto a parte perche' pesa anche in classifica
union all
select cap.user_id, (co.risolta_at at time zone 'Europe/Rome')::date,
       'penalita', -co.penalita
from contests co join captures cap on cap.id = co.capture_id
where co.stato = 'chiusa_non_valido' and co.risolta_at is not null
union all
select co.contestante_id, (co.risolta_at at time zone 'Europe/Rome')::date,
       'penalita', -co.penalita
from contests co where co.stato = 'chiusa_valido' and co.risolta_at is not null
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

-- I premi dei set non hanno una riga propria: si sa che un set e' chiuso, non
-- quando. Il giorno e' quello dell'ultimo requisito soddisfatto, ed e' li' che
-- il premio entra in stagione.
create or replace view v_premi_set_datati
with (security_invoker = true)
as
select st.user_id, max(so.giorno) as giorno, s.croquembouche as importo
from v_set_stato st
join game_sets s on s.id = st.set_id
join v_set_soddisfatti so on so.set_id = st.set_id and so.user_id = st.user_id
where st.completo
group by st.user_id, st.set_id, s.croquembouche;

-- --- il punteggio di questa stagione ----------------------------------------
create or replace view v_punti_stagione
with (security_invoker = true)
as
with f as (select * from finestra_corrente()),
mov as (
	select m.user_id,
	       sum(m.importo) filter (where m.tipo in ('cattura','presenza','contestazione_vinta','premio'))::int as acquisiti,
	       -sum(m.importo) filter (where m.tipo = 'penalita')::int as penalita
	from v_movimenti m, f
	where m.giorno >= f.da and m.giorno < f.a
	group by m.user_id
),
set_premi as (
	select p.user_id, sum(p.importo)::int as croq
	from v_premi_set_datati p, f
	where p.giorno >= f.da and p.giorno < f.a
	group by p.user_id
)
select
	u.id as user_id,
	u.nome,
	coalesce(mov.acquisiti, 0) + coalesce(sp.croq, 0) as acquisiti,
	coalesce(mov.penalita, 0) as penalita,
	coalesce(mov.acquisiti, 0) + coalesce(sp.croq, 0) - coalesce(mov.penalita, 0) as punti
from users u
left join mov on mov.user_id = u.id
left join set_premi sp on sp.user_id = u.id
where in_partita(u.id);

-- --- il portacroque ---------------------------------------------------------
-- Quello che hai davvero in tasca: le stagioni chiuse non si ricalcolano piu',
-- la stagione in corso si legge dai movimenti, le spese si tolgono sempre.
create or replace view v_saldi
with (security_invoker = true)
as
with f as (select * from finestra_corrente()),
chiuse as (
	select ss.user_id,
	       sum(ss.acquisiti)::int as acquisiti,
	       sum(ss.penalita)::int as penalita,
	       sum(ss.spesi)::int as spesi,
	       sum(ss.scambi)::int as scambi
	from stagione_saldi ss
	group by ss.user_id
),
adesso as (
	select m.user_id,
	       sum(m.importo) filter (where m.tipo in ('cattura','presenza','contestazione_vinta','premio'))::int as acquisiti,
	       -sum(m.importo) filter (where m.tipo = 'penalita')::int as penalita,
	       -sum(m.importo) filter (where m.tipo = 'spesa')::int as spesi,
	       sum(m.importo) filter (where m.tipo = 'scambio')::int as scambi
	from v_movimenti m, f
	where m.giorno >= f.da and m.giorno < f.a
	group by m.user_id
),
set_adesso as (
	select p.user_id, sum(p.importo)::int as croq
	from v_premi_set_datati p, f
	where p.giorno >= f.da and p.giorno < f.a
	group by p.user_id
)
select
	u.id as user_id,
	u.nome,
	coalesce(c.acquisiti, 0) + coalesce(a.acquisiti, 0) + coalesce(sa.croq, 0) as guadagnati,
	coalesce(c.spesi, 0) + coalesce(a.spesi, 0) as spesi_in_contestazioni,
	coalesce(c.penalita, 0) + coalesce(a.penalita, 0) as penalita,
	coalesce(c.scambi, 0) + coalesce(a.scambi, 0) as saldo_scambi,
	coalesce(c.acquisiti, 0) + coalesce(a.acquisiti, 0) + coalesce(sa.croq, 0)
		- coalesce(c.penalita, 0) - coalesce(a.penalita, 0)
		- coalesce(c.spesi, 0) - coalesce(a.spesi, 0)
		+ coalesce(c.scambi, 0) + coalesce(a.scambi, 0) as saldo
from users u
left join chiuse c on c.user_id = u.id
left join adesso a on a.user_id = u.id
left join set_adesso sa on sa.user_id = u.id;
