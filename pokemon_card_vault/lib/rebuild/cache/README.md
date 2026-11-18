# Cache Rebuild

- `marketplace_home_cache.dart`: snapshot versionato dei due caroselli, massimo
  12 espansioni e 12 carte. Le due sezioni hanno date indipendenti e vengono
  conservate per 7 giorni. Al riavvio sono mostrate prima dell'aggiornamento.
  Una copia completa salvata da meno di 5 minuti viene riutilizzata senza GET;
  Riprova forza l'aggiornamento. Una copia parziale non evita il caricamento.
  Il ripristino attende al massimo 280 ms: letture come quelle da 252–260 ms
  misurate sul telefono possono completarsi senza richieste ai metadati.
  Appena la lettura termina si prosegue, senza un'attesa fissa di 280 ms.
- `marketplace_image_cache.dart`: unica istanza della cache immagini, massimo
  240 file e rimozione dei file non utilizzati per 30 giorni. I widget lazy
  richiedono le immagini nel viewport, senza margine di precache
  dell'intero catalogo.
  Il manager consente al massimo 2 download contemporanei.
- `collection_artwork_cache.dart`: fino a 200 manifest pubblici delle scansioni
  delle carte effettivamente viste, conservati 7 giorni. Evita le GET per carta
  al riavvio quando il manifest salvato è valido; non memorizza errori o prezzi.
  La lettura locale ha un budget di 280 ms, senza bloccare i dati del proprietario.
- `collection_preview_cache.dart`: le prime 24 anteprime di ciascuna schermata
  Portfolio/Cardex, nello stesso ordine dell'ultimo caricamento completo, per
  7 giorni. I due elenchi sono separati; scroll e ricostruzioni dei widget non
  modificano ordine o contenuto della cache. Lo schema v2 ignora la precedente
  cache di recenza, che poteva contenere carte di pagine successive. Conserva solo l'ultimo
  account e ripristina solo dopo averne ricevuto lo stesso UID dalla sessione.
  Non salva quantità, prezzi, attributi di vendita, ID delle copie o credenziali.
  Le anteprime sono marcate `fromCache`, restano in caricamento e non costituiscono
  prova di possesso o un target per lo switch. Le richieste autorevoli partono in
  parallelo; il loro risultato completo sostituisce la cache anche quando è vuoto.
  Cardex mantiene l'anteprima durante la riconciliazione Held; Portfolio può già
  usare i listing completi. Vengono salvati soltanto i metadati del prefisso già
  ricevuto: le immagini mantengono il caricamento lazy delle sole carte visibili.
  I cambi Listing/Collection o i
  salvataggi dello scanner invalidano l'anteprima prima di ricaricare.
  Le scritture sono aggregate e serializzate, senza attendere il disco nella UI.
- `marketplace_search_cache.dart`: cache solo in memoria per 30 secondi,
  massimo 16 pagine riuscite e due cataloghi artista preparati. Le chiavi delle
  pagine comprendono testo, lingua, tipo di articolo, offset e limite. Una
  ricerca ripetuta fresca ricompare subito; invio e Riprova aggiornano la pagina.
  Non conserva gli errori e si perde quando l'app viene chiusa.

I DAO sotto `provider/` gestiscono directory e file. Le cache su disco risiedono nella
cartella privata di supporto dell'app, sotto `rebuild-cache/metadata/` e
`rebuild-cache/images/`, e sopravvivono ai normali riavvii. Cancellare i dati
dell'app o disinstallarla elimina anche la cache. La cache è una copia di
presentazione: l'API resta la fonte per gli aggiornamenti.

L'entry point Rebuild carica automaticamente la discovery all'apertura:
i contenuti salvati sono ripristinati prima delle richieste di aggiornamento.
Una copia completa recente evita le GET dei metadati; al primo avvio serve
la rete. Le immagini restano lazy, con massimo due download contemporanei.
`autoLoadDiscovery: false` rimane disponibile per i test diagnostici, ma
non è usato dall'entry point dell'app.
