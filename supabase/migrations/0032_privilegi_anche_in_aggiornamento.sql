-- ============================================================================
-- Pachino Express — i privilegi arrivano anche quando cambiano dopo
--
-- Spostati i privilegi in raw_app_meta_data (0031), l'account creato
-- dall'endpoint nasceva senza: is_admin restava falso anche chiedendo un
-- amministratore.
--
-- Il motivo e' nell'ordine delle operazioni di GoTrue: prima INSERT della
-- riga con i soli metadati di default, poi UPDATE per scriverci dentro
-- l'app_metadata richiesto. Il trigger, che ascoltava solo l'inserimento,
-- guardava un campo che in quel momento conteneva ancora
-- {"provider":"email"} e nient'altro.
--
-- Ora la stessa funzione ascolta anche l'aggiornamento, quindi i privilegi
-- si allineano sia quando l'account nasce sia quando cambiano dopo. Che e'
-- comodo di suo: promuovere o declassare qualcuno diventa una modifica ai
-- metadati, senza toccare la tabella a mano.
-- ============================================================================

create or replace function crea_giocatore()
returns trigger language plpgsql security definer set search_path = public as $$
begin
	insert into users (id, nome, is_admin, sola_lettura, nascosto)
	values (
		new.id,
		coalesce(new.raw_user_meta_data ->> 'nome', split_part(new.email, '@', 1)),
		coalesce((new.raw_app_meta_data ->> 'is_admin')::boolean, false),
		coalesce((new.raw_app_meta_data ->> 'sola_lettura')::boolean, false),
		coalesce((new.raw_app_meta_data ->> 'nascosto')::boolean, false)
	)
	on conflict (id) do update set
		-- Il nome non si sovrascrive con quello dei metadati: chi lo cambia
		-- lo cambia dal profilo, e non deve tornare indietro da solo.
		is_admin     = coalesce((new.raw_app_meta_data ->> 'is_admin')::boolean, users.is_admin),
		sola_lettura = coalesce((new.raw_app_meta_data ->> 'sola_lettura')::boolean, users.sola_lettura),
		nascosto     = coalesce((new.raw_app_meta_data ->> 'nascosto')::boolean, users.nascosto);
	return new;
end;
$$;

drop trigger if exists al_nuovo_giocatore on auth.users;
create trigger al_nuovo_giocatore
	after insert on auth.users
	for each row execute function crea_giocatore();

drop trigger if exists ai_privilegi_cambiati on auth.users;
create trigger ai_privilegi_cambiati
	after update of raw_app_meta_data on auth.users
	for each row execute function crea_giocatore();
