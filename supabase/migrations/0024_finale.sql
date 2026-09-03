-- ============================================================================
-- Pachino Express — la cerimonia finale
--
-- Il gioco non finisce: si chiude. Podio di partenza, poi una serie di premi
-- votati dal vivo, poi il podio aggiornato — perche' i premi danno punti veri
-- e chi era secondo puo' vincere all'ultima votazione.
--
-- --- COME SI TIENE IL PASSO -------------------------------------------------
-- Sei telefoni devono mostrare la stessa cosa nello stesso momento, e nessuno
-- di loro e' il capo. Lo stato sta tutto su una riga di "finale": in che fase
-- siamo, quale premio e' in ballo e da che istante si vota. Ogni telefono
-- guarda quella riga e l'orologio, e sa cosa disegnare senza chiedere niente
-- a nessuno.
--
-- Quando scade il minuto — o quando hanno votato tutti — ogni telefono chiama
-- chiudi_premio. Arrivano tutte insieme, ed e' voluto: la funzione e'
-- idempotente, la prima assegna e le altre non fanno niente. Non serve
-- eleggere un capo, e se il telefono di chi guida si spegne la serata va
-- avanti lo stesso.
-- ============================================================================

create table if not exists finale (
	id uuid primary key default gen_random_uuid(),
	fase text not null default 'podio' check (fase in ('podio', 'premi', 'podio_finale')),
	/** Il premio in ballo, per numero. Null nelle fasi di podio. */
	premio_numero int,
	/**
	 * L'istante da cui si vota il premio corrente. Se e' nel futuro siamo
	 * nella pausa in cui si guarda chi ha vinto quello prima: cosi' anche
	 * "aspetta qualche secondo" e' un dato, non un timer che vive dentro un
	 * telefono e muore se si blocca lo schermo.
	 */
	apertura timestamptz,
	secondi_voto int not null default 60,
	secondi_pausa int not null default 7,
	created_at timestamptz not null default now(),
	chiusa_at timestamptz
);

create table if not exists premi (
	id uuid primary key default gen_random_uuid(),
	numero int not null unique,
	domanda text not null,
	croquembouche int not null default 40 check (croquembouche >= 0),
	attivo boolean not null default true
);

create table if not exists premi_voti (
	finale_id uuid not null references finale (id) on delete cascade,
	premio_id uuid not null references premi (id) on delete cascade,
	votante_id uuid not null references users (id) on delete cascade,
	votato_id uuid not null references users (id) on delete cascade,
	created_at timestamptz not null default now(),
	-- Un voto a testa per premio. Si puo' votare se stessi: e' una serata fra
	-- amici, non un'elezione.
	primary key (finale_id, premio_id, votante_id)
);

create table if not exists premi_esiti (
	finale_id uuid not null references finale (id) on delete cascade,
	premio_id uuid not null references premi (id) on delete cascade,
	vincitore_id uuid references users (id) on delete set null,
	voti int not null default 0,
	assegnato_at timestamptz not null default now(),
	primary key (finale_id, premio_id)
);

alter table finale enable row level security;
alter table premi enable row level security;
alter table premi_voti enable row level security;
alter table premi_esiti enable row level security;

do $$
declare t text;
begin
	foreach t in array array['finale', 'premi', 'premi_voti', 'premi_esiti'] loop
		execute format('drop policy if exists %I on public.%I', 'accesso_libero_' || t, t);
		execute format(
			'create policy %I on public.%I for all to anon, authenticated using (true) with check (true)',
			'accesso_libero_' || t, t
		);
	end loop;
end $$;

-- --- il gioco e' chiuso? ----------------------------------------------------
-- La cerimonia e' terminale: una volta cominciata il gioco e' chiuso, sia
-- mentre si vota sia dopo. Il congelamento serve a garantire che il podio di
-- partenza sia quello vero e che nessuno rubi un punto mentre gli altri
-- votano.
create or replace function gioco_congelato() returns boolean
language sql stable set search_path = public as $$
	select exists (select 1 from finale);
$$;

-- --- i premi vinti entrano nel saldo ----------------------------------------
create or replace view v_premi_vinti
with (security_invoker = true)
as
select e.vincitore_id as user_id, sum(p.croquembouche)::int as croq
from premi_esiti e
join premi p on p.id = e.premio_id
where e.vincitore_id is not null
group by e.vincitore_id;

create or replace view v_saldi as
with guadagni as (
	select user_id, sum(croquembouche)::int as croq from v_crediti group by user_id
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
	coalesce(g.croq, 0) + coalesce(b.croq, 0) + coalesce(pc.croq, 0) + coalesce(pf.croq, 0) as guadagnati,
	coalesce(c.croq, 0) as spesi_in_contestazioni,
	coalesce(p.croq, 0) as penalita,
	coalesce(s.croq, 0) as saldo_scambi,
	coalesce(g.croq, 0) + coalesce(b.croq, 0) + coalesce(pc.croq, 0) + coalesce(pf.croq, 0)
		- coalesce(c.croq, 0) - coalesce(p.croq, 0) + coalesce(s.croq, 0) as saldo
from users u
left join guadagni g on g.user_id = u.id
left join costi c on c.user_id = u.id
left join premi_contestazioni pc on pc.user_id = u.id
left join penalita p on p.user_id = u.id
left join scambi s on s.user_id = u.id
left join v_set_premi b on b.user_id = u.id
left join v_premi_vinti pf on pf.user_id = u.id;

-- --- avvio ------------------------------------------------------------------
create or replace function avvia_finale()
returns uuid language plpgsql security definer set search_path = public as $$
declare
	v_id uuid;
	v_aperta record;
begin
	select id into v_id from finale limit 1;
	if v_id is not null then
		return v_id;  -- gia' avviata: si torna quella, senza farne una seconda
	end if;

	-- Le contestazioni ancora aperte si risolvono adesso con i voti che hanno:
	-- lasciarle in sospeso vorrebbe dire un podio di partenza che puo' ancora
	-- cambiare mentre lo si guarda.
	for v_aperta in select id from contests where stato = 'aperta' loop
		perform risolvi_contestazione(v_aperta.id);
	end loop;

	insert into finale (fase) values ('podio') returning id into v_id;
	return v_id;
end;
$$;

-- --- dal podio ai premi -----------------------------------------------------
create or replace function comincia_premi(p_finale uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_primo int;
begin
	select min(numero) into v_primo from premi where attivo;
	if v_primo is null then
		update finale set fase = 'podio_finale', chiusa_at = now() where id = p_finale;
		return;
	end if;
	update finale
	set fase = 'premi', premio_numero = v_primo, apertura = now()
	where id = p_finale and fase = 'podio';
end;
$$;

-- --- voto -------------------------------------------------------------------
create or replace function vota_premio(
	p_finale uuid, p_premio uuid, p_votante uuid, p_votato uuid
) returns void language plpgsql security definer set search_path = public as $$
begin
	-- Non si vota un premio gia' assegnato: se il minuto e' scaduto mentre
	-- qualcuno sceglieva, il voto arriva tardi e non conta.
	if exists (select 1 from premi_esiti where finale_id = p_finale and premio_id = p_premio) then
		raise exception 'Questo premio e'' gia'' stato assegnato';
	end if;

	insert into premi_voti (finale_id, premio_id, votante_id, votato_id)
	values (p_finale, p_premio, p_votante, p_votato)
	on conflict (finale_id, premio_id, votante_id)
	do update set votato_id = excluded.votato_id, created_at = now();
end;
$$;

-- --- chiusura di un premio --------------------------------------------------
-- La chiamano tutti i telefoni insieme quando scade il minuto. La prima
-- assegna, le altre trovano l'esito gia' scritto e si fermano li'.
create or replace function chiudi_premio(p_finale uuid, p_premio uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
	v_vincitore uuid;
	v_voti int;
	v_numero int;
	v_prossimo int;
	v_pausa int;
begin
	if exists (select 1 from premi_esiti where finale_id = p_finale and premio_id = p_premio) then
		return;
	end if;

	-- Piu' voti vince. A parita' passa avanti chi ha meno punti — cosi' il
	-- premio ricuce invece di allargare — e se anche quelli pareggiano si
	-- scende a chi ha catturato meno e poi al nome, perche' l'esito deve
	-- essere lo stesso su tutti i telefoni che stanno chiamando adesso.
	select v.votato_id, count(*)::int
	into v_vincitore, v_voti
	from premi_voti v
	join v_saldi s on s.user_id = v.votato_id
	where v.finale_id = p_finale and v.premio_id = p_premio
	group by v.votato_id, s.saldo, s.nome
	order by
		count(*) desc,
		s.saldo asc,
		(select count(*) from captures c where c.user_id = v.votato_id) asc,
		s.nome asc
	limit 1;

	insert into premi_esiti (finale_id, premio_id, vincitore_id, voti)
	values (p_finale, p_premio, v_vincitore, coalesce(v_voti, 0))
	on conflict (finale_id, premio_id) do nothing;

	select numero into v_numero from premi where id = p_premio;
	select min(numero) into v_prossimo from premi where attivo and numero > v_numero;
	select secondi_pausa into v_pausa from finale where id = p_finale;

	if v_prossimo is null then
		update finale
		set fase = 'podio_finale', premio_numero = null, chiusa_at = now()
		where id = p_finale;
	else
		-- La prossima domanda si apre fra qualche secondo: il tempo di
		-- guardare chi ha vinto questa.
		update finale
		set premio_numero = v_prossimo,
		    apertura = now() + make_interval(secs => coalesce(v_pausa, 7))
		where id = p_finale;
	end if;
end;
$$;

-- --- si torna indietro ------------------------------------------------------
-- Se parte per sbaglio, o se qualcosa va storto quella sera.
create or replace function annulla_finale()
returns void language plpgsql security definer set search_path = public as $$
begin
	delete from finale;  -- voti ed esiti se ne vanno in cascata
end;
$$;

-- --- il gioco si chiude -----------------------------------------------------
-- Le tre porte da cui entrano punti si sbarrano quando la cerimonia comincia.
-- Le funzioni sono riscritte per intero perche' plpgsql non si estende: il
-- corpo e' quello di prima con in testa il controllo.

create or replace function registra_cattura(
	p_user uuid, p_item uuid, p_foto text, p_nota text default null,
	p_lat double precision default null, p_lng double precision default null,
	p_taggati uuid[] default null, p_scattata timestamptz default null
) returns uuid language plpgsql set search_path to 'public' as $function$
declare
	v_item items; v_raggio int; v_dist double precision; v_id uuid;
	v_quando timestamptz; v_max int; v_finestra int; v_recenti int;
begin
	if gioco_congelato() then
		raise exception 'Il gioco e'' chiuso: si sta facendo la premiazione';
	end if;

	select * into v_item from items where id = p_item and attivo;
	if v_item.id is null then
		raise exception 'Questo elemento non e'' disponibile';
	end if;

	v_quando := coalesce(p_scattata, now());
	if v_quando > now() + interval '5 minutes' or v_quando < now() - interval '14 days' then
		v_quando := now();
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

	select valore into v_max from game_config where chiave = 'catture_max_finestra';
	select valore into v_finestra from game_config where chiave = 'catture_finestra_minuti';
	v_max := coalesce(v_max, 3);
	v_finestra := coalesce(v_finestra, 6);

	select count(*) into v_recenti
	from captures
	where user_id = p_user
	  and timestamp > v_quando - make_interval(mins => v_finestra)
	  and timestamp <= v_quando;

	if v_recenti >= v_max then
		raise exception 'Vai troppo di fretta: al massimo % catture ogni % minuti. Guardati intorno, poi riprova',
			v_max, v_finestra;
	end if;

	insert into captures (user_id, item_id, foto_url, nota, lat, lng, timestamp)
	values (p_user, p_item, p_foto, p_nota, p_lat, p_lng, v_quando)
	returning id into v_id;

	if p_taggati is not null then
		insert into capture_tags (capture_id, user_id)
		select v_id, u.id from users u
		where u.id = any (p_taggati) and u.id <> p_user
		on conflict (capture_id, user_id) do nothing;
	end if;

	return v_id;
end;
$function$;

create or replace function invia_croquembouche(
	p_from uuid, p_to uuid, p_importo integer, p_causale text default null
) returns uuid language plpgsql set search_path to 'public' as $function$
declare v_saldo int; v_id uuid;
begin
	if gioco_congelato() then
		raise exception 'Il gioco e'' chiuso: si sta facendo la premiazione';
	end if;
	if p_importo <= 0 then
		raise exception 'L''importo dev''essere positivo';
	end if;
	if p_from = p_to then
		raise exception 'Non puoi mandare Croquembouche a te stesso';
	end if;

	select saldo into v_saldo from v_saldi where user_id = p_from;
	if coalesce(v_saldo, 0) < p_importo then
		raise exception 'Hai solo % Croquembouche', coalesce(v_saldo, 0);
	end if;

	insert into transfers (from_user_id, to_user_id, importo, causale)
	values (p_from, p_to, p_importo, p_causale)
	returning id into v_id;
	return v_id;
end;
$function$;

create or replace function apri_contestazione(
	p_capture uuid, p_contestante uuid, p_motivo text default null
) returns uuid language plpgsql set search_path to 'public' as $function$
declare v_id uuid; v_autore uuid; v_stato text; v_costo int; v_pen int; v_ore int;
begin
	if gioco_congelato() then
		raise exception 'Il gioco e'' chiuso: si sta facendo la premiazione';
	end if;

	select c.user_id, c.stato into v_autore, v_stato from captures c where c.id = p_capture;

	if v_autore is null then
		raise exception 'Questa cattura non esiste';
	end if;
	if v_autore = p_contestante then
		raise exception 'Non puoi contestare una cattura tua';
	end if;
	if v_stato <> 'valido' then
		raise exception 'Questa cattura non e'' contestabile adesso';
	end if;

	select valore into v_costo from game_config where chiave = 'costo_apertura_contestazione';
	select valore into v_pen from game_config where chiave = 'penalita_extra_contestazione';
	select valore into v_ore from game_config where chiave = 'durata_contestazione_ore';

	insert into contests (capture_id, contestante_id, costo_pagato, penalita, motivo, scadenza)
	values (p_capture, p_contestante, coalesce(v_costo, 1), coalesce(v_pen, 15), p_motivo,
	        now() + make_interval(hours => coalesce(v_ore, 24)))
	returning id into v_id;

	update captures set stato = 'in_contestazione' where id = p_capture;
	insert into votes (contest_id, user_id, voto) values (v_id, p_contestante, 'non_valido');
	perform risolvi_contestazione(v_id);
	return v_id;
end;
$function$;
