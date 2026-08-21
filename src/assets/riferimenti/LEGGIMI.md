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

## Dimensioni: lascia fare allo script

Butta dentro i file come li hai scaricati, di qualsiasi peso, poi:

```bash
node scripts/prepara-riferimenti.mjs
```

Ridimensiona a **720px di lato lungo** e ricomprime tutto in WebP, riportando
prima e dopo. In pratica una foto scaricata da 700KB-3MB finisce fra i 10 e i
50KB, senza differenze visibili a schermo.

Due dettagli che contano:

- **Non ingrandisce mai.** Un'immagine gia' piccola resta della sua dimensione:
  gonfiarla aggiungerebbe peso e zero dettaglio.
- **Non ritocca quello che e' gia' a posto.** Un WebP gia' entro i limiti viene
  saltato, perche' ricomprimerlo a ogni giro perderebbe qualita' per niente.

Modifica i file sul posto e cancella gli originali dopo la conversione: la rete
di sicurezza e' git, quindi committa prima di lanciarlo se vuoi poter tornare
indietro.

Serve `cwebp` (`brew install webp`). Senza, ripiega su JPEG e te lo dice.

## Perche' vanno tenute leggere

Finiscono nel bundle e nel **precache del service worker**: i sei telefoni le
scaricano tutte insieme all'installazione. In cambio si vedono anche senza
campo, che alla riserva e' la norma piu' che l'eccezione.

## Licenze

Se prendi foto da internet, controlla la licenza. Wikimedia Commons va bene
per quasi tutti gli animali italiani, ma diverse immagini chiedono
l'attribuzione: mettila nel campo `note` dell'elemento.
