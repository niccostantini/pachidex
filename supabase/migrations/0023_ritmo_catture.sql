-- ============================================================================
-- Pachino Express — un ritmo alle catture
--
-- Il 30 agosto sono arrivate tredici catture in tre minuti e quattordici
-- secondi, una ogni quindici. Non e' un modo di giocare: e' un modo di
-- svuotare il PachiDex dal divano.
--
-- La regola e' una sola: al massimo 3 catture in 6 minuti. Tre di fila si
-- possono fare — a tavola si fotografano l'arancina, il cannolo e la granita,
-- ed e' giusto cosi' — ma a regime resta una ogni due minuti.
--
-- --- L'ORA CHE CONTA -------------------------------------------------------
-- Il limite si misura sull'ora dello SCATTO, non su quella dell'arrivo al
-- server, e per questo la funzione ora accetta p_scattata.
--
-- Senza, la coda offline si sarebbe autodistrutta: cinque catture fatte a
-- Vendicari senza campo partono tutte insieme quando torna la linea, a pochi
-- secondi l'una dall'altra, e sarebbero state rifiutate tutte tranne le
-- prime. Peggio: la coda tratta un'eccezione come rifiuto definitivo, quindi
-- quelle catture sarebbero morte li' senza essere mai ritentate.
--
-- Come effetto secondario si sistema un difetto che c'era gia': una foto
-- scattata alle 7 e caricata a mezzogiorno finiva a mezzogiorno, quindi
-- "L'alba e il tramonto" non si chiudeva e una cattura del 28 caricata il 29
-- non valeva per "Il primo giorno".
--
-- L'ora la dichiara il telefono, quindi chi vuole barare puo' spostare
-- l'orologio. Contro un amico determinato la difesa non e' questa: e' la
-- contestazione. Qui si toglie la tentazione del tap-tap-tap, non si chiude
-- una falla.
-- ============================================================================

insert into game_config (chiave, valore, descrizione) values
	('catture_max_finestra', 3, 'Catture consentite dentro la finestra: quante se ne possono fare di fila'),
	('catture_finestra_minuti', 6, 'Ampiezza della finestra in minuti; con 3 catture ogni 6 minuti si va di una ogni due a regime')
on conflict (chiave) do nothing;

create or replace function registra_cattura(
	p_user uuid,
	p_item uuid,
	p_foto text,
	p_nota text default null,
	p_lat double precision default null,
	p_lng double precision default null,
	p_taggati uuid[] default null,
	-- Nuovo, e con un default: le app gia' installate non lo passano e devono
	-- continuare a funzionare finche' non aggiornano.
	p_scattata timestamptz default null
)
returns uuid
language plpgsql
set search_path to 'public'
as $function$
declare
	v_item items;
	v_raggio int;
	v_dist double precision;
	v_id uuid;
	v_quando timestamptz;
	v_max int;
	v_finestra int;
	v_recenti int;
begin
	select * into v_item from items where id = p_item and attivo;
	if v_item.id is null then
		raise exception 'Questo elemento non e'' disponibile';
	end if;

	-- L'ora dichiarata dal telefono, con due paletti di buon senso: niente dal
	-- futuro e niente di piu' vecchio di due settimane. Fuori da li' si usa
	-- adesso, che al massimo e' impreciso ma non e' assurdo.
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

	-- Si contano le catture gia' registrate nella finestra che precede lo
	-- scatto, non quelle che precedono adesso: e' l'unico modo perche' una
	-- coda offline che si svuota tutta insieme venga giudicata per come e'
	-- stata fatta e non per come e' arrivata.
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
		select v_id, u.id
		from users u
		where u.id = any (p_taggati) and u.id <> p_user
		on conflict (capture_id, user_id) do nothing;
	end if;

	return v_id;
end;
$function$;
