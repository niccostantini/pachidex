-- ============================================================================
-- Pachino Express — in gioco c'e' solo il catalogo della stagione
--
-- La 0041 sorteggia un terzo delle sfiziosita' all'apertura. Qui quel terzo
-- diventa l'unico catalogo che esiste: il PachiDex mostra quello, e catturare
-- qualcos'altro non si puo'.
--
-- Senza stagioni aperte torna tutto: chi non usa le stagioni non si accorge
-- che questa migrazione esiste.
-- ============================================================================

-- --- cosa e' in gioco adesso ------------------------------------------------
create or replace view v_items_stagione
with (security_invoker = true)
as
select i.*
from items i
where i.attivo
  and (
	not exists (select 1 from stagioni s where s.chiusa_at is null)
	or exists (
		select 1 from stagione_items si
		join stagioni s on s.numero = si.stagione and s.chiusa_at is null
		where si.item_id = i.id
	)
  );

comment on view v_items_stagione is
	'Le sfiziosita'' in gioco: il terzo sorteggiato per la stagione aperta, o tutto il catalogo se non ce n''e'' una.';

-- --- il PachiDex mostra solo quelle -----------------------------------------
-- Si riscrive per intero: e' la stessa della 0014, cambia la riga da cui
-- pesca gli elementi. Le catture che si contano sotto restano tutte, comprese
-- quelle delle stagioni passate — finche' ci sono. Il giorno che si
-- cancellano, i conti si svuotano da soli.
drop view if exists v_dex;

create view v_dex as
select
	i.id as item_id,
	i.nome,
	i.categoria,
	i.rarita,
	i.croquembouche,
	i.ripetibile,
	i.validazione,
	i.note,
	i.lat,
	i.lng,
	i.riferimento,
	f.foto_url as prima_foto,
	f.user_id as primo_scopritore,
	f.timestamp as prima_volta,
	coalesce(st.catture_gruppo, 0) as catture_gruppo,
	coalesce(st.scopritori, 0) as scopritori
from v_items_stagione i
left join lateral (
	select c.foto_url, c.user_id, c.timestamp
	from captures c
	where c.item_id = i.id and c.stato <> 'invalidato'
	order by c.timestamp asc
	limit 1
) f on true
left join lateral (
	select count(*)::int as catture_gruppo, count(distinct c.user_id)::int as scopritori
	from captures c
	where c.item_id = i.id and c.stato <> 'invalidato'
) st on true;

alter view v_dex set (security_invoker = true);

-- --- e non si cattura quello che non e' in gioco -----------------------------
-- Il controllo sta nel guscio e non dentro registra_cattura_interna: quel
-- corpo e' lungo e collaudato, e questa e' una regola della stagione, non
-- della cattura. Sta con le altre regole, sulla porta.
create or replace function registra_cattura(
	p_item uuid, p_foto text, p_nota text default null,
	p_lat double precision default null, p_lng double precision default null,
	p_taggati uuid[] default null, p_scattata timestamptz default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_chi uuid;
begin
	v_chi := chi_agisce();
	if not exists (select 1 from v_items_stagione where id = p_item) then
		raise exception 'Questa sfiziosita'' non e'' in gioco in questa stagione';
	end if;
	return registra_cattura_interna(v_chi, p_item, p_foto, p_nota, p_lat, p_lng, p_taggati, p_scattata);
end;
$$;
