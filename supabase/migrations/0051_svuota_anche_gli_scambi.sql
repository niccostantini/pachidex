-- ============================================================================
-- Pachino Express — svuotando se ne vanno anche gli scambi
--
-- Dopo aver svuotato una stagione il feed restava con dentro i passaggi di
-- Croquembouche di quella prima: le catture sparivano, i "Vito ha passato 25
-- a Rosa" no. Una cronaca fatta di soli scambi, senza piu' le foto a cui si
-- riferivano.
--
-- Sono movimenti della stagione come gli altri e se ne vanno con lei. Il
-- conto e' gia' congelato quando si svuota — la colonna `scambi` di
-- stagione_saldi tiene il netto di chi ha dato e chi ha ricevuto — quindi
-- togliere le righe non sposta un Croquembouche a nessuno. E' lo stesso
-- motivo per cui si possono cancellare le catture.
--
-- Le presenze invece restano: non sono cronaca, sono la catena dei giorni di
-- fila. Cancellarle spezzerebbe la striscia di chi torna da tre settimane,
-- che e' l'unica cosa che quella meccanica ha da difendere.
-- ============================================================================

create or replace function svuota_stagione(p_stagione int)
returns int language plpgsql security definer set search_path = public as $$
declare v_catture int; v_scambi int;
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
	get diagnostics v_catture = row_count;

	delete from transfers t
	using stagioni s
	where s.numero = p_stagione
	  and (t.created_at at time zone 'Europe/Rome')::date >= s.inizio
	  and (t.created_at at time zone 'Europe/Rome')::date < s.fine;
	get diagnostics v_scambi = row_count;

	update stagioni set foto_cancellate_at = now() where numero = p_stagione;
	return v_catture + v_scambi;
end;
$$;

revoke all on function svuota_stagione(int) from public, anon, authenticated;

-- E il conto di quanto c'e' da cancellare li mette insieme, cosi' il numero
-- nel pannello e' quello che sparisce davvero.
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
	) as catture
from stagioni s
where s.chiusa_at is not null
  and s.foto_cancellate_at is null
  and s.numero > 0
order by s.numero;
