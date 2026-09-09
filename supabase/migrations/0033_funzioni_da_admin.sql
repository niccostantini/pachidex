-- ============================================================================
-- Pachino Express — le funzioni del pannello vogliono un admin
--
-- Il pannello di gestione era protetto da un indirizzo difficile da
-- indovinare, e basta. Le funzioni che chiama, pero', erano chiamabili da
-- chiunque avesse fatto login — Spione compreso, che dovrebbe solo guardare.
--
-- Fra queste c'era azzera_gioco(), che cancella la partita. Una riga di
-- curl con un token qualsiasi e la vacanza spariva.
--
-- Nascondere la pagina nell'interfaccia non sarebbe servito a niente: quello
-- che conta e' chi puo' eseguire cosa, e si decide qui.
--
-- Stesso metodo gia' usato per le catture: il corpo non si tocca, si rinomina
-- a interno, gli si toglie il permesso di esecuzione (da PUBLIC, non solo dai
-- due ruoli: in Postgres ogni funzione nasce eseguibile da chiunque) e davanti
-- ci va un guscio che controlla.
-- ============================================================================

create or replace function esigi_admin() returns void
language plpgsql stable security definer set search_path = public as $$
begin
	if auth.uid() is null then
		raise exception 'Devi entrare per fare questo';
	end if;
	if not coalesce((select is_admin from users where id = auth.uid()), false) then
		raise exception 'Serve un account amministratore';
	end if;
end;
$$;

-- --- azzeramento della partita ----------------------------------------------
do $$ begin alter function azzera_gioco() rename to azzera_gioco_interna; exception when others then null; end $$;
revoke all on function azzera_gioco_interna() from public, anon, authenticated;

create or replace function azzera_gioco()
returns table (tabella text, righe bigint)
language plpgsql security definer set search_path = public as $$
begin
	perform esigi_admin();
	return query select * from azzera_gioco_interna();
end;
$$;

-- --- avvio e annullamento della premiazione ---------------------------------
do $$ begin alter function avvia_finale() rename to avvia_finale_interna; exception when others then null; end $$;
revoke all on function avvia_finale_interna() from public, anon, authenticated;

create or replace function avvia_finale() returns uuid
language plpgsql security definer set search_path = public as $$
begin
	perform esigi_admin();
	return avvia_finale_interna();
end;
$$;

do $$ begin alter function annulla_finale() rename to annulla_finale_interna; exception when others then null; end $$;
revoke all on function annulla_finale_interna() from public, anon, authenticated;

create or replace function annulla_finale() returns void
language plpgsql security definer set search_path = public as $$
begin
	perform esigi_admin();
	perform annulla_finale_interna();
end;
$$;

-- --- il via ai premi ---------------------------------------------------------
-- Questo non lo riservo all'admin: durante la cerimonia lo preme chi e' pronto,
-- e legare la serata a un telefono solo sarebbe fragile. Basta che sia un
-- giocatore vero e non uno spettatore.
do $$ begin alter function comincia_premi(uuid) rename to comincia_premi_interna; exception when others then null; end $$;
revoke all on function comincia_premi_interna(uuid) from public, anon, authenticated;

create or replace function comincia_premi(p_finale uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
	perform chi_agisce();
	perform comincia_premi_interna(p_finale);
end;
$$;

-- --- e un "where true" che sembra inutile e non lo e' -----------------------
-- annulla_finale cancellava con "delete from finale;" senza clausola. Girando
-- come postgres, per esempio da una migrazione, passa. Arrivando dall'API
-- passa invece dal ruolo su cui Supabase tiene acceso safeupdate, che rifiuta
-- le delete senza where con un messaggio che sembra un errore di sintassi.
-- Ci eravamo gia' cascati con l'azzeramento del gioco.
create or replace function annulla_finale_interna()
returns void language plpgsql security definer set search_path = public as $$
begin
	delete from finale where true;  -- voti ed esiti se ne vanno in cascata
end;
$$;
