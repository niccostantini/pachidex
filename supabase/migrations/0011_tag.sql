-- ============================================================================
-- Pachino Express — taggare gli altri in una cattura
--
-- Una foto puo' valere per piu' persone: chi scatta tagga chi era con lui e
-- i Croquembouche vanno a tutti, PachiDex compreso.
--
-- La cattura resta UNA: una foto, un post, una sola contestazione. I tag sono
-- una tabella a parte invece che catture duplicate, perche' cosi' se il gruppo
-- boccia la foto cade per tutti insieme — con una riga per persona,
-- contestarne una lascerebbe valide le altre, che e' assurdo visto che la
-- foto e' la stessa.
-- ============================================================================

create table capture_tags (
	id uuid primary key default gen_random_uuid(),
	capture_id uuid not null references captures (id) on delete cascade,
	user_id uuid not null references users (id) on delete cascade,
	created_at timestamptz not null default now(),
	unique (capture_id, user_id)
);

create index capture_tags_capture_idx on capture_tags (capture_id);
create index capture_tags_user_idx on capture_tags (user_id);

alter table capture_tags enable row level security;
drop policy if exists accesso_libero_capture_tags on public.capture_tags;
create policy accesso_libero_capture_tags on public.capture_tags
	for all to anon, authenticated using (true) with check (true);

do $$
begin
	alter publication supabase_realtime add table public.capture_tags;
exception
	when duplicate_object then null;
end;
$$;

-- --- chi ha diritto a cosa --------------------------------------------------
-- Unifica in un posto solo le due strade per cui un giocatore prende i punti
-- di un elemento: averlo catturato, o essere stato taggato.
--
-- La deduplica e' la parte che conta. Un elemento non ripetibile vale una
-- volta sola per persona, comunque le arrivi: se Gu la granita l'ha gia'
-- presa da solo, essere taggato in quella di qualcun altro non gli aggiunge
-- niente. Il credito che sopravvive e' il piu' vecchio.
create or replace view v_crediti
with (security_invoker = true)
as
with tutti as (
	select c.user_id, c.item_id, c.id as capture_id, c.timestamp, false as da_tag
	from captures c
	where c.stato in ('valido', 'in_contestazione')

	union all

	select t.user_id, c.item_id, c.id, c.timestamp, true
	from capture_tags t
	join captures c on c.id = t.capture_id
	where c.stato in ('valido', 'in_contestazione')
),
numerati as (
	select
		tutti.*,
		i.croquembouche,
		i.ripetibile,
		row_number() over (
			partition by tutti.user_id, tutti.item_id
			order by tutti.timestamp, tutti.capture_id
		) as n
	from tutti
	join items i on i.id = tutti.item_id
)
select user_id, item_id, capture_id, timestamp, da_tag, croquembouche
from numerati
where ripetibile or n = 1;

-- --- saldo ------------------------------------------------------------------
create or replace view v_saldi as
with guadagni as (
	-- Ora si parte dai crediti, non dalle catture: cosi' i tag contano e i
	-- doppioni no, senza doverlo ripetere in ogni query.
	select user_id, sum(croquembouche)::int as croq
	from v_crediti
	group by user_id
),
costi as (
	select contestante_id as user_id, sum(costo_pagato)::int as croq
	from contests
	group by contestante_id
),
penalita as (
	select user_id, sum(croq)::int as croq
	from (
		-- La penalita' la paga chi ha pubblicato, non chi e' stato taggato:
		-- e' lui che ha messo la faccia sulla foto.
		select cap.user_id, co.penalita as croq
		from contests co
		join captures cap on cap.id = co.capture_id
		where co.stato = 'chiusa_non_valido'
		union all
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

alter view v_saldi set (security_invoker = true);

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
	from v_crediti
	group by user_id
) d on d.user_id = s.user_id;

alter view v_classifica set (security_invoker = true);

-- --- PachiDex ---------------------------------------------------------------
-- La foto resta quella di chi ha scattato; a cambiare e' solo il conteggio di
-- quanti del gruppo "ce l'hanno", che ora include i taggati.
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
	select count(*)::int as catture_gruppo, count(distinct cr.user_id)::int as scopritori
	from v_crediti cr
	where cr.item_id = i.id
) st on true
where i.attivo;

alter view v_dex set (security_invoker = true);

-- --- cattura con i taggati --------------------------------------------------
-- La vecchia firma a sei argomenti va tolta esplicitamente: aggiungendo un
-- parametro Postgres creerebbe un OVERLOAD invece di sostituire la funzione,
-- e PostgREST si troverebbe due candidate senza sapere quale chiamare.
drop function if exists registra_cattura(
	uuid, uuid, text, text, double precision, double precision
);

create or replace function registra_cattura(
	p_user uuid,
	p_item uuid,
	p_foto text,
	p_nota text default null,
	p_lat double precision default null,
	p_lng double precision default null,
	p_taggati uuid[] default null
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

	-- Chi scatta non si tagga da solo, i doppioni si ignorano, e un id che non
	-- corrisponde a nessun giocatore viene semplicemente lasciato cadere:
	-- meglio una cattura senza un tag che una cattura persa.
	if p_taggati is not null then
		insert into capture_tags (capture_id, user_id)
		select v_id, u.id
		from users u
		where u.id = any (p_taggati) and u.id <> p_user
		on conflict (capture_id, user_id) do nothing;
	end if;

	return v_id;
end;
$$;
