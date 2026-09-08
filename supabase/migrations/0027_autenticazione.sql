-- ============================================================================
-- Pachino Express — autenticazione vera
--
-- Fino a qui non c'era: si sceglieva il proprio nome da una lista e il
-- telefono se lo ricordava. Fra sei amici in vacanza andava benissimo. Adesso
-- l'app resta in piedi come vetrina e come partita fra poche persone, quindi
-- serve sapere chi e' chi davvero.
--
-- Le password le gestisce Supabase Auth: bcrypt, salt per utente, token
-- firmati. Scriverla a mano sarebbe il modo piu' rapido di farla male.
--
-- L'accesso e' a NOME UTENTE, non a email. Auth vuole comunque un indirizzo,
-- quindi se ne usa uno tecnico costruito dal nome (nicco@pachidex.local) che
-- nessuno vede mai: la finzione vive tutta nel client.
--
-- --- IL MODELLO DEI PERMESSI -----------------------------------------------
-- Le vecchie policy si chiamavano "accesso_libero" e lasciavano passare
-- tutto. Le nuove partono dal principio opposto: dalle tabelle di gioco si
-- LEGGE e basta, e ogni scrittura passa dalle funzioni che gia' controllano
-- le regole. Cosi' non esiste una strada che scavalchi i controlli, e le
-- policy da mantenere sono poche.
--
-- Le funzioni prendono l'identita' da auth.uid() e non piu' da un parametro
-- mandato dal client: prima bastava dichiarare di essere qualcun altro.
-- ============================================================================

-- --- chi sei, e cosa puoi fare ----------------------------------------------
alter table users add column if not exists sola_lettura boolean not null default false;
alter table users add column if not exists nascosto boolean not null default false;

comment on column users.sola_lettura is
	'Account che guarda e basta: nessuna cattura, nessun like, nessuno scambio.';
comment on column users.nascosto is
	'Fuori da classifica, titoli e barra della storia: guarda la partita da fuori.';

-- I giocatori seminati dalla 0004 non hanno un account dietro: si tolgono,
-- da qui in poi ogni riga di users nasce da un'iscrizione vera.
delete from users where id not in (select id from auth.users);

alter table users
	drop constraint if exists users_id_fkey,
	add constraint users_id_fkey foreign key (id) references auth.users (id) on delete cascade;

-- Il profilo nasce insieme all'account, altrimenti resta il buco fra
-- "mi sono iscritto" e "esisto per gli altri".
create or replace function crea_giocatore()
returns trigger language plpgsql security definer set search_path = public as $$
begin
	insert into users (id, nome, is_admin, sola_lettura, nascosto)
	values (
		new.id,
		coalesce(new.raw_user_meta_data ->> 'nome', split_part(new.email, '@', 1)),
		coalesce((new.raw_user_meta_data ->> 'is_admin')::boolean, false),
		coalesce((new.raw_user_meta_data ->> 'sola_lettura')::boolean, false),
		coalesce((new.raw_user_meta_data ->> 'nascosto')::boolean, false)
	)
	on conflict (id) do nothing;
	return new;
end;
$$;

drop trigger if exists al_nuovo_giocatore on auth.users;
create trigger al_nuovo_giocatore
	after insert on auth.users
	for each row execute function crea_giocatore();

-- --- le tre domande che si fanno le policy ----------------------------------
create or replace function sono_admin() returns boolean
language sql stable security definer set search_path = public as $$
	select coalesce((select is_admin from users where id = auth.uid()), false);
$$;

create or replace function posso_scrivere() returns boolean
language sql stable security definer set search_path = public as $$
	select coalesce((select not sola_lettura from users where id = auth.uid()), false);
$$;

create or replace function sono_entrato() returns boolean
language sql stable set search_path = public as $$
	select auth.uid() is not null;
$$;

-- --- via le vecchie policy --------------------------------------------------
do $$
declare r record;
begin
	for r in select tablename, policyname from pg_policies where schemaname = 'public' loop
		execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
	end loop;
end $$;

-- --- lettura: chi e' dentro vede tutto --------------------------------------
-- Sono sei amici che giocano insieme: nascondersi le cose a vicenda non
-- avrebbe senso. Quello che va difeso e' la scrittura, non la vista.
do $$
declare t text;
begin
	foreach t in array array[
		'users', 'items', 'captures', 'capture_tags', 'reactions', 'transfers',
		'contests', 'votes', 'game_config', 'game_sets', 'set_requisiti',
		'finale', 'premi', 'premi_voti', 'premi_esiti', 'classifica_posizioni'
	] loop
		execute format(
			'create policy %I on public.%I for select to authenticated using (true)',
			'lettura_' || t, t
		);
	end loop;
end $$;

-- --- scrittura diretta: solo dove serve davvero -----------------------------
-- Tutto il resto passa dalle funzioni piu' sotto, che controllano le regole.

-- I like sono l'unica cosa che il client scrive da solo: sono innocui e
-- toglierli di mezzo vorrebbe dire una funzione in piu' per niente.
create policy scrivo_i_miei_like on reactions
	for insert to authenticated
	with check (user_id = auth.uid() and posso_scrivere());

create policy tolgo_i_miei_like on reactions
	for delete to authenticated
	using (user_id = auth.uid());

-- Le iscrizioni alle notifiche sono di chi le crea, e nessun altro le vede:
-- un endpoint push e' un indirizzo a cui si puo' scrivere.
create policy le_mie_notifiche on push_subscriptions
	for all to authenticated
	using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Ognuno ritocca il proprio profilo, ma non puo' promuoversi admin ne'
-- togliersi la sola lettura: quelle due colonne le muove solo un admin.
create policy ritocco_il_mio_profilo on users
	for update to authenticated
	using (id = auth.uid())
	with check (
		id = auth.uid()
		and is_admin = (select u.is_admin from users u where u.id = auth.uid())
		and sola_lettura = (select u.sola_lettura from users u where u.id = auth.uid())
		and nascosto = (select u.nascosto from users u where u.id = auth.uid())
	);

-- --- il pannello di gestione ------------------------------------------------
-- Il contenuto del gioco lo tocca solo chi e' admin. Prima bastava indovinare
-- l'indirizzo del pannello.
do $$
declare t text;
begin
	foreach t in array array[
		'items', 'game_config', 'game_sets', 'set_requisiti', 'premi', 'users',
		'captures', 'contests', 'transfers', 'finale'
	] loop
		execute format(
			'create policy %I on public.%I for all to authenticated using (sono_admin()) with check (sono_admin())',
			'admin_' || t, t
		);
	end loop;
end $$;

-- --- l'identita' non la dichiara piu' il client -----------------------------
-- Prima queste funzioni ricevevano l'id di chi agiva come parametro: bastava
-- passarne un altro per catturare al posto di qualcun altro. Fra sei amici
-- non e' mai successo; con un account per il portfolio in giro sarebbe una
-- porta aperta.
--
-- Il corpo delle funzioni non si tocca — funziona ed e' stato collaudato.
-- Si rinomina a interno, gli si toglie il permesso di esecuzione dai client,
-- e davanti ci va un guscio che l'identita' se la prende da auth.uid().

alter function registra_cattura(uuid, uuid, text, text, double precision, double precision, uuid[], timestamptz)
	rename to registra_cattura_interna;
alter function invia_croquembouche(uuid, uuid, integer, text) rename to invia_croquembouche_interna;
alter function apri_contestazione(uuid, uuid, text) rename to apri_contestazione_interna;
alter function vota_contestazione(uuid, uuid, text) rename to vota_contestazione_interna;

-- Da PUBLIC, non solo da anon e authenticated: in Postgres ogni funzione
-- nasce eseguibile da chiunque, e togliere il permesso ai due ruoli nominati
-- non serve a niente finche' resta la concessione a PUBLIC sotto.
revoke all on function registra_cattura_interna(uuid, uuid, text, text, double precision, double precision, uuid[], timestamptz) from public, anon, authenticated;
revoke all on function invia_croquembouche_interna(uuid, uuid, integer, text) from public, anon, authenticated;
revoke all on function apri_contestazione_interna(uuid, uuid, text) from public, anon, authenticated;
revoke all on function vota_contestazione_interna(uuid, uuid, text) from public, anon, authenticated;

/** Chi sta agendo, se puo' agire. Lancia invece di restituire null: un
    errore parlante e' meglio di una riga che non compare. */
create or replace function chi_agisce() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare v_id uuid; v_ferma boolean;
begin
	v_id := auth.uid();
	if v_id is null then
		raise exception 'Devi entrare per fare questo';
	end if;
	select sola_lettura into v_ferma from users where id = v_id;
	if v_ferma is null then
		raise exception 'Questo account non e'' un giocatore';
	end if;
	if v_ferma then
		raise exception 'Questo account puo'' solo guardare';
	end if;
	return v_id;
end;
$$;

create or replace function registra_cattura(
	p_item uuid, p_foto text, p_nota text default null,
	p_lat double precision default null, p_lng double precision default null,
	p_taggati uuid[] default null, p_scattata timestamptz default null
) returns uuid language sql security definer set search_path = public as $$
	select registra_cattura_interna(chi_agisce(), p_item, p_foto, p_nota, p_lat, p_lng, p_taggati, p_scattata);
$$;

create or replace function invia_croquembouche(
	p_to uuid, p_importo integer, p_causale text default null
) returns uuid language sql security definer set search_path = public as $$
	select invia_croquembouche_interna(chi_agisce(), p_to, p_importo, p_causale);
$$;

create or replace function apri_contestazione(
	p_capture uuid, p_motivo text default null
) returns uuid language sql security definer set search_path = public as $$
	select apri_contestazione_interna(p_capture, chi_agisce(), p_motivo);
$$;

create or replace function vota_contestazione(
	p_contest uuid, p_voto text
) returns void language sql security definer set search_path = public as $$
	select vota_contestazione_interna(p_contest, chi_agisce(), p_voto);
$$;

-- Anche il voto della premiazione: era gia' security definer ma si fidava del
-- votante dichiarato.
alter function vota_premio(uuid, uuid, uuid, uuid) rename to vota_premio_interna;
revoke all on function vota_premio_interna(uuid, uuid, uuid, uuid) from public, anon, authenticated;

create or replace function vota_premio(p_finale uuid, p_premio uuid, p_votato uuid)
returns void language sql security definer set search_path = public as $$
	select vota_premio_interna(p_finale, p_premio, chi_agisce(), p_votato);
$$;

-- --- chi guarda da fuori non entra in classifica ----------------------------
create or replace view v_classifica as
select s.user_id, s.nome, s.saldo, s.guadagnati,
       coalesce(d.unici, 0) as item_unici, coalesce(d.catture, 0) as catture_totali
from v_saldi s
join users u on u.id = s.user_id and not u.nascosto
left join (
	select user_id, count(distinct item_id)::int as unici, count(*)::int as catture
	from v_crediti group by user_id
) d on d.user_id = s.user_id;

alter view v_classifica set (security_invoker = true);

create or replace view v_titoli
with (security_invoker = true)
as
with
primi_crediti as (
	select cr.user_id, cr.item_id, min(cr.timestamp) as quando
	from v_crediti cr
	join users u on u.id = cr.user_id and not u.nascosto
	group by cr.user_id, cr.item_id
),
per_categoria as (
	select case i.categoria when 'pietanza' then 'ghiottona' when 'animale' then 'birdwatcher'
	       when 'posto' then 'camminatrice' end as titolo,
	       p.user_id, count(*)::int as conteggio, max(p.quando) as ultimo
	from primi_crediti p join items i on i.id = p.item_id
	where i.categoria in ('pietanza', 'animale', 'posto')
	group by i.categoria, p.user_id
),
scoperte as (
	select 'scopritrice' as titolo, pr.user_id, count(*)::int as conteggio, max(pr.timestamp) as ultimo
	from v_primati pr join users u on u.id = pr.user_id and not u.nascosto
	group by pr.user_id
),
affari as (
	select 'businessperson' as titolo, t.from_user_id as user_id, sum(t.importo)::int as conteggio,
	       max(t.created_at) as ultimo
	from transfers t join users u on u.id = t.from_user_id and not u.nascosto
	where not t.annullato group by t.from_user_id
),
gradimento as (
	select 'piaciona' as titolo, c.user_id, count(*)::int as conteggio, max(r.created_at) as ultimo
	from reactions r
	join captures c on c.id = r.capture_id
	join users u on u.id = c.user_id and not u.nascosto
	where c.stato <> 'invalidato' and r.user_id <> c.user_id
	group by c.user_id
),
tutte as (
	select titolo, user_id, conteggio, ultimo from per_categoria
	union all select titolo, user_id, conteggio, ultimo from scoperte
	union all select titolo, user_id, conteggio, ultimo from affari
	union all select titolo, user_id, conteggio, ultimo from gradimento
)
select distinct on (titolo) titolo, user_id, conteggio
from tutte where conteggio > 0
order by titolo, conteggio desc, ultimo asc;
