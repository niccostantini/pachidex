-- ============================================================================
-- Pachino Express — RLS, Storage, Realtime
--
-- NOTA DI SICUREZZA, CONSAPEVOLE E ACCETTATA
-- L'app non ha autenticazione: il profilo si sceglie da una lista e basta.
-- Di conseguenza chiunque abbia la anon key puo' scrivere qualsiasi riga.
-- E' un gioco fra sei amici in vacanza, non un sistema con dei segreti:
-- il rischio e' proporzionato. Se un giorno servisse davvero, la strada e'
-- Supabase Auth con magic link e policy per auth.uid().
-- ============================================================================

alter table users enable row level security;
alter table items enable row level security;
alter table captures enable row level security;
alter table reactions enable row level security;
alter table contests enable row level security;
alter table votes enable row level security;
alter table transfers enable row level security;
alter table game_config enable row level security;

do $$
declare t text;
begin
	foreach t in array array[
		'users', 'items', 'captures', 'reactions', 'contests', 'votes', 'transfers', 'game_config'
	] loop
		-- Idempotente: la migration si puo' rieseguire senza schiantarsi.
		execute format('drop policy if exists %I on public.%I', 'accesso_libero_' || t, t);
		execute format(
			'create policy %I on public.%I for all to anon, authenticated using (true) with check (true)',
			'accesso_libero_' || t, t
		);
	end loop;
end;
$$;

-- --- Storage ----------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
	('catture', 'catture', true, 8388608, array['image/jpeg', 'image/webp', 'image/png']),
	('avatar', 'avatar', true, 262144, array['image/png', 'image/webp', 'image/gif'])
on conflict (id) do nothing;

drop policy if exists "lettura pubblica immagini" on storage.objects;
drop policy if exists "caricamento immagini" on storage.objects;
drop policy if exists "sostituzione immagini" on storage.objects;
drop policy if exists "rimozione immagini" on storage.objects;

create policy "lettura pubblica immagini" on storage.objects
	for select to anon, authenticated
	using (bucket_id in ('catture', 'avatar'));

create policy "caricamento immagini" on storage.objects
	for insert to anon, authenticated
	with check (bucket_id in ('catture', 'avatar'));

create policy "sostituzione immagini" on storage.objects
	for update to anon, authenticated
	using (bucket_id in ('catture', 'avatar'));

create policy "rimozione immagini" on storage.objects
	for delete to anon, authenticated
	using (bucket_id in ('catture', 'avatar'));

-- --- Realtime ---------------------------------------------------------------
-- Il feed e' una subscription, non un polling.
do $$
declare t text;
begin
	foreach t in array array['captures', 'contests', 'votes', 'reactions', 'transfers'] loop
		begin
			execute format('alter publication supabase_realtime add table public.%I', t);
		exception
			when duplicate_object then null;
		end;
	end loop;
end;
$$;
