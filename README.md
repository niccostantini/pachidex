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

## Deploy su Vercel

Importa il repo su Vercel: rileva SvelteKit da solo, non serve configurare
build command o output directory.

Poi, in **Settings > Environment Variables**, incolla tutte e otto le
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
