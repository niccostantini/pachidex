-- ============================================================================
-- Pachino Express — si menziona solo chi gioca
--
-- Da quando l'app ha account veri, dentro users non ci sono solo giocatori:
-- c'e' Admin, che amministra e basta, e c'e' Spione, che guarda la partita da
-- fuori. Tutti e due sono `nascosto`, cioe' fuori da classifica e titoli.
--
-- Il menu delle @menzioni pero' li offriva come chiunque altro, e taggarli
-- funzionava: un nome nel feed accanto agli altri, per due che non giocano.
-- Il client adesso non li propone piu'; qui si chiude la porta anche dal lato
-- del database, perche' la RPC accetta comunque gli id che le si passano.
--
-- Di conseguenza va corretto anche "una foto con tutto il gruppo": contava
-- tutte le righe di users, Admin e Spione compresi, e quindi chiedeva una
-- foto con dentro due persone che non si possono nemmeno taggare. Cosi'
-- com'era, quel requisito non lo chiudeva piu' nessuno.
-- ============================================================================

-- --- i tag si fermano ai giocatori ------------------------------------------
-- Il corpo e' quello di prima: plpgsql non si estende, e cambia solo l'ultima
-- insert.
create or replace function registra_cattura_interna(
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
		-- Gli id che non sono di giocatori si buttano in silenzio: la cattura
		-- e' buona lo stesso, e un errore qui farebbe perdere la foto per un
		-- nome che il menu non offre nemmeno piu'.
		insert into capture_tags (capture_id, user_id)
		select v_id, u.id from users u
		where u.id = any (p_taggati) and u.id <> p_user and not u.nascosto
		on conflict (capture_id, user_id) do nothing;
	end if;

	return v_id;
end;
$function$;

-- --- "tutto il gruppo" e' il gruppo che gioca -------------------------------
-- La vista si riscrive per intero perche' non si estende: cambia solo il
-- conto dentro al_completo.
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
-- Catture in cui c'e' tutto il gruppo: l'autore piu' i taggati. Chi guarda da
-- fuori non conta nel totale, altrimenti la foto di gruppo la chiuderebbe solo
-- una fotografia impossibile.
al_completo as (
	select
		c.id as capture_id,
		(c.timestamp at time zone 'Europe/Rome')::date as giorno,
		c.user_id as autore
	from captures c
	where c.stato in ('valido', 'in_contestazione')
	  and (select count(*) from capture_tags t where t.capture_id = c.id) + 1
	      >= (select count(*) from users where not nascosto)
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
