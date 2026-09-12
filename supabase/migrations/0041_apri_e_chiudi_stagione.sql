-- ============================================================================
-- Pachino Express — si apre e si chiude una stagione
--
-- La 0040 ha messo la finestra. Qui ci sono i due gesti che la muovono, e una
-- cosa che ho scoperto solo provandola: aprendo la prima stagione, tutto
-- quello che era successo prima usciva dal portacroque. La finestra guardava
-- avanti e il passato non era ancora congelato da nessuna parte, quindi 437
-- Croquembouche diventavano 377 senza che nessuno avesse speso niente.
--
-- Da qui la stagione zero: quando si apre la prima, il passato diventa una
-- stagione chiusa che va da sempre a oggi, e il suo conto si scrive come
-- quello di tutte le altre. Non e' un caso speciale nascosto in un angolo: e'
-- esattamente la stessa operazione di chiusura, fatta una volta sola.
--
-- L'invariante da non rompere mai, qualunque cosa si tocchi qui dentro: il
-- portacroque non cambia di un Croquembouche nel momento in cui si congela.
-- Congelare e' scrivere cio' che si sarebbe calcolato comunque.
-- ============================================================================

-- --- il conto di una finestra qualsiasi -------------------------------------
-- Una funzione sola, usata sia per il portacroque in tempo reale sia per
-- l'istantanea: cosi' non possono scostarsi. Se il congelamento calcolasse
-- con formule proprie, il giorno che le due divergono nessuno se ne
-- accorgerebbe — i soldi sarebbero gia' in tasca a qualcuno.
create or replace function conto_stagione(p_da date, p_a date)
returns table (user_id uuid, acquisiti int, penalita int, spesi int, scambi int)
language sql stable security definer set search_path = public as $$
	with mov as (
		select m.user_id,
		       coalesce(sum(m.importo) filter (
		           where m.tipo in ('cattura','presenza','contestazione_vinta','premio')), 0)::int as acquisiti,
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

-- Le due viste della 0040 rifatte sopra la funzione, cosi' la formula sta in
-- un posto solo.
create or replace view v_punti_stagione
with (security_invoker = true)
as
select c.user_id, u.nome, c.acquisiti, c.penalita, c.acquisiti - c.penalita as punti
from finestra_corrente() f
cross join lateral conto_stagione(f.da, f.a) c
join users u on u.id = c.user_id
where in_partita(u.id);

create or replace view v_saldi
with (security_invoker = true)
as
with chiuse as (
	select ss.user_id,
	       sum(ss.acquisiti)::int as acquisiti,
	       sum(ss.penalita)::int as penalita,
	       sum(ss.spesi)::int as spesi,
	       sum(ss.scambi)::int as scambi
	from stagione_saldi ss
	group by ss.user_id
),
adesso as (
	select c.* from finestra_corrente() f cross join lateral conto_stagione(f.da, f.a) c
)
select
	u.id as user_id,
	u.nome,
	coalesce(c.acquisiti, 0) + coalesce(a.acquisiti, 0) as guadagnati,
	coalesce(c.spesi, 0) + coalesce(a.spesi, 0) as spesi_in_contestazioni,
	coalesce(c.penalita, 0) + coalesce(a.penalita, 0) as penalita,
	coalesce(c.scambi, 0) + coalesce(a.scambi, 0) as saldo_scambi,
	coalesce(c.acquisiti, 0) + coalesce(a.acquisiti, 0)
		- coalesce(c.penalita, 0) - coalesce(a.penalita, 0)
		- coalesce(c.spesi, 0) - coalesce(a.spesi, 0)
		+ coalesce(c.scambi, 0) + coalesce(a.scambi, 0) as saldo
from users u
left join chiuse c on c.user_id = u.id
left join adesso a on a.user_id = u.id;

-- --- congelare ---------------------------------------------------------------
create or replace function congela_stagione(p_numero int) returns void
language plpgsql security definer set search_path = public as $$
declare v_da date; v_a date;
begin
	select inizio, fine into v_da, v_a from stagioni where numero = p_numero;
	if v_da is null then
		raise exception 'La stagione % non esiste', p_numero;
	end if;

	delete from stagione_saldi where stagione = p_numero;

	insert into stagione_saldi (stagione, user_id, acquisiti, penalita, spesi, scambi, punti, posizione)
	select
		p_numero,
		c.user_id,
		c.acquisiti,
		c.penalita,
		c.spesi,
		c.scambi,
		c.acquisiti - c.penalita,
		-- La posizione la decide il punteggio; a parita' chi ha speso meno,
		-- poi il nome, cosi' due telefoni non mostrano due classifiche.
		row_number() over (
			order by (c.acquisiti - c.penalita) desc, c.spesi asc, u.nome asc
		)::int
	from conto_stagione(v_da, v_a) c
	join users u on u.id = c.user_id
	-- Chi guarda da fuori non ha un conto da congelare, ma se un giorno
	-- rientrasse in partita i suoi movimenti ci sarebbero ancora.
	where in_partita(u.id);
end;
$$;

-- --- il sorteggio del catalogo ----------------------------------------------
-- Un terzo delle sfiziosita' attive, per categoria, cosi' una stagione non
-- esce tutta di animali. Meno di tre elementi in una categoria: entra almeno
-- uno, altrimenti la categoria sparisce e con lei i set che la usano.
create or replace function sorteggia_catalogo(p_stagione int, p_quota numeric default 1.0 / 3)
returns int language plpgsql security definer set search_path = public as $$
declare v_quanti int;
begin
	delete from stagione_items where stagione = p_stagione;

	insert into stagione_items (stagione, item_id)
	select p_stagione, x.item_id from (
		select
			i.id as item_id,
			row_number() over (partition by i.categoria order by random()) as n,
			greatest(1, round(count(*) over (partition by i.categoria) * p_quota))::int as quanti
		from items i
		where i.attivo
	) x
	where x.n <= x.quanti;

	get diagnostics v_quanti = row_count;
	return v_quanti;
end;
$$;

-- --- aprire -----------------------------------------------------------------
create or replace function apri_stagione(p_giorni int default 14)
returns int language plpgsql security definer set search_path = public as $$
declare v_numero int; v_oggi date; v_inizio date;
begin
	perform esigi_admin();
	if p_giorni < 1 then
		raise exception 'Una stagione dura almeno un giorno';
	end if;
	if exists (select 1 from stagioni where chiusa_at is null) then
		raise exception 'C''e'' gia'' una stagione aperta: prima si chiude quella';
	end if;

	v_oggi := oggi_a_pachino();

	-- La prima volta, il passato diventa la stagione zero: senza, aprire le
	-- stagioni vorrebbe dire azzerare il portacroque a tutti.
	if not exists (select 1 from stagioni) then
		insert into stagioni (numero, inizio, fine, chiusa_at)
		values (0, '-infinity', v_oggi, now());
		perform congela_stagione(0);
	end if;

	-- La stagione nuova comincia dove e' finita quella prima, mai prima.
	-- Le finestre sono [inizio, fine): se due si sovrappongono anche di un
	-- giorno, quel giorno viene contato due volte — una nel congelato e una
	-- nel vivo — e il portacroque cresce da solo. E' successo davvero,
	-- provandolo: dieci Croquembouche diventati venti al momento della
	-- chiusura.
	select coalesce(max(numero), 0) + 1 into v_numero from stagioni;
	select greatest(v_oggi, coalesce(max(fine), v_oggi)) into v_inizio from stagioni;

	insert into stagioni (numero, inizio, fine)
	values (v_numero, v_inizio, v_inizio + p_giorni);

	perform sorteggia_catalogo(v_numero);
	return v_numero;
end;
$$;

-- --- chiudere ---------------------------------------------------------------
-- Chiude e riapre: "si ricomincia daccapo" vuol dire che il giorno dopo si
-- gioca gia'. La premiazione e la cancellazione delle foto sono un'altra
-- faccenda, e hanno i loro tempi.
create or replace function chiudi_stagione(p_giorni int default 14)
returns int language plpgsql security definer set search_path = public as $$
declare v_numero int;
begin
	perform esigi_admin();
	select numero into v_numero from stagioni where chiusa_at is null;
	if v_numero is null then
		raise exception 'Non c''e'' nessuna stagione aperta';
	end if;

	-- La finestra si chiude OGGI, qualunque fosse la scadenza prevista: cosi'
	-- la stagione dopo comincia esattamente dove finisce questa, e nessun
	-- giorno resta fuori o dentro due volte. Va fatto prima di congelare,
	-- altrimenti si scrive un conto su una finestra che poi cambia.
	--
	-- Conseguenza da sapere: quello che si fa NEL giorno della chiusura conta
	-- per la stagione nuova, non per quella che si chiude. La finestra e'
	-- [inizio, fine) e il giorno di chiusura e' il primo della successiva —
	-- l'alternativa sarebbe farlo cadere in tutte e due, che e' il modo in cui
	-- i Croquembouche si duplicano.
	if oggi_a_pachino() <= (select inizio from stagioni where numero = v_numero) then
		raise exception 'Questa stagione e'' cominciata oggi: chiuderla adesso lascerebbe i conti a meta''';
	end if;

	update stagioni set fine = oggi_a_pachino() where numero = v_numero;
	perform congela_stagione(v_numero);
	update stagioni set chiusa_at = now() where numero = v_numero;

	return apri_stagione(p_giorni);
end;
$$;

revoke all on function congela_stagione(int), sorteggia_catalogo(int, numeric) from public, anon, authenticated;
revoke all on function apri_stagione(int), chiudi_stagione(int) from public, anon;
grant execute on function apri_stagione(int), chiudi_stagione(int) to authenticated;
