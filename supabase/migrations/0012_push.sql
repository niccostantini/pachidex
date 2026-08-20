-- ============================================================================
-- Pachino Express — iscrizioni alle notifiche push
-- Un'iscrizione e' per DISPOSITIVO, non per persona: lo stesso giocatore che
-- installa la PWA sul telefono e sul tablet ne ha due, ed e' giusto cosi'.
-- ============================================================================

create table push_subscriptions (
	id uuid primary key default gen_random_uuid(),
	user_id uuid not null references users (id) on delete cascade,
	endpoint text not null unique,
	p256dh text not null,
	auth text not null,
	creata timestamptz not null default now(),
	ultimo_errore text,
	scaduta boolean not null default false
);

create index push_subscriptions_user_idx on push_subscriptions (user_id);
create index push_subscriptions_vive_idx on push_subscriptions (user_id) where not scaduta;

alter table push_subscriptions enable row level security;
drop policy if exists accesso_libero_push_subscriptions on public.push_subscriptions;
create policy accesso_libero_push_subscriptions on public.push_subscriptions
	for all to anon, authenticated using (true) with check (true);

-- --- posizioni in classifica -------------------------------------------------
-- Per dire "ti ha superato" serve sapere com'era la classifica un attimo
-- prima: il saldo si calcola al volo dagli eventi, quindi il passato non
-- esiste da nessuna parte se non lo si annota.
create table classifica_posizioni (
	user_id uuid primary key references users (id) on delete cascade,
	posizione int not null,
	saldo int not null,
	aggiornata timestamptz not null default now()
);

alter table classifica_posizioni enable row level security;
drop policy if exists accesso_libero_classifica_posizioni on public.classifica_posizioni;
create policy accesso_libero_classifica_posizioni on public.classifica_posizioni
	for all to anon, authenticated using (true) with check (true);

-- Rilegge la classifica, la confronta con l'ultima annotata e restituisce solo
-- i sorpassi avvenuti da allora, aggiornando l'istantanea: cosi' ogni sorpasso
-- si racconta una volta sola.
create or replace function registra_sorpassi()
returns table (superato uuid, superante uuid)
language plpgsql
set search_path = public
as $$
begin
	-- Il drop esplicito serve se la funzione viene chiamata due volte nella
	-- stessa transazione: "on commit drop" pulisce solo alla fine.
	drop table if exists _nuova;
	create temporary table _nuova on commit drop as
	select
		user_id,
		saldo,
		row_number() over (order by saldo desc, nome asc)::int as posizione
	from v_classifica;

	return query
	select v.user_id as superato, n.user_id as superante
	from classifica_posizioni v
	join _nuova n on n.user_id <> v.user_id
	join classifica_posizioni v2 on v2.user_id = n.user_id
	join _nuova n2 on n2.user_id = v.user_id
	where v.posizione < v2.posizione   -- prima stava davanti
	  and n2.posizione > n.posizione;  -- adesso sta dietro

	delete from classifica_posizioni where true;
	insert into classifica_posizioni (user_id, posizione, saldo)
	select user_id, posizione, saldo from _nuova;
end;
$$;

-- Istantanea iniziale, cosi' il primo confronto non inventa sorpassi.
insert into classifica_posizioni (user_id, posizione, saldo)
select user_id, row_number() over (order by saldo desc, nome asc)::int, saldo
from v_classifica
on conflict (user_id) do nothing;
