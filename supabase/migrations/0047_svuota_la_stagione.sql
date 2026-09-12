-- ============================================================================
-- Pachino Express — le foto della stagione se ne vanno
--
-- L'unico pezzo di tutto il gioco che distrugge qualcosa. Quindi:
--
-- 1. Nasce SPENTO. `svuotamento_attivo` sta a zero, e finche' e' zero la
--    funzione rifiuta di fare qualsiasi cosa. Si accende dal pannello, quando
--    si e' visto che il resto funziona.
--
-- 2. Non si cancella niente finche' il Wrapped non l'hanno visto tutti —
--    oppure finche' non sono passate ventiquattr'ore dalla chiusura. Il
--    secondo ramo esiste perche' basta una persona in ferie per bloccare
--    tutto per sempre.
--
-- 3. Le foto tenute da parte per «Queste siete» non si toccano MAI. Sono
--    l'unica cosa che rende il Wrapped guardabile a distanza di mesi.
--
-- Le foto vere stanno su R2, che il database non sa toccare: qui si dice
-- QUALI cancellare e si cancellano le righe. A svuotare il secchio ci pensa
-- l'app, che le chiavi di R2 ce l'ha.
-- ============================================================================

alter table stagioni add column if not exists foto_cancellate_at timestamptz;

-- Provandolo sul seme e' saltata fuori una fragilita': le foto da tenere si
-- riconoscevano per indirizzo, e nel seme tutte le catture puntano allo
-- stesso file. Risultato, "non cancellare quelle tenute" proteggeva tutto e
-- non si cancellava niente. In produzione ogni foto ha il suo indirizzo e non
-- sarebbe successo, ma riconoscere una cattura dall'indirizzo della sua foto
-- e' sbagliato comunque: due righe possono puntare allo stesso file.
--
-- Quindi si tiene anche l'id della cattura. E si separano le due cose: le
-- RIGHE della stagione se ne vanno tutte, gli OGGETTI su R2 no — quello
-- tenuto da parte resta li' per sempre, ed e' cio' che «Queste siete»
-- continua a mostrare anche quando la cattura non esiste piu'.
alter table stagione_foto add column if not exists capture_id uuid
	references captures(id) on delete set null;

insert into game_config (chiave, valore, descrizione)
values ('svuotamento_attivo', 0,
        'Cancellazione automatica delle foto a fine stagione: 1 accesa, 0 spenta')
on conflict (chiave) do nothing;

-- --- tieni_le_foto scrive anche da quale cattura viene ----------------------
create or replace function tieni_le_foto(p_stagione int)
returns int language plpgsql security definer set search_path = public as $$
declare v_da date; v_a date; v_quante int;
begin
	select inizio, fine into v_da, v_a from stagioni where numero = p_stagione;
	if v_da is null then
		raise exception 'La stagione % non esiste', p_stagione;
	end if;

	delete from stagione_foto where stagione = p_stagione;

	insert into stagione_foto (stagione, user_id, foto_url, item_nome, mi_piace, capture_id)
	select distinct on (c.user_id)
		p_stagione, c.user_id, c.foto_url, i.nome,
		(select count(*)::int from reactions r where r.capture_id = c.id),
		c.id
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

	update coccarde c
	set foto_url = sf.foto_url
	from stagione_foto sf
	where sf.stagione = c.stagione and sf.user_id = c.user_id and c.stagione = p_stagione;

	return v_quante;
end;
$$;

revoke all on function tieni_le_foto(int) from public, anon, authenticated;

-- --- si puo' svuotare? ------------------------------------------------------
-- Buttata e rifatta: cambia il nome di una colonna, e "create or replace" su
-- una vista non sa rinominare.
drop view if exists v_da_svuotare;

create view v_da_svuotare
with (security_invoker = true)
as
select
	s.numero as stagione,
	s.chiusa_at,
	s.chiusa_at + interval '24 hours' as scade,
	(select count(*)::int from wrapped_visto w where w.stagione = s.numero) as visto_da,
	(select count(*)::int from users u where in_partita(u.id)) as giocatori,
	(
		(select count(*) from wrapped_visto w where w.stagione = s.numero)
			>= (select count(*) from users u where in_partita(u.id))
		or now() >= s.chiusa_at + interval '24 hours'
	) as pronta,
	(select count(*)::int
	 from captures c
	 where (c.timestamp at time zone 'Europe/Rome')::date >= s.inizio
	   and (c.timestamp at time zone 'Europe/Rome')::date < s.fine
	) as catture
from stagioni s
where s.chiusa_at is not null
  and s.foto_cancellate_at is null
  and s.numero > 0
order by s.numero;

-- --- quali file togliere da R2 ------------------------------------------------
-- Le foto della stagione tranne quelle tenute da parte, riconosciute per
-- indirizzo: se due catture puntassero allo stesso file, cancellarlo per una
-- lo toglierebbe anche all'altra — e quell'altra e' quella del Wrapped.
create or replace function foto_da_cancellare(p_stagione int)
returns table (capture_id uuid, foto_url text)
language sql stable security definer set search_path = public as $$
	select c.id, c.foto_url
	from captures c, stagioni s
	where s.numero = p_stagione
	  and (c.timestamp at time zone 'Europe/Rome')::date >= s.inizio
	  and (c.timestamp at time zone 'Europe/Rome')::date < s.fine
	  and not exists (
		select 1 from stagione_foto sf
		where sf.stagione = p_stagione and sf.foto_url = c.foto_url
	  );
$$;

revoke all on function foto_da_cancellare(int) from public, anon, authenticated;

-- --- svuotare ---------------------------------------------------------------
create or replace function svuota_stagione(p_stagione int)
returns int language plpgsql security definer set search_path = public as $$
declare v_quante int; v_pronta boolean;
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
