-- ============================================================================
-- Pachino Express — il premio di chi torna
--
-- Chi apre l'app in giorni consecutivi prende Croquembouche crescenti. Basta
-- saltare un giorno e si riparte dal primo gradino: e' la parte che tiene, e
-- va detta chiara in pagina, altrimenti sembra un premio rubato.
--
-- --- DUE COSE CHE NON SONO COME IL RESTO DEL GIOCO --------------------------
--
-- 1. Qui il premio si SCRIVE, non si ricalcola. Tutto il resto del gioco e'
--    una vista che si rifa' a ogni lettura, e cambiare una regola e'
--    retroattivo — ci contiamo. Ma una presenza e' un fatto avvenuto in un
--    giorno preciso: se domani si alza il terzo gradino da 20 a 30, chi l'ha
--    gia' preso ieri non deve ritrovarsi trenta in tasca. Quindi la riga si
--    porta dietro quanto valeva quel giorno.
--
-- 2. La funzione non alza eccezioni. La chiama l'app a ogni apertura, anche
--    quando ad aprirla e' Spione: chi non gioca non prende niente e non se ne
--    accorge, invece di trovarsi un errore addosso ogni volta.
-- ============================================================================

-- Il giorno com'e' inteso dal gioco: quello di Pachino, non quello di UTC.
-- Una granita delle 23:30 e' di stasera, non di domani.
create or replace function oggi_a_pachino() returns date
language sql stable set search_path = public as $$
	select (now() at time zone 'Europe/Rome')::date;
$$;

-- --- la scala dei premi -----------------------------------------------------
-- Una tabella e non righe in game_config: e' una lista ordinata che si
-- allunga e si accorcia dal pannello, e game_config tiene numeri singoli.
create table if not exists presenze_scala (
	passo int primary key check (passo >= 1),
	croquembouche int not null check (croquembouche >= 0)
);

comment on table presenze_scala is
	'Quanto vale ogni giorno di fila. Oltre l''ultimo gradino si resta li''.';

insert into presenze_scala (passo, croquembouche)
values (1, 5), (2, 10), (3, 20), (4, 40), (5, 60), (6, 80), (7, 100)
on conflict (passo) do nothing;

-- --- chi c'era, e quando ----------------------------------------------------
create table if not exists presenze (
	user_id uuid not null references users(id) on delete cascade,
	giorno date not null,
	/** Quanti giorni di fila, contando questo. */
	striscia int not null,
	/** Quanto e' stato dato quel giorno: non si ricalcola mai piu'. */
	croquembouche int not null,
	created_at timestamptz not null default now(),
	primary key (user_id, giorno)
);

-- L'interruttore generale sta con le altre regole del gioco.
insert into game_config (chiave, valore, descrizione)
values ('presenze_attive', 1, 'Premi per chi torna giorni di fila: 1 accesi, 0 spenti')
on conflict (chiave) do nothing;

-- --- le regole di lettura e scrittura ---------------------------------------
-- Si legge in due (chi gioca vede la propria striscia, il pannello le vede
-- tutte), si scrive solo dalla funzione qui sotto o dal pannello.
alter table presenze enable row level security;
alter table presenze_scala enable row level security;

drop policy if exists lettura_presenze on presenze;
create policy lettura_presenze on presenze for select to authenticated using (true);

drop policy if exists lettura_presenze_scala on presenze_scala;
create policy lettura_presenze_scala on presenze_scala for select to authenticated using (true);

drop policy if exists admin_presenze on presenze;
create policy admin_presenze on presenze
	for all to authenticated using (sono_admin()) with check (sono_admin());

drop policy if exists admin_presenze_scala on presenze_scala;
create policy admin_presenze_scala on presenze_scala
	for all to authenticated using (sono_admin()) with check (sono_admin());

-- --- si segna chi apre l'app ------------------------------------------------
-- Torna anche il premio di domani: e' l'unica ragione per cui uno torna, e
-- farlo sapere costa una riga qui invece di una lettura in piu' dal telefono.
drop function if exists segna_presenza();
create or replace function segna_presenza()
returns table (giorno date, striscia int, croquembouche int, prossimo int, nuova boolean)
language plpgsql security definer set search_path = public as $$
declare
	v_id uuid;
	v_oggi date;
	v_riga presenze;
	v_prima int;
	v_striscia int;
	v_premio int;
	v_prossimo int;
	v_ultimo int;
begin
	v_id := auth.uid();
	-- Chi non e' entrato, chi guarda da fuori e chi amministra: niente premio
	-- e nessun errore. Vedi la nota 2 in testa al file.
	if v_id is null or not puo_agire(v_id) then
		return;
	end if;
	if coalesce((select c.valore from game_config c where c.chiave = 'presenze_attive'), 0) = 0 then
		return;
	end if;
	-- Durante la premiazione le porte dei punti sono sbarrate: anche questa.
	if gioco_congelato() then
		return;
	end if;

	v_oggi := oggi_a_pachino();

	select max(s.passo) into v_ultimo from presenze_scala s;
	if v_ultimo is null then
		return; -- scala vuota dal pannello: e' come averli spenti
	end if;

	select * into v_riga from presenze p where p.user_id = v_id and p.giorno = v_oggi;
	if found then
		-- Gia' passato di qui oggi: si dice com'e' messo, senza rifare festa.
		select s.croquembouche into v_prossimo from presenze_scala s
		where s.passo = least(v_riga.striscia + 1, v_ultimo);
		return query select v_riga.giorno, v_riga.striscia, v_riga.croquembouche,
		                    coalesce(v_prossimo, 0), false;
		return;
	end if;

	-- La striscia continua solo se ieri c'era. Nessun "recupero": saltare un
	-- giorno costa, ed e' il motivo per cui si torna.
	select p.striscia into v_prima from presenze p
	where p.user_id = v_id and p.giorno = v_oggi - 1;
	v_striscia := coalesce(v_prima, 0) + 1;

	select s.croquembouche into v_premio from presenze_scala s
	where s.passo = least(v_striscia, v_ultimo);
	select s.croquembouche into v_prossimo from presenze_scala s
	where s.passo = least(v_striscia + 1, v_ultimo);

	insert into presenze (user_id, giorno, striscia, croquembouche)
	values (v_id, v_oggi, v_striscia, coalesce(v_premio, 0));

	return query select v_oggi, v_striscia, coalesce(v_premio, 0), coalesce(v_prossimo, 0), true;
end;
$$;

revoke all on function segna_presenza() from public, anon;
grant execute on function segna_presenza() to authenticated;

-- --- a che punto sta ognuno -------------------------------------------------
-- La striscia "di adesso" vale solo se l'ultima presenza e' di oggi o di
-- ieri: piu' indietro e' una striscia gia' rotta, e mostrarla sarebbe una
-- bugia gentile.
create or replace view v_presenze
with (security_invoker = true)
as
with ultima as (
	select distinct on (p.user_id) p.user_id, p.giorno, p.striscia
	from presenze p
	order by p.user_id, p.giorno desc
),
totali as (
	select p.user_id, sum(p.croquembouche)::int as croquembouche, count(*)::int as giorni
	from presenze p
	group by p.user_id
)
select
	u.id as user_id,
	u.nome,
	case when ul.giorno >= oggi_a_pachino() - 1 then ul.striscia else 0 end as striscia,
	coalesce(ul.striscia, 0) as striscia_ultima,
	ul.giorno as ultimo_giorno,
	coalesce(t.giorni, 0) as giorni,
	coalesce(t.croquembouche, 0) as croquembouche
from users u
left join ultima ul on ul.user_id = u.id
left join totali t on t.user_id = u.id
where in_partita(u.id);

-- --- i premi entrano nel saldo ----------------------------------------------
-- La vista si riscrive per intero: cambia solo il termine "presenze".
create or replace view v_saldi
with (security_invoker = true)
as
with guadagni as (
	select user_id, sum(croquembouche)::int as croq from v_crediti group by user_id
),
presenze_croq as (
	select user_id, sum(croquembouche)::int as croq from presenze group by user_id
),
costi as (
	select contestante_id as user_id, sum(costo_pagato)::int as croq from contests group by contestante_id
),
premi_contestazioni as (
	select contestante_id as user_id, sum(costo_pagato * 2)::int as croq
	from contests where stato = 'chiusa_non_valido' group by contestante_id
),
penalita as (
	select user_id, sum(croq)::int as croq
	from (
		select cap.user_id, co.penalita as croq
		from contests co join captures cap on cap.id = co.capture_id
		where co.stato = 'chiusa_non_valido'
		union all
		select co.contestante_id, co.penalita from contests co where co.stato = 'chiusa_valido'
	) x group by user_id
),
scambi as (
	select user_id, sum(croq)::int as croq
	from (
		select from_user_id as user_id, -importo as croq from transfers where not annullato
		union all
		select to_user_id, importo from transfers where not annullato
	) x group by user_id
)
select
	u.id as user_id,
	u.nome,
	coalesce(g.croq, 0) + coalesce(b.croq, 0) + coalesce(pc.croq, 0) + coalesce(pf.croq, 0)
		+ coalesce(pr.croq, 0) as guadagnati,
	coalesce(c.croq, 0) as spesi_in_contestazioni,
	coalesce(p.croq, 0) as penalita,
	coalesce(s.croq, 0) as saldo_scambi,
	coalesce(g.croq, 0) + coalesce(b.croq, 0) + coalesce(pc.croq, 0) + coalesce(pf.croq, 0)
		+ coalesce(pr.croq, 0)
		- coalesce(c.croq, 0) - coalesce(p.croq, 0) + coalesce(s.croq, 0) as saldo
from users u
left join guadagni g on g.user_id = u.id
left join presenze_croq pr on pr.user_id = u.id
left join costi c on c.user_id = u.id
left join premi_contestazioni pc on pc.user_id = u.id
left join penalita p on p.user_id = u.id
left join scambi s on s.user_id = u.id
left join v_set_premi b on b.user_id = u.id
left join v_premi_vinti pf on pf.user_id = u.id;

-- --- e se si ricomincia da capo, se ne vanno anche loro ----------------------
create or replace function azzera_gioco_interna()
returns table (tabella text, cancellate int)
language plpgsql set search_path to 'public' as $function$
declare
	n_catture int;
	n_contestazioni int;
	n_voti int;
	n_reazioni int;
	n_scambi int;
	n_item int;
	n_presenze int;
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
			('presenze', n_presenze)
	) as t(tabella, cancellate);
end;
$function$;
