# Pachino Express

PWA di gamification per la vacanza a Pachino: sei amici, un PachiDex di
sfiziosita' da catturare in foto, e una valuta chiamata **Croquembouche** che
si guadagna, si perde nelle contestazioni e si scambia fra giocatori.

Estetica pixel art con chrome da sistema operativo retro; il feed si comporta
come Bluesky, cronologico e senza algoritmo.

## Cosa serve

- Node 20+
- Un progetto Supabase (piano free)
- Niente altro: la mappa e' OpenStreetMap, l'hosting e' statico

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
3. Da **Project Settings > API** copia URL e `anon` key dentro `.env`:

```
PUBLIC_SUPABASE_URL="https://xxxx.supabase.co"
PUBLIC_SUPABASE_ANON_KEY="eyJ..."
```

In alternativa, con la CLI: `supabase db push`.

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
- `validazione`: `auto_gps` (solo per i posti, richiede lat e lng) oppure `foto`
- separatore virgola o punto e virgola, decide da solo

Le righe valide entrano anche se altre sono rotte: gli errori sono segnalati
riga per riga.

## Deploy

Build statica, gira ovunque:

```bash
npm run build     # esce in build/
```

- **Vercel**: importa il repo, framework SvelteKit, aggiungi le due variabili
  d'ambiente. Nient'altro.
- **Netlify**: publish directory `build`, stesse variabili.

Le variabili sono `PUBLIC_*`, quindi finiscono nel bundle: e' voluto, la anon
key e' pensata per stare nel client.

## Regole del gioco

| Cosa | Come |
|---|---|
| Posti | Validati dal GPS entro il raggio configurato. **Non contestabili.** |
| Pietanze, animali, attivita | Foto e autocertificazione. **Contestabili.** |
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
manuale · giocatori e sprite avatar · annullamento scambi.

## Note tecniche

- **SPA statica** (`adapter-static` con fallback): nessun server, nessun cold
  start, stesso artefatto su qualsiasi host.
- **Realtime** su catture, contestazioni, voti, reazioni e scambi: un solo
  canale, niente polling.
- **Offline**: le catture finiscono in coda su IndexedDB e ripartono da sole
  quando la rete torna. Serve, dalle parti di Vendicari.
- **Foto** ridimensionate e ricompresse nel browser prima dell'upload; il
  service worker le tiene in cache.
- **Leaflet** e' in un chunk a parte (~42 KB gz): lo scarica solo chi apre la
  mappa.
- **Niente autenticazione**: il profilo si sceglie da una lista e resta in
  localStorage. Chiunque abbia la anon key puo' scrivere. E' un gioco fra sei
  amici, il rischio e' proporzionato; se un giorno servisse davvero, la strada
  e' Supabase Auth con magic link e policy su `auth.uid()`.

## Icone

Sono generate, non disegnate a mano:

```bash
node scripts/gen-icons.mjs
```

Un croquembouche su griglia 32×32 scalato a numeri interi, cosi' i pixel
restano quadrati. Per cambiarlo, si toccano i numeri dentro lo script.
