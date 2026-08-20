-- ============================================================================
-- Pachino Express — le foto delle catture si spostano su R2
--
-- Il bucket 'catture' su Supabase Storage non serve piu': gli upload passano
-- da un URL firmato verso R2 (vedi src/routes/api/upload-url), perche' un
-- bucket personale costa meno e non consuma la quota Storage del piano free
-- di Supabase. Il bucket 'avatar' resta qui: sono pochi sprite piccoli
-- caricati solo dall'admin, non vale la complessita' di spostarli.
--
-- Supabase blocca la DELETE diretta sulle tabelle di storage via trigger
-- (storage.protect_delete): il bucket 'catture' vuoto va rimosso a mano
-- dalla dashboard (Storage > catture > elimina bucket), non da SQL. Qui si
-- stringe solo cio' che conta davvero: le policy, cosi' la anon key non
-- puo' piu' scriverci nemmeno se il bucket restasse li' dimenticato.
-- ============================================================================

drop policy if exists "lettura pubblica immagini" on storage.objects;
drop policy if exists "caricamento immagini" on storage.objects;
drop policy if exists "sostituzione immagini" on storage.objects;
drop policy if exists "rimozione immagini" on storage.objects;

create policy "lettura pubblica immagini" on storage.objects
	for select to anon, authenticated
	using (bucket_id = 'avatar');

create policy "caricamento immagini" on storage.objects
	for insert to anon, authenticated
	with check (bucket_id = 'avatar');

create policy "sostituzione immagini" on storage.objects
	for update to anon, authenticated
	using (bucket_id = 'avatar');

create policy "rimozione immagini" on storage.objects
	for delete to anon, authenticated
	using (bucket_id = 'avatar');
