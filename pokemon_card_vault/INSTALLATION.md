# Installazione mobile

## Prerequisiti

- Flutter/Dart compatibili con `pubspec.yaml` e `pubspec.lock`.
- Android Studio, Android SDK e JDK compatibili con la configurazione Gradle presente.
- Telefono Android ARM64 con Android 8/API 26 o superiore, USB debugging autorizzato, oppure dispositivo adatto al comando Flutter scelto.
- Accesso alle API Pokoin e ai servizi Firebase per le funzioni online.

## Sorgenti

```powershell
git clone --branch AppMobile https://github.com/SabatinoRaffaella/cardvault.git
cd cardvault/pokemon_card_vault
flutter pub get
flutter devices
flutter run --target lib/rebuild/main_mobile_prototype.dart -d <device-id>
```

Non serve installare il vecchio package npm del server o avviare un database locale. Il dizionario dei suggerimenti e gia incluso; `scripts/generate-suggest-dictionary.mjs` serve solo per rigenerarlo dalla sorgente esterna fissata nel suo manifest.

## Scanner

Per la build sono necessari anche i file descritti in [assets/README-scan-assets.md](assets/README-scan-assets.md): detector TFLite, modello CNN ONNX e indici western/japanese/chinese nei percorsi del manifest Flutter. Sono asset locali esclusi da Git e non arrivano con il clone. Usare il pacchetto Android originale; nessun download automatico o sostituzione di modello viene introdotto.

Conservare `lib/firebase_options.dart`, `android/app/google-services.json` e le impostazioni native esistenti. Le configurazioni del client identificano il progetto remoto; non inserire credenziali amministrative del backend nella app. Chiavi di firma e impostazioni SDK personali restano locali.

## APK di consegna

Da PowerShell, nella cartella del progetto:

```powershell
./scripts/build-emulator-apk.ps1
```

Il default genera il main Rebuild in modalita profile ARM64, verifica ABI/hash e mantiene un solo APK corrente:

`build/app/outputs/flutter-apk/Rebuild/pokoin-profile-phone-arm64-Rebuild.apk`

Lo storico contiene al massimo tre versioni precedenti distinte. La build non installa automaticamente la app. Il percorso Flutter locale di default e configurabile con `-FlutterPath`.

Questa e una consegna profile per telefono, distinta da una build release firmata per Play Store. La pulizia della repository non cambia la versione `1.2.1+64` e non sostituisce il file gia allegato alla release GitHub `v1.2.1`.
