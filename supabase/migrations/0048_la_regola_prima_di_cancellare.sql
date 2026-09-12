-- ============================================================================
-- Pachino Express — la regola si chiede prima di cancellare, non dopo
--
-- Difetto trovato rileggendo la 0047. Tutte le sicurezze dello svuotamento —
-- interruttore acceso, Wrapped visto da tutti o ventiquattr'ore passate,
-- stagione non gia' svuotata — stavano dentro svuota_stagione, che l'app
-- chiama DOPO aver tolto i file da R2. foto_da_cancellare, che e' il primo
-- passo, non controllava niente: restituiva l'elenco e basta.
--
-- Quindi bastava che una delle condizioni non reggesse — l'interruttore
-- rispento da un altro dispositivo, la scheda del pannello rimasta aperta,
-- una chiamata diretta all'endpoint con il token dell'admin — e le foto
-- sparivano lo stesso, mentre le righe restavano a puntare a file che non
-- c'erano piu'. Un feed rotto per sempre, e nessun modo di tornare indietro.
--
-- Adesso la regola sta in un posto solo e la chiedono tutte e due le porte.
-- Chi un domani aggiungera' una terza strada la trovera' sulla sua strada
-- senza doversela ricordare.
-- ============================================================================

create or replace function esigi_svuotabile(p_stagione int) returns void
language plpgsql stable security definer set search_path = public as $$
declare v_pronta boolean;
begin
	if coalesce((select valore from game_config where chiave = 'svuotamento_attivo'), 0) = 0 then
		raise exception 'Lo svuotamento e'' spento: si accende dal pannello';
	end if;

	select pronta into v_pronta from v_da_svuotare where stagione = p_stagione;
	if v_pronta is null then
		raise exception 'La stagione % non c''e'', non e'' chiusa, o e'' gia'' svuotata', p_stagione;
	end if;
	if not v_pronta then
		raise exception 'Aspetta: il Wrapped non l''hanno ancora visto tutti e non sono passate 24 ore';
	end if;
end;
$$;

revoke all on function esigi_svuotabile(int) from public, anon, authenticated;

-- --- l'elenco si nega alle stesse condizioni --------------------------------
create or replace function foto_da_cancellare(p_stagione int)
returns table (capture_id uuid, foto_url text)
language plpgsql stable security definer set search_path = public as $$
begin
	perform esigi_svuotabile(p_stagione);

	return query
	select c.id, c.foto_url
	from captures c, stagioni s
	where s.numero = p_stagione
	  and (c.timestamp at time zone 'Europe/Rome')::date >= s.inizio
	  and (c.timestamp at time zone 'Europe/Rome')::date < s.fine
	  and not exists (
		select 1 from stagione_foto sf
		where sf.stagione = p_stagione and sf.foto_url = c.foto_url
	  );
end;
$$;

revoke all on function foto_da_cancellare(int) from public, anon, authenticated;

-- --- e lo svuotamento chiede la stessa cosa ---------------------------------
create or replace function svuota_stagione(p_stagione int)
returns int language plpgsql security definer set search_path = public as $$
declare v_quante int;
begin
	perform esigi_svuotabile(p_stagione);

	-- Le righe se ne vanno TUTTE, anche quelle delle foto tenute da parte: il
	-- feed della stagione finita non deve restare mezzo pieno. Quelle foto
	-- continuano a vedersi lo stesso, perche' stagione_foto si tiene
	-- l'indirizzo per conto suo — ed e' per questo che il riferimento alla
	-- cattura e' "on delete set null" e non "cascade".
	--
	-- Con le catture se ne vanno tag, like e contestazioni che ci pendono. Il
	-- conto della stagione e' gia' congelato: nessun Croquembouche si muove.
	delete from captures c
	using stagioni s
	where s.numero = p_stagione
	  and (c.timestamp at time zone 'Europe/Rome')::date >= s.inizio
	  and (c.timestamp at time zone 'Europe/Rome')::date < s.fine;
	get diagnostics v_quante = row_count;

	update stagioni set foto_cancellate_at = now() where numero = p_stagione;
	return v_quante;
end;
$$;

revoke all on function svuota_stagione(int) from public, anon, authenticated;
