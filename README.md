# Pokoin Mobile

Fork mobile mantenuto in [SabatinoRaffaella/cardvault](https://github.com/SabatinoRaffaella/cardvault), branch predefinito `AppMobile`.

Il progetto Flutter vive in `pokemon_card_vault/`; il punto di ingresso attivo e `lib/rebuild/main_mobile_prototype.dart`. Versione corrente: **1.2.1+64**.

## Avvio Android

```powershell
cd pokemon_card_vault
flutter pub get
flutter run --target lib/rebuild/main_mobile_prototype.dart -d <device-id>
```

Per prerequisiti, modelli locali dello scanner e APK leggere [INSTALLATION.md](pokemon_card_vault/INSTALLATION.md).

## Confine del fork

Questa copia contiene il client mobile, i progetti nativi Flutter, gli asset, i test Flutter e i contratti API utili al client. Le implementazioni server, le migrazioni del database, il sito HTML, i worker CDN e gli script di deploy/importazione sono stati rimossi dal branch mobile dopo il controllo delle dipendenze. Il tag `v1.2.1` conserva lo stato precedente alla pulizia.

Marketplace, account, collezione e scanner continuano a usare i servizi remoti gia configurati. Rimuovere una copia locale del server non spegne quei servizi e non rende autonoma offline la app. Il repository originale resta disponibile tramite il remote `upstream`; `origin` punta a questo fork. Le modifiche upstream vengono integrate soltanto con una operazione Git esplicita.

## Struttura

- `pokemon_card_vault/lib/rebuild/`: codice mobile attivo.
- `pokemon_card_vault/lib/old/`: precedente client Flutter, conservato come riferimento insieme ai suoi test.
- `pokemon_card_vault/assets/`, `android/`, `ios/`: risorse e progetti nativi.
- `pokemon_card_vault/docs/`: funzionalita mobile e contratti API di riferimento.
- `pokemon_card_vault/scripts/`: build APK, dizionario locale, diagnostica e test isolati delle regole Firestore.
- `pokemon_card_vault/firestore.rules`: riferimento delle regole di accesso ai dati usati dal client; nessun deploy automatico.

La documentazione operativa del client e in [pokemon_card_vault/README.md](pokemon_card_vault/README.md). La release [1.2.1](https://github.com/SabatinoRaffaella/cardvault/releases/tag/v1.2.1) e il suo APK pubblicato restano invariati.
