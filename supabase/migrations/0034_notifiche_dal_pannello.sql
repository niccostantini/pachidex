-- ============================================================================
-- Pachino Express — le notifiche si governano dal pannello
--
-- Finora la configurazione delle notifiche stava solo nel database: per
-- cambiare l'indirizzo dell'app o spegnere il podio serale bisognava aprire
-- l'editor SQL di Supabase. E i lavori pianificati vivono nello schema cron,
-- che dall'API non si vede nemmeno.
--
-- Qui si aprono tre porte, tutte riservate a chi amministra: guardare come
-- sta messa la faccenda, impostare indirizzo e segreto, accendere o spegnere
-- i due lavori che mandano notifiche.
--
-- Restano funzioni e non policy sulle tabelle perche' push_config contiene un
-- segreto condiviso: meglio che passi da un punto solo, controllato, che
-- renderlo leggibile a chiunque abbia fatto login.
-- ============================================================================

-- I due lavori che mandano notifiche. Il terzo — la chiusura delle
-- contestazioni scadute — non si tocca da qui: e' solo SQL, non disturba
-- nessuno e serve al gioco anche a notifiche spente.
create or replace function stato_notifiche()
returns table (
	app_url text,
	cron_secret_impostato boolean,
	configurate boolean,
	lavori_accesi boolean,
	dispositivi int
)
language plpgsql stable security definer set search_path = public as $$
declare v_url text; v_seg text;
begin
	perform esigi_admin();

	select valore into v_url from push_config where chiave = 'app_url';
	select valore into v_seg from push_config where chiave = 'cron_secret';

	return query select
		v_url,
		-- Il segreto non esce mai di qui: si dice solo se c'e'.
		(v_seg is not null and v_seg <> '' and v_seg not like '%DA-CONFIGURARE%'),
		(v_url is not null and v_url not like '%DA-CONFIGURARE%'
		 and v_seg is not null and v_seg not like '%DA-CONFIGURARE%'),
		coalesce((select bool_or(active) from cron.job
		          where jobname in ('podio-estate', 'podio-inverno', 'promemoria-voto')), false),
		(select count(*)::int from push_subscriptions);
end;
$$;

create or replace function imposta_notifiche(p_app_url text, p_cron_secret text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
	perform esigi_admin();

	if p_app_url is not null and p_app_url <> '' then
		-- Senza slash finale: la funzione che chiama ci attacca "/api/push/cron"
		-- e due barre di fila fanno un indirizzo che non risponde.
		update push_config set valore = rtrim(trim(p_app_url), '/') where chiave = 'app_url';
	end if;

	-- Il segreto si cambia solo se ne arriva uno nuovo: il pannello non lo
	-- rilegge mai, quindi un campo lasciato vuoto significa "lascia com'e'".
	if p_cron_secret is not null and p_cron_secret <> '' then
		update push_config set valore = trim(p_cron_secret) where chiave = 'cron_secret';
	end if;
end;
$$;

create or replace function accendi_notifiche(p_accese boolean)
returns void language plpgsql security definer set search_path = public as $$
declare r record;
begin
	perform esigi_admin();
	for r in select jobid from cron.job
	         where jobname in ('podio-estate', 'podio-inverno', 'promemoria-voto') loop
		perform cron.alter_job(r.jobid, active := p_accese);
	end loop;
end;
$$;

revoke all on function stato_notifiche() from public, anon;
revoke all on function imposta_notifiche(text, text) from public, anon;
revoke all on function accendi_notifiche(boolean) from public, anon;
grant execute on function stato_notifiche() to authenticated;
grant execute on function imposta_notifiche(text, text) to authenticated;
grant execute on function accendi_notifiche(boolean) to authenticated;
