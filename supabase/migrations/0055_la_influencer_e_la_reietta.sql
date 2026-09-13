-- ============================================================================
-- Pachino Express — «La influencer» e «La reietta»
--
-- I due titoli che nascono con Fa' Oversharing. Il primo va a chi ha raccolto
-- piu' consenso in giro — CHIC sugli oversharing e cuori sulle foto messi
-- insieme, perche' e' la stessa cosa detta in due posti. Il secondo a chi si
-- e' preso piu' CHEAP.
--
-- «La reietta» e' un premio vero e non uno sfottò: nel gioco perdere in
-- pubblico e' gia' previsto — si puo' essere contestate, si puo' finire in
-- penalita' — e un titolo che si vince facendo ridere di se' e' esattamente
-- il tipo di cosa che questa gara premia. Serve anche a togliere la paura di
-- premere CHEAP: se il peggio che fai e' regalare una coccarda, lo premi.
--
-- --- PERCHE' LA INFLUENCER NON E' LA PIACIONA -------------------------------
-- Si somigliano e tengono conti diversi. «La piaciona» conta i like sulle
-- foto: premia chi fotografa bene. «La influencer» ci aggiunge i CHIC, quindi
-- premia chi sta simpatica — con una foto o con una frase. Possono capitare
-- alla stessa persona, e quando capita vuol dire qualcosa.
-- ============================================================================

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
        ),
        -- Il consenso raccolto, da qualunque parte sia arrivato: un CHIC
        -- sotto una frase e un cuore sotto una foto dicono la stessa cosa.
        applausi AS (
         SELECT o.user_id, v.created_at
           FROM oversharing_voti v
             JOIN oversharing o ON o.id = v.oversharing_id
          WHERE v.voto = 'chic'
        UNION ALL
         SELECT c.user_id, r.created_at
           FROM reactions r
             JOIN captures c ON c.id = r.capture_id
          WHERE c.stato <> 'invalidato'::text AND r.user_id <> c.user_id
        ), seguito AS (
         SELECT 'influencer'::text AS titolo,
            a.user_id,
            count(*)::integer AS conteggio,
            max(a.created_at) AS ultimo
           FROM applausi a
             JOIN users u ON u.id = a.user_id AND NOT u.nascosto,
            finestra_corrente() f(numero, da, a)
          WHERE (a.created_at AT TIME ZONE 'Europe/Rome'::text)::date >= f.da AND (a.created_at AT TIME ZONE 'Europe/Rome'::text)::date < f.a
          GROUP BY a.user_id
        ), fischi AS (
         SELECT 'reietta'::text AS titolo,
            o.user_id,
            count(*)::integer AS conteggio,
            max(v.created_at) AS ultimo
           FROM oversharing_voti v
             JOIN oversharing o ON o.id = v.oversharing_id
             JOIN users u ON u.id = o.user_id AND NOT u.nascosto,
            finestra_corrente() f(numero, da, a)
          WHERE v.voto = 'cheap' AND (v.created_at AT TIME ZONE 'Europe/Rome'::text)::date >= f.da AND (v.created_at AT TIME ZONE 'Europe/Rome'::text)::date < f.a
          GROUP BY o.user_id
        ), tutte AS (
         SELECT per_categoria.titolo, per_categoria.user_id, per_categoria.conteggio, per_categoria.ultimo
           FROM per_categoria
        UNION ALL
         SELECT scoperte.titolo, scoperte.user_id, scoperte.conteggio, scoperte.ultimo
           FROM scoperte
        UNION ALL
         SELECT affari.titolo, affari.user_id, affari.conteggio, affari.ultimo
           FROM affari
        UNION ALL
         SELECT gradimento.titolo, gradimento.user_id, gradimento.conteggio, gradimento.ultimo
           FROM gradimento
        UNION ALL
         SELECT seguito.titolo, seguito.user_id, seguito.conteggio, seguito.ultimo
           FROM seguito
        UNION ALL
         SELECT fischi.titolo, fischi.user_id, fischi.conteggio, fischi.ultimo
           FROM fischi
        )
 SELECT titolo, user_id, conteggio, ultimo
   FROM tutte
  WHERE conteggio > 0;

-- --- e le coccarde sanno come si chiamano -----------------------------------
create or replace function assegna_coccarde(p_stagione int)
returns int language plpgsql security definer set search_path = public as $$
declare v_quante int; v_totali int := 0;
begin
	delete from coccarde where stagione = p_stagione;

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

	insert into coccarde (user_id, stagione, tipo, chiave, etichetta, quanto)
	select t.user_id, p_stagione, 'titolo', t.titolo,
	       case t.titolo
	           when 'ghiottona' then 'La ghiottona'
	           when 'birdwatcher' then 'La birdwatcher'
	           when 'camminatrice' then 'La camminatrice'
	           when 'scopritrice' then 'La scopritrice'
	           when 'businessperson' then 'La businessperson'
	           when 'piaciona' then 'La piaciona'
	           when 'influencer' then 'La influencer'
	           when 'reietta' then 'La reietta'
	           else t.titolo
	       end,
	       t.conteggio
	from v_titoli t;
	get diagnostics v_quante = row_count;
	return v_totali + v_quante;
end;
$$;

revoke all on function assegna_coccarde(int) from public, anon, authenticated;

-- --- svuotando se ne vanno anche le chiacchiere -----------------------------
-- Stessa ragione degli scambi: senza le foto a cui rispondevano, le frasi
-- della stagione prima sono una cronaca che parla di niente. E il titolo che
-- ne e' uscito e' gia' stampato in una coccarda, quindi cancellarle non
-- toglie niente a nessuno.
create or replace function svuota_stagione(p_stagione int)
returns int language plpgsql security definer set search_path = public as $$
declare v_catture int; v_scambi int; v_frasi int;
begin
	perform esigi_svuotabile(p_stagione);

	delete from captures c
	using stagioni s
	where s.numero = p_stagione
	  and (c.timestamp at time zone 'Europe/Rome')::date >= s.inizio
	  and (c.timestamp at time zone 'Europe/Rome')::date < s.fine;
	get diagnostics v_catture = row_count;

	delete from transfers t
	using stagioni s
	where s.numero = p_stagione
	  and (t.created_at at time zone 'Europe/Rome')::date >= s.inizio
	  and (t.created_at at time zone 'Europe/Rome')::date < s.fine;
	get diagnostics v_scambi = row_count;

	delete from oversharing o
	using stagioni s
	where s.numero = p_stagione
	  and (o.created_at at time zone 'Europe/Rome')::date >= s.inizio
	  and (o.created_at at time zone 'Europe/Rome')::date < s.fine;
	get diagnostics v_frasi = row_count;

	update stagioni set foto_cancellate_at = now() where numero = p_stagione;
	return v_catture + v_scambi + v_frasi;
end;
$$;

revoke all on function svuota_stagione(int) from public, anon, authenticated;

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
	) + (select count(*)::int
	 from transfers t
	 where (t.created_at at time zone 'Europe/Rome')::date >= s.inizio
	   and (t.created_at at time zone 'Europe/Rome')::date < s.fine
	) + (select count(*)::int
	 from oversharing o
	 where (o.created_at at time zone 'Europe/Rome')::date >= s.inizio
	   and (o.created_at at time zone 'Europe/Rome')::date < s.fine
	) as catture
from stagioni s
where s.chiusa_at is not null
  and s.foto_cancellate_at is null
  and s.numero > 0
order by s.numero;

-- --- e ricominciando da capo se ne vanno tutte ------------------------------
-- Le formule no: sono arredamento del gioco, come le regole in game_config.
-- Azzerare la partita non vuol dire riscrivere le ventitre battute.
create or replace function azzera_gioco_interna()
returns table (tabella text, cancellate int)
language plpgsql set search_path to 'public' as $function$
declare
	n_catture int; n_contestazioni int; n_voti int; n_reazioni int;
	n_scambi int; n_item int; n_presenze int; n_frasi int;
begin
	select count(*) into n_voti from votes;
	delete from votes where true;

	select count(*) into n_contestazioni from contests;
	delete from contests where true;

	select count(*) into n_reazioni from reactions;
	delete from reactions where true;

	select count(*) into n_catture from captures;
	delete from captures where true;

	select count(*) into n_scambi from transfers;
	delete from transfers where true;

	select count(*) into n_presenze from presenze;
	delete from presenze where true;

	select count(*) into n_frasi from oversharing;
	delete from oversharing where true;

	select count(*) into n_item from items;
	delete from items where true;

	return query
	select * from (
		values
			('sfiziosita', n_item),
			('catture', n_catture),
			('contestazioni', n_contestazioni),
			('voti', n_voti),
			('reazioni', n_reazioni),
			('scambi', n_scambi),
			('presenze', n_presenze),
			('oversharing', n_frasi)
	) as t(tabella, cancellate);
end;
$function$;

revoke all on function azzera_gioco_interna() from public, anon, authenticated;
