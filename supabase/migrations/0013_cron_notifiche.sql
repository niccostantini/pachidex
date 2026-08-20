-- ============================================================================
-- Pachino Express — notifiche a orario
--
-- Podio della classifica ogni sera alle 22:30 italiane, e promemoria a chi non
-- ha ancora votato due ore prima che una contestazione scada.
--
-- pg_net chiama l'endpoint dell'app, che e' l'unico posto dove si puo' firmare
-- un messaggio push (serve una chiave privata VAPID e un JWT ES256: non e'
-- roba da fare in SQL).
-- ============================================================================

create extension if not exists pg_net;

-- --- configurazione ---------------------------------------------------------
-- URL dell'app e segreto condiviso. RLS attiva e NESSUNA policy: cosi' anon
-- non la legge proprio. Le migration e pg_cron girano come postgres e passano
-- sopra le RLS, che e' esattamente cio' che serve — il segreto non deve mai
-- poter uscire dal database verso un client.
create table if not exists push_config (
	chiave text primary key,
	valore text not null
);

alter table push_config enable row level security;
revoke all on push_config from anon, authenticated;

insert into push_config (chiave, valore) values
	('app_url', 'https://DA-CONFIGURARE.vercel.app'),
	('cron_secret', 'DA-CONFIGURARE')
on conflict (chiave) do nothing;

-- --- il richiamo ------------------------------------------------------------
create or replace function chiama_notifiche(p_tipo text)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
	v_url text;
	v_segreto text;
	v_id bigint;
begin
	select valore into v_url from push_config where chiave = 'app_url';
	select valore into v_segreto from push_config where chiave = 'cron_secret';

	if v_url is null or v_url like '%DA-CONFIGURARE%' then
		raise notice 'push_config.app_url non e ancora impostato: notifica saltata';
		return null;
	end if;

	select net.http_post(
		url := v_url || '/api/push/cron?tipo=' || p_tipo,
		headers := jsonb_build_object(
			'Content-Type', 'application/json',
			'x-cron-secret', v_segreto
		),
		body := '{}'::jsonb
	) into v_id;

	return v_id;
end;
$$;

revoke execute on function chiama_notifiche(text) from public, anon, authenticated;

-- --- pianificazione ---------------------------------------------------------
-- Due voci per il podio, non una: pg_cron ragiona in UTC e l'Italia cambia ora
-- due volte l'anno. 20:30 UTC sono le 22:30 d'estate, 21:30 UTC d'inverno.
-- L'endpoint controlla che a Roma siano davvero le 22 e ignora l'altra, cosi'
-- non arriva mai doppio ne' all'ora sbagliata.
select cron.unschedule('podio-estate') where exists (select 1 from cron.job where jobname = 'podio-estate');
select cron.unschedule('podio-inverno') where exists (select 1 from cron.job where jobname = 'podio-inverno');
select cron.unschedule('promemoria-voto') where exists (select 1 from cron.job where jobname = 'promemoria-voto');

select cron.schedule('podio-estate', '30 20 * * *', $$ select chiama_notifiche('podio') $$);
select cron.schedule('podio-inverno', '30 21 * * *', $$ select chiama_notifiche('podio') $$);

-- Ogni quarto d'ora: l'endpoint guarda solo le contestazioni che scadono fra
-- 105 e 135 minuti, quindi ogni promemoria parte una volta sola.
select cron.schedule('promemoria-voto', '*/15 * * * *', $$ select chiama_notifiche('promemoria') $$);
