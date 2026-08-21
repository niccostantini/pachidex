-- ============================================================================
-- Pachino Express — punti storia e capitoli
--
-- Un amico ha scritto una storia in otto capitoli. Si sbloccano riempiendo
-- una barra collettiva: i "puntini piccini picciò", che crescono di quanto
-- vale ogni cattura del gruppo.
--
-- Tre regole che decidono tutto il resto:
--
-- 1. Alimentano SOLO le catture. Non gli scambi: quelli non creano
--    croquembouche, li spostano, e contarli permetterebbe di passarseli
--    avanti e indietro generando punti dal nulla.
-- 2. Una cattura vale una volta, qualunque sia il numero di taggati. I tag
--    stanno in una tabella a parte, quindi basta sommare sulle catture.
-- 3. I punti si perdono solo con le contestazioni — e viene gratis, perche'
--    la somma e' una vista sugli eventi: una cattura invalidata sparisce dal
--    totale da sola, come gia' fa per i saldi.
--
-- Lo sblocco invece e' un timbro con la data, non una condizione ricalcolata:
-- un capitolo gia' letto non si richiude se la barra scende.
-- ============================================================================

create table if not exists story_chapters (
	numero int primary key check (numero > 0),
	titolo text,
	soglia int not null check (soglia >= 0),
	sbloccato_at timestamptz
);

-- Il titolo e' l'unica cosa davvero segreta dell'app: si vede solo dopo lo
-- sblocco. RLS accesa senza policy, come per push_config, cosi' nessun
-- client legge la tabella: si passa dalla funzione qui sotto.
alter table story_chapters enable row level security;

-- --- la barra -------------------------------------------------------------
create or replace view v_punti_storia as
select
	coalesce(sum(i.croquembouche), 0)::int as punti,
	count(*)::int as catture
from captures c
join items i on i.id = c.item_id
where c.stato in ('valido', 'in_contestazione');

alter view v_punti_storia set (security_invoker = true);

-- --- i capitoli, con il titolo nascosto finche' serve ----------------------
create or replace function capitoli()
returns table (
	numero int,
	titolo text,
	soglia int,
	sbloccato_at timestamptz,
	sbloccato boolean
)
language sql
security definer
set search_path = public
as $$
	select
		c.numero,
		-- Il titolo esce solo a capitolo sbloccato: nemmeno guardando la
		-- risposta di rete si anticipa la storia.
		case when c.sbloccato_at is not null then c.titolo end as titolo,
		c.soglia,
		c.sbloccato_at,
		c.sbloccato_at is not null as sbloccato
	from story_chapters c
	order by c.numero;
$$;

revoke execute on function capitoli() from public;
grant execute on function capitoli() to anon, authenticated;

-- --- lo sblocco -----------------------------------------------------------
/**
 * Timbra tutti i capitoli la cui soglia e' stata raggiunta e restituisce
 * quelli appena sbloccati. Nessun tetto: una giornata grossa puo' sbloccarne
 * piu' d'uno insieme, e quando leggerli e' affare del gruppo.
 */
create or replace function sblocca_capitoli()
returns table (numero int, titolo text)
language plpgsql
security definer
set search_path = public
as $$
declare
	v_punti int;
begin
	select punti into v_punti from v_punti_storia;

	return query
	update story_chapters c
	set sbloccato_at = now()
	where c.sbloccato_at is null
	  and c.soglia <= v_punti
	returning c.numero, c.titolo;
end;
$$;

revoke execute on function sblocca_capitoli() from public;
grant execute on function sblocca_capitoli() to anon, authenticated;

-- --- soglie iniziali ------------------------------------------------------
-- Tarate su dieci giorni (28 agosto - 6 settembre) e 109 elementi. I salti
-- crescono fino a meta' vacanza e poi calano: verso la fine restano solo gli
-- animali difficili e le pietanze da rifare, quindi il tratto finale deve
-- essere piu' corto, non piu' lungo. Modificabili dal pannello.
insert into story_chapters (numero, soglia, sbloccato_at) values
	(1, 0, now()),   -- gia' vostro: e' la partenza
	(2, 250, null),
	(3, 700, null),
	(4, 1350, null),
	(5, 2150, null),
	(6, 3100, null),
	(7, 4100, null),
	(8, 5000, null)
on conflict (numero) do nothing;
