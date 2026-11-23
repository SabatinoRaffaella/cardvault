# Pokoin Mobile Rebuild

Client Flutter mobile del fork `SabatinoRaffaella/cardvault`, branch `AppMobile`. Versione: **1.3.0+65**; punto di ingresso `lib/rebuild/main_mobile_prototype.dart`.

## Aggiornamento 1.3.0 — cache immagini

Corretto l'accumulo di immagini residue su disco: la pulizia usa lo stesso
filesystem dei download e rimuove il file prima del riferimento nell'indice.
All'avvio vengono riconciliati i residui della sola cartella immagini.
Budget: 64 MB di contenuto, massimo 240 immagini e 30 giorni di inutilizzo;
i download in corso possono superare temporaneamente il budget prima della
manutenzione aggregata. Dettagli in [Cache Rebuild](lib/rebuild/cache/README.md).

Sul dispositivo controllato sono stati rimossi 2.254 file senza riferimento,
liberando 167,5 MB allocati. Dopo l'avvio dell'aggiornamento: 240 file e 240
record, nessun residuo, circa 22,5 MB allocati per le immagini. I dati
persistenti confrontati sono rimasti identici dopo l'installazione con `-r`.
Queste sono misure di un dispositivo; il difetto verificato riguarda lo spazio
su disco, senza evidenza di un leak della RAM. Carte, account, carrello e
scanner non vengono cancellati dalla pulizia.

La versione include anche lo swipe orizzontale del Checkout già presente
nell'APK locale. La release [v1.3.0](https://github.com/SabatinoRaffaella/cardvault/releases/tag/v1.3.0)
riporta commit sorgente e SHA256 dell'APK profile ARM64. Analisi statica dei
file cache e compilazione verificate; nessuna nuova suite di test eseguita
per questo hotfix.

## Sviluppo

```powershell
flutter pub get
flutter run --target lib/rebuild/main_mobile_prototype.dart -d <device-id>
```

Vedere [INSTALLATION.md](INSTALLATION.md) per ambiente Android, asset scanner non versionati e consegna APK. Il codice attivo segue Provider/DAO -> Service -> Controller -> Presentation; le schermate sono in `lib/rebuild/presentation/`, con `component/` e `atomics/`; gli stili in `style/`.

`lib/old/` conserva il precedente client e i suoi import condizionali web come riferimento. Non e il target della build mobile. I progetti iOS e desktop Flutter restano disponibili, ma questa pulizia e verificata con la build Android ARM64.

## Funzionalita e documentazione

- [Account e profilo](docs/rebuild-account.md).
- [Ricerca Marketplace](docs/rebuild-marketplace-search.md) e [caricamento caroselli](docs/rebuild-discovery-loading.md).
- [Cardex e Portfolio](docs/rebuild-cardex.md).
- [Carrello, persistenza e Checkout a bundle](docs/rebuild-cart.md).
- [Scanner](docs/rebuild-scanner.md) e [asset locali richiesti](assets/README-scan-assets.md).
- [Identificativi pubblici delle carte](docs/marketplace-public-ids.md), [API](docs/pokoin-api.md) e [contratti delle pagine](docs/react-page-apis.md).

La 1.2.1 include finestra centrale compatta per offerte/venditori, palette crema/marrone/oliva, carosello di carte verticali con gruppo attivo centrale e vicini in prospettiva. Sfoglia cambia gruppo al tocco; Lente apre le informazioni. La pressione lunga mostra la checkbox del solo gruppo attivo; trascinamento in alto, Annulla e cambio laterale dei bundle restano disponibili. Il Checkout e ancora un riepilogo senza invio ordini/pagamenti.

## Dipendenze esterne preservate

Il client legge le API remote (`https://api.pokoin.com` nei provider che espongono `MARKETPLACE_API_BASE_URL`) e usa Firebase Auth/Firestore con le configurazioni esistenti. Modelli scanner e indici CNN vengono forniti separatamente e restano esclusi da Git. Nessun servizio server e incluso nella compilazione Android.

Manteniamo `lib/`, tutti gli asset del manifest, i progetti nativi Flutter, `pubspec.yaml`/lock, Firebase e le regole Firestore, tutti i test Flutter e il generatore del dizionario locale. Il logo SVG condiviso e in `assets/brand/pokoin.svg`, gia identico alla vecchia copia web.

## Pulizia del sito/backend

Il controllo ha trovato 1.516 riferimenti Dart locali e nessun import verso i file server/sito candidati alla rimozione. Sono stati rimossi 894 file versionati: API/server Node, SQL/Prisma/Supabase, pagine web, configurazioni Vercel/Cloudflare, artefatti di revisione immagini e script server/deploy/importazione, inclusi i relativi test esclusivamente backend. I test Flutter e il progetto isolato delle regole Firestore sono conservati.

Non cambiano endpoint, autenticazione, policy di cache o codice applicativo Rebuild. I contratti API sono documentazione del servizio esterno, non un server locale da avviare. La documentazione storica puo citare file server: recuperare la versione al tag `v1.2.1` o consultare `upstream`, senza ricreare un backend in questo fork. File ignorati e configurazioni locali non vengono eliminati dalla pulizia dei sorgenti.

Il tag `v1.2.1` conserva lo stato iniziale, senza riscrittura della cronologia.
Su richiesta dell'utente, l'APK allegato alla stessa release e stato aggiornato
alla build del Checkout verticale descritta sopra, con versione invariata `1.2.1+64`.
Le note della release indicano il commit sorgente esatto dell'APK.
Dimensione: 103839245 byte. SHA256:
`6031BBF877BC07CD501E28FE12FC81536AFC40F0D268F1D32B22CC2025981614`.

Verifica dopo la rimozione: analisi statica di `lib/rebuild` senza problemi; build profile ARM64 riuscita tramite helper standard. Controllati il logo condiviso nel pacchetto, la rimozione del vecchio percorso web e il motore Flutter ARM64. Confrontati 578 file client/native/asset/test: cambia solo il percorso del logo legacy. Nessuna suite di test eseguita per questa pulizia. Il funzionamento dei servizi remoti non e provato dalla sola compilazione; endpoint e client Rebuild sono invariati.
