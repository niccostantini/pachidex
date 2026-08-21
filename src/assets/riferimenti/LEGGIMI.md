# Foto di riferimento

Immagini che mostrano **com'e' fatto** un elemento, per chi non lo sa
riconoscere. Servono soprattutto per gli animali: una folaga non la conoscono
tutti.

## Come si aggiungono

1. Metti il file qui dentro. Formati accettati: `.webp`, `.jpg`, `.png`.
2. Nel CSV, la colonna `riferimento` porta il **nome del file senza
   estensione**, tutto minuscolo.

```
nome,categoria,rarita,croquembouche,ripetibile,validazione,note,lat,lng,riferimento
Folaga,animale,raro,25,no,foto,Nera col becco bianco,,,folaga
```

Il file `folaga.webp` viene agganciato da solo: non c'e' nessun elenco da
tenere aggiornato nel codice.

## Dimensioni

Vengono impacchettate nell'app e precaricate dal service worker, cosi'
funzionano anche senza campo — che nella riserva e' la norma. Per questo
conviene tenerle leggere: **640px di lato lungo, sotto i 60KB**.

Per sistemare in blocco quello che hai scaricato:

```bash
node scripts/prepara-riferimenti.mjs
```

Ridimensiona e ricomprime tutto quello che trova qui dentro, riportando
prima e dopo.

## Licenze

Se prendi foto da internet, controlla la licenza. Wikimedia Commons va bene
per quasi tutti gli animali italiani, ma diverse immagini chiedono
l'attribuzione: mettila nel campo `note` dell'elemento.
