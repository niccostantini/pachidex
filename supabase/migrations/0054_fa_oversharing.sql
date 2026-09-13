-- ============================================================================
-- Pachino Express — Fa' Oversharing
--
-- Fino a qui nel feed si poteva mettere solo cio' che si era fatto: una foto,
-- uno scambio, una lite. Mancava il rumore di fondo — la frase che uno dice
-- mentre aspetta la granita, che non e' una cattura e non vale Croquembouche,
-- e che e' meta' di quello che succede davvero in vacanza.
--
-- --- PERCHE' UNA FORMULA DAVANTI --------------------------------------------
-- «Ciccio: che caldo» e' un messaggio. «Ciccio sussurra all'orecchio del
-- frigo: che caldo» e' una scena. La formula non e' decorazione: e' quello
-- che rende pubblicabile una frase che da sola non varrebbe la pena di
-- scrivere, e toglie a chi scrive il peso di essere spiritoso — ci pensa gia'
-- la cornice.
--
-- Si sceglie all'inserimento e resta quella. Sorteggiarla a ogni lettura
-- sarebbe stato piu' semplice, ma una battuta che cambia identita' a ogni
-- ricarica non si puo' nemmeno citare: «hai visto quella del commercialista?»
-- e non c'e' piu'. La formula appartiene al post come la didascalia a una
-- foto.
--
-- Se una formula viene tolta dal pannello, i post che ce l'avevano non
-- restano monchi: il riferimento va a null e l'app ne rimette una — sempre la
-- stessa per quel post, perche' la pesca con il suo id.
--
-- --- CHIC E CHEAP -----------------------------------------------------------
-- Due pulsanti, non uno. Un solo cuore fa salire tutto e basta; potendo dire
-- anche di no, il conto vuol dire qualcosa — ed e' cio' che rende possibile
-- premiare «La reietta», che e' il premio piu' divertente dei due.
--
-- Un voto per persona per post, cambiabile finche' la stagione e' aperta:
-- dopo, quel conto e' gia' finito in una coccarda e non si tocca piu'. Non si
-- vota se stessi, che e' l'unico modo di rovinare una classifica cosi'.
-- ============================================================================

-- --- le formule -------------------------------------------------------------
-- La X e' il posto dove va il nome. Sta nel testo e non a parte perche' un
-- domani potrebbe non stare all'inizio: «Con la voce di X:» e' una formula
-- come le altre, e questa forma la regge senza cambiare niente.
create table if not exists formule (
	id uuid primary key default gen_random_uuid(),
	testo text not null check (length(trim(testo)) between 1 and 120),
	ordine int not null default 0,
	attiva boolean not null default true,
	created_at timestamptz not null default now()
);

create index if not exists formule_in_ordine on formule (ordine, created_at);

-- --- i post -----------------------------------------------------------------
create table if not exists oversharing (
	id uuid primary key default gen_random_uuid(),
	user_id uuid not null references users(id) on delete cascade,
	testo text not null check (length(trim(testo)) between 1 and 280),
	/** Quella pescata alla pubblicazione. Null se poi e' stata tolta. */
	formula_id uuid references formule(id) on delete set null,
	created_at timestamptz not null default now()
);

create index if not exists oversharing_in_cronaca on oversharing (created_at desc);
create index if not exists oversharing_per_autore on oversharing (user_id);

-- --- i voti -----------------------------------------------------------------
create table if not exists oversharing_voti (
	oversharing_id uuid not null references oversharing(id) on delete cascade,
	user_id uuid not null references users(id) on delete cascade,
	voto text not null check (voto in ('chic', 'cheap')),
	created_at timestamptz not null default now(),
	primary key (oversharing_id, user_id)
);

create index if not exists oversharing_voti_per_chi on oversharing_voti (user_id);

-- --- chi vede e chi tocca ---------------------------------------------------
alter table formule enable row level security;
alter table oversharing enable row level security;
alter table oversharing_voti enable row level security;

drop policy if exists lettura_formule on formule;
create policy lettura_formule on formule for select to authenticated using (true);

drop policy if exists admin_formule on formule;
create policy admin_formule on formule
	for all to authenticated using (sono_admin()) with check (sono_admin());

drop policy if exists lettura_oversharing on oversharing;
create policy lettura_oversharing on oversharing for select to authenticated using (true);

-- Si pubblica dalla funzione, che pesca la formula e misura il testo. Qui
-- resta solo il ripensamento: il proprio si butta, e chi amministra puo'
-- togliere quello che non doveva uscire.
drop policy if exists butto_i_miei_oversharing on oversharing;
create policy butto_i_miei_oversharing on oversharing
	for delete to authenticated using (user_id = auth.uid() or sono_admin());

drop policy if exists lettura_oversharing_voti on oversharing_voti;
create policy lettura_oversharing_voti on oversharing_voti
	for select to authenticated using (true);

drop policy if exists admin_oversharing_voti on oversharing_voti;
create policy admin_oversharing_voti on oversharing_voti
	for all to authenticated using (sono_admin()) with check (sono_admin());

-- --- pubblicare -------------------------------------------------------------
create or replace function pubblica_oversharing(p_testo text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_chi uuid; v_testo text; v_formula uuid; v_id uuid;
begin
	v_chi := chi_agisce();
	v_testo := trim(coalesce(p_testo, ''));
	if v_testo = '' then
		raise exception 'Non hai scritto niente';
	end if;
	if length(v_testo) > 280 then
		raise exception 'Massimo 280 caratteri: ne hai scritti %', length(v_testo);
	end if;

	select id into v_formula from formule where attiva order by random() limit 1;

	insert into oversharing (user_id, testo, formula_id)
	values (v_chi, v_testo, v_formula)
	returning id into v_id;
	return v_id;
end;
$$;

revoke all on function pubblica_oversharing(text) from public, anon;
grant execute on function pubblica_oversharing(text) to authenticated;

-- --- votare -----------------------------------------------------------------
-- Ripremere lo stesso pulsante toglie il voto: e' come funzionano gia' i
-- cuori sulle foto, e qui serve anche a poter dire «non lo so» dopo averlo
-- detto. Premere l'altro cambia idea.
create or replace function vota_oversharing(p_oversharing uuid, p_voto text)
returns text language plpgsql security definer set search_path = public as $$
declare v_chi uuid; v_autore uuid; v_quando timestamptz; v_prima text; v_da date; v_a date;
begin
	v_chi := chi_agisce();
	if p_voto not in ('chic', 'cheap') then
		raise exception 'Si vota chic o cheap';
	end if;

	select user_id, created_at into v_autore, v_quando
	from oversharing where id = p_oversharing;
	if v_autore is null then
		raise exception 'Questo oversharing non c''e'' piu''';
	end if;
	if v_autore = v_chi then
		raise exception 'Il tuo non lo puoi votare';
	end if;

	-- Solo dentro la stagione in corso: il conto di quelle chiuse e' gia'
	-- diventato una coccarda, e una coccarda non si rinegozia.
	select da, a into v_da, v_a from finestra_corrente();
	if (v_quando at time zone 'Europe/Rome')::date < v_da
		or (v_quando at time zone 'Europe/Rome')::date >= v_a then
		raise exception 'Questa stagione e'' chiusa: si vota quello di adesso';
	end if;

	select voto into v_prima from oversharing_voti
	where oversharing_id = p_oversharing and user_id = v_chi;

	if v_prima = p_voto then
		delete from oversharing_voti
		where oversharing_id = p_oversharing and user_id = v_chi;
		return null;
	end if;

	insert into oversharing_voti (oversharing_id, user_id, voto)
	values (p_oversharing, v_chi, p_voto)
	on conflict (oversharing_id, user_id)
	do update set voto = excluded.voto, created_at = now();
	return p_voto;
end;
$$;

revoke all on function vota_oversharing(uuid, text) from public, anon;
grant execute on function vota_oversharing(uuid, text) to authenticated;

-- --- le ventitre di partenza ------------------------------------------------
insert into formule (testo, ordine)
select testo, (row_number() over ())::int
from unnest(array[
	'X suggerisce sommessamente:',
	'X grida sguaitamente:',
	'X asserisce con convinzione:',
	'X ridacchia sotto i baffi:',
	'X mormora tra i denti:',
	'X urla al soffitto:',
	'X sussurra all''orecchio del frigo:',
	'X sbotta con dignita'':',
	'X annuncia con la voce del meteo:',
	'X bisbiglia al proprio ombelico:',
	'X tuona dal divano:',
	'X confida al cuscino:',
	'X sputacchia la frase:',
	'X scandisce con lentezza teatrale:',
	'X borbotta al gatto:',
	'X masticando la penna:',
	'X con la faccia di chi ha dormito poco:',
	'X al telefono con l''operatore:',
	'X mentre si gratta la testa:',
	'X con tono da commercialista:',
	'X tra un sorso di caffe'' e l''altro:',
	'X con la voce di chi ha appena visto un fantasma:',
	'X al terzo tentativo:'
]) as testo
where not exists (select 1 from formule);
