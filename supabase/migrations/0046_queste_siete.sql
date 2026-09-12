-- ============================================================================
-- Pachino Express — «Queste siete»
--
-- La pagina che si guarda quando una stagione finisce: la classifica com'e'
-- rimasta, i titoli uno per uno, le coccarde che ognuno si porta a casa.
--
-- --- PERCHE' TIENE DA PARTE DELLE FOTO --------------------------------------
-- Il Wrapped e' fatto di foto, e a fine stagione le foto si cancellano. Una
-- retrospettiva che si mangia la propria materia prima si guarda una volta
-- sola e poi diventa una tabella di numeri.
--
-- Quindi alla chiusura si mette da parte una foto per giocatore — la piu'
-- piaciuta della stagione — e quella non si cancella mai. E' anche cio' che
-- da' senso alle coccarde: ci clicchi sopra e rivedi per cosa l'hai presa.
--
-- --- E PERCHE' SI SEGNA CHI L'HA VISTA --------------------------------------
-- Le foto si cancellano solo dopo che tutti l'hanno guardata. Chi non la apre
-- entro il giorno vale come se l'avesse vista, altrimenti basta una persona
-- in ferie per bloccare tutto per sempre.
-- ============================================================================

-- --- la foto che resta ------------------------------------------------------
create table if not exists stagione_foto (
	stagione int not null references stagioni(numero) on delete cascade,
	user_id uuid not null references users(id) on delete cascade,
	foto_url text not null,
	item_nome text not null,
	mi_piace int not null default 0,
	primary key (stagione, user_id)
);

-- --- chi l'ha vista ---------------------------------------------------------
create table if not exists wrapped_visto (
	stagione int not null references stagioni(numero) on delete cascade,
	user_id uuid not null references users(id) on delete cascade,
	visto_at timestamptz not null default now(),
	primary key (stagione, user_id)
);

alter table stagione_foto enable row level security;
alter table wrapped_visto enable row level security;

do $$
declare t text;
begin
	foreach t in array array['stagione_foto', 'wrapped_visto'] loop
		execute format('drop policy if exists %I on public.%I', 'lettura_' || t, t);
		execute format(
			'create policy %I on public.%I for select to authenticated using (true)', 'lettura_' || t, t);
		execute format('drop policy if exists %I on public.%I', 'admin_' || t, t);
		execute format(
			'create policy %I on public.%I for all to authenticated using (sono_admin()) with check (sono_admin())',
			'admin_' || t, t);
	end loop;
end $$;

-- --- mettere da parte -------------------------------------------------------
-- Una per giocatore: la piu' piaciuta della stagione, e a parita' di cuori la
-- piu' preziosa. Chi non ha catturato niente non ha foto, e va bene cosi'.
create or replace function tieni_le_foto(p_stagione int)
returns int language plpgsql security definer set search_path = public as $$
declare v_da date; v_a date; v_quante int;
begin
	select inizio, fine into v_da, v_a from stagioni where numero = p_stagione;
	if v_da is null then
		raise exception 'La stagione % non esiste', p_stagione;
	end if;

	delete from stagione_foto where stagione = p_stagione;

	insert into stagione_foto (stagione, user_id, foto_url, item_nome, mi_piace)
	select distinct on (c.user_id)
		p_stagione, c.user_id, c.foto_url, i.nome,
		(select count(*)::int from reactions r where r.capture_id = c.id)
	from captures c
	join items i on i.id = c.item_id
	join users u on u.id = c.user_id and in_partita(u.id)
	where c.stato <> 'invalidato'
	  and (c.timestamp at time zone 'Europe/Rome')::date >= v_da
	  and (c.timestamp at time zone 'Europe/Rome')::date < v_a
	order by c.user_id,
	         (select count(*) from reactions r where r.capture_id = c.id) desc,
	         i.croquembouche desc,
	         c.timestamp desc;

	get diagnostics v_quante = row_count;

	-- La stessa foto finisce sulle coccarde di quella stagione: una coccarda
	-- con dentro un'immagine e' un ricordo, senza e' un adesivo.
	update coccarde c
	set foto_url = sf.foto_url
	from stagione_foto sf
	where sf.stagione = c.stagione and sf.user_id = c.user_id and c.stagione = p_stagione;

	return v_quante;
end;
$$;

revoke all on function tieni_le_foto(int) from public, anon, authenticated;

-- --- l'ho vista -------------------------------------------------------------
create or replace function segna_wrapped_visto(p_stagione int)
returns void language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
	v_id := auth.uid();
	-- Chi guarda da fuori puo' guardare il Wrapped quanto vuole, ma non conta
	-- per la cancellazione: non e' uno di quelli che devono vederlo.
	if v_id is null or not puo_agire(v_id) then
		return;
	end if;
	insert into wrapped_visto (stagione, user_id) values (p_stagione, v_id)
	on conflict (stagione, user_id) do nothing;
end;
$$;

revoke all on function segna_wrapped_visto(int) from public, anon;
grant execute on function segna_wrapped_visto(int) to authenticated;

-- --- c'e' un Wrapped da guardare? -------------------------------------------
-- L'ultima stagione chiusa, con dentro se io l'ho gia' vista e quanti
-- mancano all'appello. Il client la usa per aprire la pagina da sola.
create or replace view v_wrapped
with (security_invoker = true)
as
select
	s.numero as stagione,
	s.inizio,
	s.fine,
	s.chiusa_at,
	/** Da qui in poi si puo' cancellare anche se qualcuno non l'ha vista. */
	s.chiusa_at + interval '24 hours' as scade,
	exists (
		select 1 from wrapped_visto w
		where w.stagione = s.numero and w.user_id = auth.uid()
	) as visto_da_me,
	(select count(*)::int from wrapped_visto w where w.stagione = s.numero) as visto_da,
	(select count(*)::int from users u where in_partita(u.id)) as giocatori
from stagioni s
where s.chiusa_at is not null and s.numero > 0
order by s.numero desc
limit 1;

-- --- la chiusura mette da parte le foto --------------------------------------
create or replace function chiudi_stagione(p_giorni int default 14)
returns int language plpgsql security definer set search_path = public as $$
declare v_numero int;
begin
	perform esigi_admin();
	select numero into v_numero from stagioni where chiusa_at is null;
	if v_numero is null then
		raise exception 'Non c''e'' nessuna stagione aperta';
	end if;
	if oggi_a_pachino() <= (select inizio from stagioni where numero = v_numero) then
		raise exception 'Questa stagione e'' cominciata oggi: chiuderla adesso lascerebbe i conti a meta''';
	end if;

	-- L'ordine conta: la finestra si stringe a oggi, poi il conto si congela,
	-- poi le coccarde (che leggono i titoli, e i titoli vivono nella
	-- finestra), poi le foto da tenere — che vanno prese finche' le catture
	-- ci sono ancora. Solo alla fine la stagione risulta chiusa.
	update stagioni set fine = oggi_a_pachino() where numero = v_numero;
	perform congela_stagione(v_numero);
	perform assegna_coccarde(v_numero);
	perform tieni_le_foto(v_numero);
	update stagioni set chiusa_at = now() where numero = v_numero;

	return apri_stagione(p_giorni);
end;
$$;

revoke all on function chiudi_stagione(int) from public, anon;
grant execute on function chiudi_stagione(int) to authenticated;
