# Pachino Express

PWA di gamification per la vacanza a Pachino: sei amici, un PachiDex di
sfiziosita' da catturare in foto, e una valuta chiamata **Croquembouche** che
si guadagna, si perde nelle contestazioni e si scambia fra giocatori.

Estetica pixel art con chrome da sistema operativo retro; il feed si comporta
come Bluesky, cronologico e senza algoritmo.

## Cosa serve

- Node 20+
- Un progetto Supabase (piano free) — database, realtime, avatar
- Un bucket Cloudflare R2 con un dominio personalizzato — le foto delle catture
- Niente altro: la mappa e' OpenStreetMap

## Avvio

```bash
npm install
cp .env.example .env   # e riempilo, vedi sotto
npm run dev
```

### Configurare Supabase

1. Crea un progetto su [supabase.com](https://supabase.com) (free tier).
2. Da **SQL Editor**, esegui in ordine i file di `supabase/migrations/`:
   - `0001_schema.sql` — tabelle e vincoli
   - `0002_logica.sql` — viste, saldi, regole di gioco
   - `0003_rls_storage.sql` — permessi, bucket immagini, realtime
   - `0004_seed.sql` — i sei giocatori e la configurazione iniziale
   - `0005_cron.sql` — **opzionale**, chiude le contestazioni scadute da sole
   - `0006_indurimento.sql` — chiude gli avvisi del linter di sicurezza
   - `0007_r2_migrazione.sql` — restringe Storage al solo bucket `avatar`
   - `0008` e `0009` — azzeramento del gioco, compatibile con `safeupdate`
   - `0010_foto_gps.sql` — i posti diventano `foto_gps` e contestabili
   - `0011_tag.sql` — @menzioni: una foto vale per piu' giocatori
   - `0012_push.sql` — iscrizioni push e posizioni in classifica
   - `0013_cron_notifiche.sql` — podio serale e promemoria voto via pg_cron
3. Da **Project Settings > API** copia URL e `anon` key dentro `.env`:

```
PUBLIC_SUPABASE_URL="https://xxxx.supabase.co"
PUBLIC_SUPABASE_ANON_KEY="eyJ..."
```

In alternativa, con la CLI: `supabase db push`.

### Configurare Cloudflare R2

Le foto delle catture stanno su R2, non su Supabase Storage: non consumano la
quota del piano free e costano meno a crescere.

1. **Crea il bucket** — Cloudflare dashboard > R2 > Create bucket. Il nome che
   scegli va in `R2_BUCKET`.
2. **Collega il dominio** — nel bucket, Settings > Custom Domains > Connect
   Domain (es. `cdn.tuodominio.it`; serve un dominio gia' su Cloudflare DNS).
   Va in `R2_PUBLIC_BASE_URL`, senza slash finale. E' da qui che il feed legge
   le foto, quindi il bucket resta privato in scrittura ma pubblico in lettura
   solo attraverso questo dominio.
3. **Crea il token** — R2 > Manage API Tokens > Create API Token, permessi
   *Object Read & Write* ristretti a quel bucket. Ti da' Access Key ID e
   Secret Access Key, che vanno in `R2_ACCESS_KEY_ID` e
   `R2_SECRET_ACCESS_KEY`. La secret la vedi una volta sola.
4. **Account ID** — e' nella barra laterale della dashboard Cloudflare, va in
   `R2_ACCOUNT_ID`.
5. **Giurisdizione** — se accanto al nome del bucket il pannello mostra "EU",
   metti `R2_JURISDICTION="eu"`; se non mostra niente, lascia la variabile
   vuota. R2 ha endpoint separati per giurisdizione e un bucket EU **non**
   risponde da quello standard: restituisce `AccessDenied`, che sembra
   identico a una chiave sbagliata. Se l'upload da 403 e le chiavi sono
   giuste, e' quasi sempre questo.

Il browser non parla mai direttamente con R2 usando queste chiavi: chiede un
URL di upload temporaneo a `/api/upload-url`, che lo firma lato server e vale
cinque minuti. Le variabili R2 **non** sono prefissate `PUBLIC_` proprio per
questo — SvelteKit rifiuta di compilare se qualcuno prova a importarle in un
file client.

### Caricare il PachiDex

Il database parte **vuoto di contenuti di gioco**: nessun elemento e'
precaricato. Vai su `/gestione-xk29`, sezione **Import CSV**, scarica il
template e caricalo. Colonne attese:

```
nome, categoria, rarita, croquembouche, ripetibile, validazione, note, lat, lng
```

- `categoria`: `posto` | `pietanza` | `animale` | `attivita`
- `rarita`: `comune` | `raro` | `leggendario`
- `croquembouche`: se vuoto, prende il default della rarita' (10 / 25 / 60)
- `ripetibile`: `si` / `no`
- `validazione`: `foto_gps` per i checkpoint (solo categoria `posto`, richiede
  lat e lng: serve la foto **e** essere sul posto) oppure `foto`
- separatore virgola o punto e virgola, decide da solo

Le righe valide entrano anche se altre sono rotte: gli errori sono segnalati
riga per riga.

### Notifiche push

Le chiavi VAPID si generano una volta sola e vanno in `.env` e su Vercel:

```bash
node -e "console.log(require('web-push').generateVAPIDKeys())"
```

Poi va detto al database dove sta l'app e con quale segreto bussare, perche'
le notifiche a orario partono da pg_cron dentro Supabase. Dal **SQL Editor**,
una volta sola:

```sql
update push_config set valore = 'https://tuo-progetto.vercel.app' where chiave = 'app_url';
update push_config set valore = 'lo-stesso-CRON_SECRET-che-sta-su-vercel' where chiave = 'cron_secret';
```

`push_config` ha le RLS attive e nessuna policy: nessun client puo' leggerla,
il segreto resta dentro il database.

> **Su iPhone le notifiche arrivano solo se la PWA e' installata sulla
> schermata Home.** In Safari come scheda normale l'API non esiste proprio —
> non e' un permesso negato, e' assente. Serve iOS 16.4+ e ognuno dei sei deve
> fare "Aggiungi a schermata Home", altrimenti non riceve niente e non capisce
> perche'. L'app se ne accorge e lo spiega, invece di dire "non supportato".

Cosa fa suonare il telefono:

| Quando | A chi |
|---|---|
| Qualcuno cattura qualcosa | A tutti gli altri, accorpate: le catture ravvicinate si sovrascrivono invece di impilarsi |
| Ti taggano in una foto | Solo a te, e sostituisce quella generica |
| Ti contestano | Al contestato |
| C'e' da votare | A tutti tranne contestato e contestante |
| La contestazione si chiude | A tutti, con l'esito |
| Mancano 2 ore al voto | Solo a chi non ha ancora votato |
| Ricevi Croquembouche | A chi li riceve |
| Ti superano in classifica | A chi viene superato |
| Ogni sera alle 22:30 | Il podio, con la posizione di ciascuno |

Il testo dei messaggi si compone **lato server leggendo dal database**: il
client dice solo "e' successa la cosa X", cosi' nessuno puo' far arrivare agli
altri una notifica che dice quello che gli pare.

## Deploy su Vercel

Importa il repo su Vercel: rileva SvelteKit da solo, non serve configurare
build command o output directory.

Poi, in **Settings > Environment Variables**, incolla tutte e dodici le
variabili di `.env.example` con i valori veri (Production, Preview e
Development). Da li' in poi ogni push su `main` fa il deploy.

Quasi tutta l'app viene pubblicata come file statici — 13 pagine
prerenderizzate — e resta **una sola funzione serverless**, `/api/upload-url`,
che esiste solo per firmare gli upload verso R2.

Le due variabili `PUBLIC_*` finiscono nel bundle client: e' voluto, la anon key
di Supabase e' pensata per stare li' ed e' protetta dalle RLS. Le sei `R2_*`
no: restano solo lato server, e la secret key di R2 in particolare va trattata
come una credenziale vera, perche' chi la ottiene puo' svuotare il bucket.

## Regole del gioco

| Cosa | Come |
|---|---|
| Posti | **Foto + GPS**: serve lo scatto *e* stare nel raggio configurato |
| Pietanze, animali, attivita | Foto e autocertificazione |
| Contestabilita' | Tutto e' contestabile, posti compresi: il GPS prova che c'eri, non che la foto valga qualcosa |
| Elementi ripetibili | Catturabili all'infinito, sempre a valore pieno |
| Tag @menzione | Scrivi `@nome` nella didascalia e la foto vale anche per lui: stessi Croquembouche, stesso sblocco nel PachiDex |
| Contestazione | Costa 1 ✦ a chi la apre, comunque vada |
| Chi perde | Lascia altri 15 ✦ (contestato se cade la cattura, contestante se regge) |
| Voto | Vota chiunque tranne il contestato: con 6 profili sono 5 voti, mai parita' |
| Scadenza | 24 ore senza maggioranza: la cattura resta valida |
| Scambi | I Croquembouche si passano fra giocatori, con causale |

Tutti i valori sono modificabili dal pannello admin. Costo e penalita' vengono
**congelati all'apertura** di ogni contestazione: cambiare le regole a meta'
vacanza non riscrive il passato.

Il saldo non e' un contatore salvato ma una vista calcolata dagli eventi
(`v_saldi`), quindi non puo' andare in drift.

Sui tag valgono tre regole che vale la pena sapere a cena:

- Un elemento **non ripetibile vale una volta sola per persona**, comunque le
  arrivi. Se Gu la granita l'ha gia' presa da solo, farsi taggare in quella di
  un altro non gli aggiunge niente.
- Se la foto viene contestata e bocciata, **i punti svaniscono per tutti** i
  taggati: la foto e' una sola, cade tutta insieme.
- La **penalita' la paga solo chi ha pubblicato**, non i taggati: e' lui che
  ci ha messo la faccia, e gli altri potrebbero non sapere nemmeno di esserci.

## Pannello admin

`/gestione-xk29` — nessuna password, solo un indirizzo poco indovinabile.
Responsive: tabelle da desktop, card da telefono.

Import CSV · gestione elementi · regole e valori · contestazioni con override
manuale · giocatori · annullamento scambi · azzeramento del gioco.

## Note tecniche

- **Quasi tutto statico** (`adapter-vercel` con `ssr:false` e `prerender:true`):
  le pagine sono file, non funzioni, quindi niente cold start sul percorso che
  usano i giocatori. L'unica funzione serverless e' `/api/upload-url`.
- **Realtime** su catture, contestazioni, voti, reazioni e scambi: un solo
  canale, niente polling.
- **Offline**: le catture finiscono in coda su IndexedDB e ripartono da sole
  quando la rete torna. Serve, dalle parti di Vendicari.
- **Foto** ridimensionate e ricompresse nel browser prima dell'upload, poi
  caricate su R2 con un URL firmato valido cinque minuti; il service worker le
  tiene in cache. L'URL si richiede a ogni tentativo, cosi' una coda rimasta
  ferma per ore senza rete non resta bloccata su una firma scaduta.
- **Leaflet** e' in un chunk a parte (~43 KB gz): lo scarica solo chi apre la
  mappa.
- **Niente autenticazione**: il profilo si sceglie da una lista e resta in
  localStorage. Chiunque abbia la anon key puo' scrivere sul database. E' un
  gioco fra sei amici, il rischio e' proporzionato; se un giorno servisse
  davvero, la strada e' Supabase Auth con magic link e policy su `auth.uid()`.
  Le credenziali R2 sono un discorso diverso e stanno solo lato server: una
  chiave di scrittura su un bucket e' un rischio di tutt'altro peso.

## Icone

Sono generate, non disegnate a mano:

```bash
node scripts/gen-icons.mjs
```

Un croquembouche su griglia 32×32 scalato a numeri interi, cosi' i pixel
restano quadrati. Per cambiarlo, si toccano i numeri dentro lo script.
