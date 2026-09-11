-- ============================================================================
-- Pachino Express — due porte rimaste aperte
--
-- Vengono da una revisione di sicurezza. Non c'entrano niente l'una con
-- l'altra se non il fatto che sono l'ultima roba aperta che restava.
-- ============================================================================

-- --- 1. il bucket avatar accettava scritture da chiunque ---------------------
-- Le policy sono quelle della 0007: "to anon, authenticated" con come unica
-- condizione bucket_id = 'avatar'. Nessun controllo di proprieta', nessun
-- auth.uid(). Con la chiave anonima — che sta nel bundle del client, e quindi
-- ce l'hanno tutti — si caricavano e si cancellavano oggetti nel bucket.
--
-- Sono sopravvissute alla grande pulizia della 0027 per un dettaglio: quel
-- ciclo itera "pg_policies where schemaname = 'public'" e costruisce i nomi
-- come public.%I, quindi lo schema storage non e' mai stato toccato. Tutto il
-- resto del database e' stato chiuso e questa e' rimasta com'era dal 2026.
--
-- Si tolgono tutte e quattro, lettura compresa: l'app non usa piu' Supabase
-- Storage da nessuna parte. Le foto delle catture stanno su R2 (0007), e gli
-- avatar sono PNG impacchettati da Vite e cercati per nome del giocatore
-- (src/lib/avatars.ts) — la colonna users.avatar non la legge piu' nessuno.
-- Senza policy, RLS nega tutto a chiunque: e' la posizione giusta per una
-- tabella che il gioco non tocca.
--
-- ATTENZIONE, resta un passo a mano: i bucket non si cancellano da SQL,
-- perche' Supabase lo impedisce con un trigger (storage.protect_delete).
-- Vanno eliminati dalla dashboard, Storage > il bucket > elimina. Sono due,
-- 'avatar' e 'catture' — quest'ultimo la 0007 diceva gia' di toglierlo e c'e'
-- ancora. Finche' restano li' sono vuoti e inerti, ma sono superficie che non
-- serve a niente.
drop policy if exists "lettura pubblica immagini" on storage.objects;
drop policy if exists "caricamento immagini" on storage.objects;
drop policy if exists "sostituzione immagini" on storage.objects;
drop policy if exists "rimozione immagini" on storage.objects;

-- --- 2. chiudi_premio era l'unica funzione senza cancello --------------------
-- La 0027 e la 0033 hanno messo un guscio di controllo davanti a tutte le
-- funzioni potenti. chiudi_premio e' sfuggita a tutte e due: security
-- definer, mai revocata da PUBLIC, e dentro non controlla ne' chi chiama, ne'
-- che il premio sia quello in ballo, ne' che il minuto di voto sia scaduto.
--
-- Con una cerimonia avviata bastavano due chiamate — vota te stesso, chiudi
-- subito il premio — per intestarsi tutti i premi della serata, e a chi
-- guarda da fuori bastava la seconda per farla finire in anticipo.
--
-- La premiazione non e' in programma, quindi si sceglie la via corta: la
-- funzione si rinomina interna e si toglie il permesso di eseguirla, come
-- tutte le altre. Nessun guscio, perche' un guscio senza nessuno che lo usa
-- e' solo altro codice da mantenere.
--
-- SE UN GIORNO LA PREMIAZIONE TORNA: la pagina /finale chiama chiudi_premio
-- da ogni telefono, quindi con questa migrazione applicata la cerimonia si
-- pianta al primo premio. Va rimesso un guscio, sul modello della 0033, che
-- pretenda "sono_admin() or puo_agire(auth.uid())" e soprattutto verifichi
-- che p_premio sia il premio con numero = finale.premio_numero e che
-- now() >= finale.apertura + secondi_voto (oppure che abbiano gia' votato
-- tutti). L'idempotenza delle chiamate in contemporanea non si perde: la
-- resta il controllo sull'esito gia' scritto, dentro la funzione interna.
do $$ begin
	alter function chiudi_premio(uuid, uuid) rename to chiudi_premio_interna;
exception when others then null; -- gia' rinominata: la migrazione si ripete
end $$;

revoke all on function chiudi_premio_interna(uuid, uuid) from public, anon, authenticated;
