-- ============================================================================
-- Pachino Express — gestione dei capitoli dal pannello
--
-- story_chapters ha le RLS accese e nessuna policy, perche' i titoli dei
-- capitoli bloccati sono l'unica cosa davvero da non far vedere. Ma allora
-- nemmeno il pannello puo' toccarla: servono funzioni apposta.
--
-- Nota onesta sul livello di protezione: l'app non ha autenticazione, quindi
-- chi conosce il nome di queste funzioni puo' chiamarle e leggersi i titoli
-- in anticipo. Non e' una cassaforte, e' un coperchio: serve a non
-- rovinarsi la sorpresa per sbaglio, non a fermare chi vuole barare. Per
-- quello servirebbe Supabase Auth, che qui non c'e' per scelta.
-- ============================================================================

create or replace function capitoli_admin()
returns setof story_chapters
language sql
security definer
set search_path = public
as $$
	select * from story_chapters order by numero;
$$;

/**
 * Aggiorna soglia e/o titolo di un capitolo. I parametri null lasciano il
 * valore com'e', tranne p_pulisci_titolo che permette di svuotarlo davvero.
 */
create or replace function imposta_capitolo(
	p_numero int,
	p_soglia int default null,
	p_titolo text default null,
	p_pulisci_titolo boolean default false
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
	if p_soglia is not null and p_soglia < 0 then
		raise exception 'La soglia non puo'' essere negativa';
	end if;

	update story_chapters
	set
		soglia = coalesce(p_soglia, soglia),
		titolo = case
			when p_pulisci_titolo then null
			else coalesce(p_titolo, titolo)
		end
	where numero = p_numero;

	if not found then
		raise exception 'Il capitolo % non esiste', p_numero;
	end if;
end;
$$;

revoke execute on function capitoli_admin() from public;
revoke execute on function imposta_capitolo(int, int, text, boolean) from public;
grant execute on function capitoli_admin() to anon, authenticated;
grant execute on function imposta_capitolo(int, int, text, boolean) to anon, authenticated;
