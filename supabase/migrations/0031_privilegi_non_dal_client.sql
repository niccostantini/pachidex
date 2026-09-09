-- ============================================================================
-- Pachino Express — i privilegi non li dichiara chi si iscrive
--
-- Il trigger che crea il giocatore leggeva is_admin, sola_lettura e nascosto
-- da raw_user_meta_data. Quello e' esattamente il campo che il client
-- riempie al momento dell'iscrizione: bastava mandare {"is_admin": true}
-- insieme a email e password per nascere amministratore.
--
-- Oggi non e' sfruttabile perche' la registrazione libera e' chiusa, e gli
-- account li fa solo un admin. Ma e' una mina: il giorno che si riaprissero
-- le iscrizioni — o che qualcuno provasse — il buco si aprirebbe da solo,
-- senza che nessuno abbia toccato questo file.
--
-- I privilegi si spostano in raw_app_meta_data, che il client NON puo'
-- scrivere: lo riempie solo chi chiama con la chiave di servizio, cioe' il
-- nostro endpoint lato server. Il nome resta dove sta, che e' solo
-- un'etichetta.
-- ============================================================================

create or replace function crea_giocatore()
returns trigger language plpgsql security definer set search_path = public as $$
begin
	insert into users (id, nome, is_admin, sola_lettura, nascosto)
	values (
		new.id,
		coalesce(new.raw_user_meta_data ->> 'nome', split_part(new.email, '@', 1)),
		-- Da app_meta_data, non da user_meta_data: il primo lo scrive solo il
		-- server con la chiave di servizio, il secondo lo sceglie chi si iscrive.
		coalesce((new.raw_app_meta_data ->> 'is_admin')::boolean, false),
		coalesce((new.raw_app_meta_data ->> 'sola_lettura')::boolean, false),
		coalesce((new.raw_app_meta_data ->> 'nascosto')::boolean, false)
	)
	on conflict (id) do nothing;
	return new;
end;
$$;
