-- ============================================================================
-- Pachino Express — i set
--
-- Gruppi di sfiziosita' che, completati, valgono un premio doppio:
-- Croquembouche a chi lo chiude e puntini alla barra della storia, che e' di
-- tutti. Servono a dare uno scopo alla coda lunga — quelle voci che nessuno
-- guarderebbe mai perche' da sole valgono dieci punti.
--
-- Sono PERSONALI: li completa una giocatrice per volta, e possono
-- completarli tutte.
--
-- Il motore e' guidato dai dati e non dal codice, perche' dal pannello si
-- devono poter aggiungere set nuovi senza una migrazione. Un set e' una lista
-- di requisiti; li soddisfi tutti e il set e' tuo.
-- ============================================================================

create table if not exists game_sets (
	id uuid primary key default gen_random_uuid(),
	nome text not null,
	descrizione text,
	croquembouche int not null default 30 check (croquembouche >= 0),
	punti_storia int not null default 10 check (punti_storia >= 0),
	-- Tutti i requisiti devono cadere nello stesso giorno (una colazione non
	-- e' una colazione se la brioche e' di martedi' e la granita di giovedi').
	stesso_giorno boolean not null default false,
	-- ...oppure in un giorno preciso, per i riti a data fissa.
	giorno date,
	ordine int not null default 0,
	attivo boolean not null default true,
	created_at timestamptz not null default now()
);

create table if not exists set_requisiti (
	id uuid primary key default gen_random_uuid(),
	set_id uuid not null references game_sets (id) on delete cascade,
	-- parola:       un elemento qualsiasi il cui nome contiene la parola
	-- tutte_parola: TUTTI gli elementi il cui nome contiene la parola
	-- categoria:    un elemento qualsiasi di quella categoria
	-- orario:       una cattura qualsiasi in una fascia oraria
	-- tutti_taggati: una cattura con dentro tutto il gruppo
	tipo text not null check (tipo in ('parola', 'tutte_parola', 'categoria', 'orario', 'tutti_taggati')),
	valore text,
	ora_da int check (ora_da between 0 and 23),
	ora_a int check (ora_a between 1 and 24),
	-- Come si legge il requisito nella scheda del set.
	etichetta text not null,
	ordine int not null default 0
);

create index if not exists idx_set_requisiti_set on set_requisiti (set_id);

alter table game_sets enable row level security;
alter table set_requisiti enable row level security;

do $$
declare t text;
begin
	foreach t in array array['game_sets', 'set_requisiti'] loop
		execute format('drop policy if exists %I on public.%I', 'accesso_libero_' || t, t);
		execute format(
			'create policy %I on public.%I for all to anon, authenticated using (true) with check (true)',
			'accesso_libero_' || t, t
		);
	end loop;
end $$;

-- --- chi ha soddisfatto cosa ------------------------------------------------
-- Una riga per (giocatrice, requisito, giorno). Il giorno serve ai set che
-- vogliono tutto nella stessa giornata: si tiene il giorno di ogni requisito
-- e poi si cerca una giornata in cui ci sono tutti.
create or replace view v_set_soddisfatti
with (security_invoker = true)
as
with crediti as (
	-- Giorno e ora vanno letti nell'ora di Pachino, non in UTC: una granita
	-- delle 23:30 in UTC sarebbe gia' del giorno dopo, e "prima delle 8"
	-- diventerebbe un orario a caso.
	select
		cr.user_id,
		cr.item_id,
		(cr.timestamp at time zone 'Europe/Rome')::date as giorno,
		extract(hour from cr.timestamp at time zone 'Europe/Rome')::int as ora
	from v_crediti cr
),
-- Catture in cui c'e' tutto il gruppo: l'autore piu' i taggati.
al_completo as (
	select
		c.id as capture_id,
		(c.timestamp at time zone 'Europe/Rome')::date as giorno,
		c.user_id as autore
	from captures c
	where c.stato in ('valido', 'in_contestazione')
	  and (select count(*) from capture_tags t where t.capture_id = c.id) + 1
	      >= (select count(*) from users)
),
-- Il requisito lo chiudono tutti quelli che erano nella foto, non solo chi
-- l'ha scattata: "ci siete tutti" vale per tutti.
presenti as (
	select a.capture_id, a.giorno, a.autore as user_id from al_completo a
	union
	select a.capture_id, a.giorno, t.user_id
	from al_completo a
	join capture_tags t on t.capture_id = a.capture_id
),
per_parola as (
	select r.id as requisito_id, r.set_id, c.user_id, c.giorno
	from set_requisiti r
	join items i on i.attivo and i.nome ilike '%' || r.valore || '%'
	join crediti c on c.item_id = i.id
	where r.tipo = 'parola'
),
per_categoria as (
	select r.id as requisito_id, r.set_id, c.user_id, c.giorno
	from set_requisiti r
	join items i on i.attivo and i.categoria = r.valore
	join crediti c on c.item_id = i.id
	where r.tipo = 'categoria'
),
per_orario as (
	select r.id as requisito_id, r.set_id, c.user_id, c.giorno
	from set_requisiti r
	join crediti c on c.ora >= r.ora_da and c.ora < r.ora_a
	where r.tipo = 'orario'
),
per_gruppo as (
	select r.id as requisito_id, r.set_id, p.user_id, p.giorno
	from set_requisiti r
	cross join presenti p
	where r.tipo = 'tutti_taggati'
),
-- "tutte_parola" non si accontenta di uno: servono tutti gli elementi che
-- contengono quella parola. Il giorno buono e' quello in cui si e' chiuso il
-- conto, cosi' anche questo requisito sa dire quando e' stato soddisfatto.
bersaglio as (
	select r.id as requisito_id, count(*) as quanti
	from set_requisiti r
	join items i on i.attivo and i.nome ilike '%' || r.valore || '%'
	where r.tipo = 'tutte_parola'
	group by r.id
),
raccolti as (
	select r.id as requisito_id, r.set_id, c.user_id,
	       count(distinct i.id) as presi, max(c.giorno) as giorno
	from set_requisiti r
	join items i on i.attivo and i.nome ilike '%' || r.valore || '%'
	join crediti c on c.item_id = i.id
	where r.tipo = 'tutte_parola'
	group by r.id, r.set_id, c.user_id
),
per_tutte as (
	select rc.requisito_id, rc.set_id, rc.user_id, rc.giorno
	from raccolti rc
	join bersaglio b on b.requisito_id = rc.requisito_id
	where rc.presi >= b.quanti
),
tutto as (
	select requisito_id, set_id, user_id, giorno from per_parola
	union all select requisito_id, set_id, user_id, giorno from per_categoria
	union all select requisito_id, set_id, user_id, giorno from per_orario
	union all select requisito_id, set_id, user_id, giorno from per_gruppo
	union all select requisito_id, set_id, user_id, giorno from per_tutte
)
select distinct t.requisito_id, t.set_id, t.user_id, t.giorno
from tutto t
join game_sets s on s.id = t.set_id
-- Un set a data fissa guarda solo quel giorno: il selfie del 28 fatto il 30
-- non conta, altrimenti non era il primo giorno.
where s.attivo and (s.giorno is null or t.giorno = s.giorno);

-- --- a che punto sta ognuna -------------------------------------------------
create or replace view v_set_stato
with (security_invoker = true)
as
with totali as (
	select set_id, count(*)::int as totale from set_requisiti group by set_id
),
nel_giorno_migliore as (
	select set_id, user_id, max(n)::int as n
	from (
		select set_id, user_id, giorno, count(distinct requisito_id) as n
		from v_set_soddisfatti
		group by set_id, user_id, giorno
	) x
	group by set_id, user_id
),
in_tutto as (
	select set_id, user_id, count(distinct requisito_id)::int as n
	from v_set_soddisfatti
	group by set_id, user_id
)
select
	s.id as set_id,
	u.id as user_id,
	case
		when s.stesso_giorno or s.giorno is not null then coalesce(g.n, 0)
		else coalesce(a.n, 0)
	end as fatti,
	t.totale,
	case
		when s.stesso_giorno or s.giorno is not null then coalesce(g.n, 0)
		else coalesce(a.n, 0)
	end >= t.totale as completo
from game_sets s
join totali t on t.set_id = s.id
cross join users u
left join nel_giorno_migliore g on g.set_id = s.id and g.user_id = u.id
left join in_tutto a on a.set_id = s.id and a.user_id = u.id
where s.attivo;

-- --- i premi ---------------------------------------------------------------
create or replace view v_set_premi
with (security_invoker = true)
as
select
	st.user_id,
	sum(s.croquembouche)::int as croq,
	sum(s.punti_storia)::int as punti
from v_set_stato st
join game_sets s on s.id = st.set_id
where st.completo
group by st.user_id;

-- I Croquembouche dei set entrano nel saldo come i guadagni delle catture.
-- La vista va riscritta per intero: si aggiunge solo il termine dei set, il
-- resto e' identico a prima.
create or replace view v_saldi as
with guadagni as (
	select c.user_id, sum(i.croquembouche)::int as croq
	from captures c
	join items i on i.id = c.item_id
	where c.stato in ('valido', 'in_contestazione')
	group by c.user_id
),
costi as (
	select contestante_id as user_id, sum(costo_pagato)::int as croq
	from contests
	group by contestante_id
),
penalita as (
	select user_id, sum(croq)::int as croq
	from (
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
	coalesce(g.croq, 0) + coalesce(b.croq, 0) as guadagnati,
	coalesce(c.croq, 0) as spesi_in_contestazioni,
	coalesce(p.croq, 0) as penalita,
	coalesce(s.croq, 0) as saldo_scambi,
	coalesce(g.croq, 0) + coalesce(b.croq, 0)
		- coalesce(c.croq, 0) - coalesce(p.croq, 0) + coalesce(s.croq, 0) as saldo
from users u
left join guadagni g on g.user_id = u.id
left join costi c on c.user_id = u.id
left join penalita p on p.user_id = u.id
left join scambi s on s.user_id = u.id
left join v_set_premi b on b.user_id = u.id;

-- I puntini dei set finiscono nella barra della storia, che e' collettiva:
-- ogni set chiuso da chiunque la fa salire.
create or replace view v_punti_storia as
select
	(select coalesce(sum(i.croquembouche), 0)::int
	 from captures c join items i on i.id = c.item_id
	 where c.stato in ('valido', 'in_contestazione'))
	+ (select coalesce(sum(punti), 0)::int from v_set_premi) as punti,
	(select count(*)::int
	 from captures c
	 where c.stato in ('valido', 'in_contestazione')) as catture;

alter view v_punti_storia set (security_invoker = true);
