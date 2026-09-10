-- ============================================================================
-- Pachino Express — dopo l'ultimo gradino si ricomincia a salire
--
-- La 0037 lasciava chi arriva in cima a prendere il premio massimo per sempre:
-- cento Croquembouche al giorno, piu' di un leggendario, per il solo fatto di
-- aprire l'app. Adesso la scala riparte da capo — ottavo giorno cinque, nono
-- dieci — e il giro ricomincia.
--
-- La striscia invece continua a contare: chi torna da venti giorni di fila ne
-- ha venti, non uno. E' un fatto vero e si vede nel pannello; a ripartire e'
-- solo il premio.
-- ============================================================================

drop function if exists segna_presenza();
create or replace function segna_presenza()
returns table (giorno date, striscia int, croquembouche int, prossimo int, giro int, nuova boolean)
language plpgsql security definer set search_path = public as $$
declare
	v_id uuid;
	v_oggi date;
	v_riga presenze;
	v_prima int;
	v_striscia int;
	v_premio int;
	v_prossimo int;
	v_ultimo int;
begin
	v_id := auth.uid();
	-- Chi non e' entrato, chi guarda da fuori e chi amministra: niente premio
	-- e nessun errore.
	if v_id is null or not puo_agire(v_id) then
		return;
	end if;
	if coalesce((select c.valore from game_config c where c.chiave = 'presenze_attive'), 0) = 0 then
		return;
	end if;
	-- Durante la premiazione le porte dei punti sono sbarrate: anche questa.
	if gioco_congelato() then
		return;
	end if;

	v_oggi := oggi_a_pachino();

	select max(s.passo) into v_ultimo from presenze_scala s;
	if v_ultimo is null then
		return; -- scala vuota dal pannello: e' come averli spenti
	end if;

	select * into v_riga from presenze p where p.user_id = v_id and p.giorno = v_oggi;
	if found then
		-- Gia' passato di qui oggi: si dice com'e' messo, senza rifare festa.
		select s.croquembouche into v_prossimo from presenze_scala s
		where s.passo = (v_riga.striscia % v_ultimo) + 1;
		return query select
			v_riga.giorno,
			v_riga.striscia,
			v_riga.croquembouche,
			coalesce(v_prossimo, 0),
			((v_riga.striscia - 1) / v_ultimo) + 1,
			false;
		return;
	end if;

	-- La striscia continua solo se ieri c'era. Nessun "recupero": saltare un
	-- giorno costa, ed e' il motivo per cui si torna.
	select p.striscia into v_prima from presenze p
	where p.user_id = v_id and p.giorno = v_oggi - 1;
	v_striscia := coalesce(v_prima, 0) + 1;

	-- Il gradino gira: con sette scalini, l'ottavo giorno e' di nuovo il primo.
	select s.croquembouche into v_premio from presenze_scala s
	where s.passo = ((v_striscia - 1) % v_ultimo) + 1;
	select s.croquembouche into v_prossimo from presenze_scala s
	where s.passo = (v_striscia % v_ultimo) + 1;

	insert into presenze (user_id, giorno, striscia, croquembouche)
	values (v_id, v_oggi, v_striscia, coalesce(v_premio, 0));

	return query select
		v_oggi,
		v_striscia,
		coalesce(v_premio, 0),
		coalesce(v_prossimo, 0),
		((v_striscia - 1) / v_ultimo) + 1,
		true;
end;
$$;

revoke all on function segna_presenza() from public, anon;
grant execute on function segna_presenza() to authenticated;
