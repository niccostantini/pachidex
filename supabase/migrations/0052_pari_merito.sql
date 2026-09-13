-- ============================================================================
-- Pachino Express — a pari merito il premio e' di tutti e due
--
-- Le coccarde si assegnavano a una persona sola. In classifica la posizione
-- usciva da row_number(), che a parita' di punti sceglie comunque un primo e
-- un secondo — in base a quanto avevano speso, o al nome: un ordine che non
-- vuol dire niente, deciso da una riga di SQL. E i titoli passavano da
-- v_titoli, che ne tiene uno solo.
--
-- Dentro la stagione un titolo conteso ce l'ha una persona alla volta, e a
-- pari merito lo tiene chi ci e' arrivato prima: e' la regola della cintura,
-- serve a rendere il titolo qualcosa che si puo' soffiare, e resta com'e'.
-- Ma quando la stagione finisce e la coccarda si stampa per sempre, due
-- persone arrivate allo stesso punto hanno fatto la stessa cosa. Se ne prende
-- una ciascuna.
--
-- Per il podio si passa a rank(): due primi restano primi tutti e due, e dopo
-- di loro viene il terzo. Il secondo posto non esiste, ed e' giusto cosi' —
-- non l'ha occupato nessuno.
-- ============================================================================

-- --- la classifica di ogni titolo, per intero -------------------------------
-- v_titoli ne mostra uno, ma per premiare servono tutti: il taglio si sposta
-- qui sotto, cosi' non c'e' una seconda copia di questo cosone da tenere
-- allineata.
create or replace view v_titoli_tutti
with (security_invoker = true)
as
WITH primi_crediti AS (
         SELECT cr.user_id,
            cr.item_id,
            min(cr."timestamp") AS quando
           FROM v_crediti cr
             JOIN users u ON u.id = cr.user_id AND NOT u.nascosto,
            finestra_corrente() f(numero, da, a)
          WHERE (cr."timestamp" AT TIME ZONE 'Europe/Rome'::text)::date >= f.da AND (cr."timestamp" AT TIME ZONE 'Europe/Rome'::text)::date < f.a
          GROUP BY cr.user_id, cr.item_id
        ), per_categoria AS (
         SELECT
                CASE i.categoria
                    WHEN 'pietanza'::text THEN 'ghiottona'::text
                    WHEN 'animale'::text THEN 'birdwatcher'::text
                    WHEN 'posto'::text THEN 'camminatrice'::text
                    ELSE NULL::text
                END AS titolo,
            p.user_id,
            count(*)::integer AS conteggio,
            max(p.quando) AS ultimo
           FROM primi_crediti p
             JOIN items i ON i.id = p.item_id
          WHERE i.categoria = ANY (ARRAY['pietanza'::text, 'animale'::text, 'posto'::text])
          GROUP BY i.categoria, p.user_id
        ), scoperte AS (
         SELECT 'scopritrice'::text AS titolo,
            pr.user_id,
            count(*)::integer AS conteggio,
            max(pr."timestamp") AS ultimo
           FROM v_primati pr
             JOIN users u ON u.id = pr.user_id AND NOT u.nascosto,
            finestra_corrente() f(numero, da, a)
          WHERE (pr."timestamp" AT TIME ZONE 'Europe/Rome'::text)::date >= f.da AND (pr."timestamp" AT TIME ZONE 'Europe/Rome'::text)::date < f.a
          GROUP BY pr.user_id
        ), affari AS (
         SELECT 'businessperson'::text AS titolo,
            t.from_user_id AS user_id,
            sum(t.importo)::integer AS conteggio,
            max(t.created_at) AS ultimo
           FROM transfers t
             JOIN users u ON u.id = t.from_user_id AND NOT u.nascosto,
            finestra_corrente() f(numero, da, a)
          WHERE NOT t.annullato AND (t.created_at AT TIME ZONE 'Europe/Rome'::text)::date >= f.da AND (t.created_at AT TIME ZONE 'Europe/Rome'::text)::date < f.a
          GROUP BY t.from_user_id
        ), gradimento AS (
         SELECT 'piaciona'::text AS titolo,
            c.user_id,
            count(*)::integer AS conteggio,
            max(r.created_at) AS ultimo
           FROM reactions r
             JOIN captures c ON c.id = r.capture_id
             JOIN users u ON u.id = c.user_id AND NOT u.nascosto,
            finestra_corrente() f(numero, da, a)
          WHERE c.stato <> 'invalidato'::text AND r.user_id <> c.user_id AND (r.created_at AT TIME ZONE 'Europe/Rome'::text)::date >= f.da AND (r.created_at AT TIME ZONE 'Europe/Rome'::text)::date < f.a
          GROUP BY c.user_id
        ), tutte AS (
         SELECT per_categoria.titolo,
            per_categoria.user_id,
            per_categoria.conteggio,
            per_categoria.ultimo
           FROM per_categoria
        UNION ALL
         SELECT scoperte.titolo,
            scoperte.user_id,
            scoperte.conteggio,
            scoperte.ultimo
           FROM scoperte
        UNION ALL
         SELECT affari.titolo,
            affari.user_id,
            affari.conteggio,
            affari.ultimo
           FROM affari
        UNION ALL
         SELECT gradimento.titolo,
            gradimento.user_id,
            gradimento.conteggio,
            gradimento.ultimo
           FROM gradimento
        )
 SELECT titolo,
    user_id,
    conteggio,
    ultimo
   FROM tutte
  WHERE conteggio > 0;;


-- --- e v_titoli resta quella di prima, il titolare di adesso ----------------
create or replace view v_titoli
with (security_invoker = true)
as
select distinct on (titolo) titolo, user_id, conteggio
from v_titoli_tutti
order by titolo, conteggio desc, ultimo;

-- --- la posizione non spacca i pari merito ----------------------------------
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
		-- rank() e non row_number(): a parita' di punti la posizione e' la
		-- stessa. Due primi, poi il terzo.
		rank() over (order by (c.acquisiti - c.penalita) desc)::int
	from conto_stagione(v_da, v_a) c
	join users u on u.id = c.user_id
	where in_partita(u.id);
end;
$$;

-- --- e le coccarde vanno a tutti quelli che sono arrivati li' ---------------
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

	-- I titoli: tutti quelli che hanno raggiunto il conteggio piu' alto, non
	-- solo chi lo teneva l'ultimo giorno.
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
	from v_titoli_tutti t
	where t.conteggio = (select max(x.conteggio) from v_titoli_tutti x where x.titolo = t.titolo);
	get diagnostics v_quante = row_count;
	return v_totali + v_quante;
end;
$$;

revoke all on function congela_stagione(int), assegna_coccarde(int) from public, anon, authenticated;
