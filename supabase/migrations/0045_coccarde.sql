-- ============================================================================
-- Pachino Express — le coccarde
--
-- Alla fine di ogni stagione si azzera tutto: classifica, titoli, set, foto.
-- Le coccarde sono l'unica cosa che resta, insieme al portacroque. Sono la
-- memoria lunga del gioco — senza, due settimane dopo non ci sarebbe modo di
-- sapere che qualcuno ha vinto qualcosa.
--
-- Si assegnano alla chiusura, e non si ricalcolano mai piu'. Nemmeno
-- potrebbero: vengono da una classifica e da titoli che il giorno dopo non
-- esistono gia' piu'.
-- ============================================================================

create table if not exists coccarde (
	id uuid primary key default gen_random_uuid(),
	user_id uuid not null references users(id) on delete cascade,
	stagione int not null references stagioni(numero) on delete cascade,
	/** 'podio' oppure 'titolo': decide il colore. */
	tipo text not null check (tipo in ('podio', 'titolo')),
	/** La posizione ('1','2','3') o il nome breve del titolo. */
	chiave text not null,
	/** Come si chiama, scritto una volta: se un titolo cambia nome, le
	    coccarde gia' date continuano a dire quello che dicevano. */
	etichetta text not null,
	/** Il numero che l'ha meritata: i punti, o quanti pezzi. */
	quanto int,
	/** La foto per cui l'hai presa, quando ce n'e' una. La riempie il Wrapped. */
	foto_url text,
	assegnata_at timestamptz not null default now(),
	unique (stagione, user_id, tipo, chiave)
);

create index if not exists coccarde_per_giocatore on coccarde (user_id, assegnata_at desc);

alter table coccarde enable row level security;

drop policy if exists lettura_coccarde on coccarde;
create policy lettura_coccarde on coccarde for select to authenticated using (true);

drop policy if exists admin_coccarde on coccarde;
create policy admin_coccarde on coccarde
	for all to authenticated using (sono_admin()) with check (sono_admin());

-- --- assegnarle -------------------------------------------------------------
-- Va chiamata mentre la stagione e' ancora aperta: i titoli si leggono dalla
-- finestra, e appena si chiude quella finestra non c'e' piu'.
create or replace function assegna_coccarde(p_stagione int)
returns int language plpgsql security definer set search_path = public as $$
declare v_quante int; v_totali int := 0;
begin
	delete from coccarde where stagione = p_stagione;

	-- Il podio. Solo chi ha fatto punti: una stagione in cui non hai giocato
	-- non ti mette terzo per assenza degli altri.
	insert into coccarde (user_id, stagione, tipo, chiave, etichetta, quanto)
	select ss.user_id, p_stagione, 'podio', ss.posizione::text,
	       case ss.posizione when 1 then 'Prima in classifica'
	                         when 2 then 'Seconda in classifica'
	                         else 'Terza in classifica' end,
	       ss.punti
	from stagione_saldi ss
	where ss.stagione = p_stagione and ss.posizione <= 3 and ss.punti > 0;
	get diagnostics v_quante = row_count;
	v_totali := v_totali + v_quante;

	-- I titoli, uno per uno, com'erano l'ultimo giorno.
	insert into coccarde (user_id, stagione, tipo, chiave, etichetta, quanto)
	select t.user_id, p_stagione, 'titolo', t.titolo,
	       case t.titolo
	           when 'ghiottona' then 'La ghiottona'
	           when 'birdwatcher' then 'La birdwatcher'
	           when 'camminatrice' then 'La camminatrice'
	           when 'scopritrice' then 'La scopritrice'
	           when 'businessperson' then 'La businessperson'
	           when 'piaciona' then 'La piaciona'
	           else t.titolo
	       end,
	       t.conteggio
	from v_titoli t;
	get diagnostics v_quante = row_count;
	return v_totali + v_quante;
end;
$$;

revoke all on function assegna_coccarde(int) from public, anon, authenticated;

-- --- la chiusura le assegna --------------------------------------------------
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

	-- L'ordine conta. La finestra si chiude a oggi, poi si congela il conto,
	-- poi si assegnano le coccarde — che leggono i titoli, e i titoli vivono
	-- dentro la finestra. Solo dopo la stagione risulta chiusa: se si mettesse
	-- chiusa_at prima, la finestra sarebbe gia' quella infinita e i titoli
	-- assegnati sarebbero quelli di tutta la storia del gioco.
	update stagioni set fine = oggi_a_pachino() where numero = v_numero;
	perform congela_stagione(v_numero);
	perform assegna_coccarde(v_numero);
	update stagioni set chiusa_at = now() where numero = v_numero;

	return apri_stagione(p_giorni);
end;
$$;

revoke all on function chiudi_stagione(int) from public, anon;
grant execute on function chiudi_stagione(int) to authenticated;
