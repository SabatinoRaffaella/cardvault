# Agent instructions (Pokoin / CardVault)

## Mobile app working branch (user workflow)

- `AppMobile` is the user-requested working branch for this mobile app checkout.
- It replaces `codex/search-images-mobile-filters`; keep local work tracking
  `origin/AppMobile` after the GitHub branch rename.
- Do not merge into `main`, force-push, publish releases or deploy production
  unless the user explicitly requests it.
- Keep APKs, generated caches and machine-local Android SDK configuration out
  of source commits. Continue the local APK and Obsidian workflows below.

## Previous application reference (2026-10-16)

- On `AppMobile`, the previous application folders live under `lib/old/`.
- Keep active mobile work under `lib/rebuild/`; use `lib/old/` as reference.
- `lib/old/main.dart` is the previous application's entry point. Rebuild starts
  from `lib/rebuild/main_mobile_prototype.dart`; choose the target explicitly.
- Shared `lib/firebase_options.dart` stays at the `lib/` root.
- Legacy Flutter tests use the `old/` paths; server-side generators live upstream.

## Mobile Rebuild architecture (user preference)

- The user chose the Service -> Controller -> Presentation structure, refined
  on 2026-10-09 to group UI files by screen under `lib/rebuild/presentation/`.
  Follow this structure for new work and incremental refactors.
- User refinement on 2026-10-08: introduce a `provider/` data-access/DAO layer.
  Requests flow Screen/Component -> Controller -> Service -> Provider/DAO ->
  backend/local storage; typed models/results flow back through these layers,
  and controllers expose the resulting presentation state to the UI.
- `model/`: data entities and presentation-state snapshots. Models represent
  backend data; they do not perform network or storage access.
- `constants/`: shared compile-time labels, lookup tables and static metadata,
  grouped into feature-specific Dart files (for example expansion era titles).
  Keep these values out of services/controllers; constants must not depend on
  UI, services or storage. Do not turn this into a single unrelated strings file
  or move runtime configuration/secrets here.
- `provider/`: read/write API, Hive, Firestore or other storage through focused
  DAO-style classes. Convert stored/API data into typed models and expose
  asynchronous results via Future/Stream. Providers do not depend on UI,
  controllers or services. This project-specific name is distinct from
  Riverpod providers used for state management in the legacy `lib/old/providers/`.
- `service/`: data operations, domain rules and coordination of providers,
  including local/remote persistence and reconciliation when needed. Keep
  services free of `BuildContext`, navigation, dialogs and widget construction.
  Introduce this separation incrementally; the legacy CartNotifier combines
  persistence, synchronization and UI state, so extract its storage operations
  rather than reusing the whole notifier as a DAO.
- `cache/`: cache policies, versioned snapshots, expiry and shared image-cache
  configuration, as requested on 2026-10-09. File and directory access belongs
  to `provider/`; background cache writes must not delay presentation or retry.
- `controller/`: coordinate services, expose state and actions, and handle
  loading, retries, filtering and notifications without constructing UI.
  Keep focused controllers such as `CartController` for distinct responsibilities;
  `CartService` retains cart data and calculations.
- `presentation/<screen>/<screen>.dart`: compose the view, bind controller
  state/actions, and manage UI
  lifecycle, layout, input, dialogs and routing. Delegate data operations to
  controllers rather than calling services directly.
- `presentation/<screen>/component/`: intermediate presentation widgets that
  compose sections from atomics, preferably receiving data and
  callbacks. A reactive component can observe its dedicated controller, as the
  cart sheet does; components should not access services directly.
- `presentation/<screen>/atomics/`: small reusable building blocks such as
  fields, badges, panels and images. The former `widget/` folder is replaced
  by `atomics/`; complete sections belong to `component/` instead.
- `presentation/shared/`: components, atomics and presentation helpers used
  by multiple screens, including navigation, the cart sheet and thumbnails.
  Shared widgets must not depend on a screen-specific component for helpers.
- Keep page palettes and themes in the dedicated `style/` folder, as requested
  on 2026-10-08. Controllers, services, providers and models remain outside
  presentation. Wire dependencies and ownership at the app/feature entry point.

## Local Rebuild phone APK (user workflow)

- Latest user update on 2026-10-17: keep one current handoff APK at
  `build/app/outputs/flutter-apk/Rebuild/pokoin-profile-phone-arm64-Rebuild.apk`.
  Keep at most three distinct preceding versions in `build/emulator-apk-backups/`.
  Do not create extra exported copies or unlimited historical APK backups.
  This supersedes both the old unlimited history and the earlier no-history policy.
- After changes affecting the Flutter app, Android configuration, dependencies
  or bundled assets, refresh the profile ARM64 phone APK before handing off.
  Do not build additional variants by default.
- From `pokemon_card_vault/`, run `./scripts/build-emulator-apk.ps1`.
  Its defaults select `lib/rebuild/main_mobile_prototype.dart`, `android-arm64`,
  `profile`, and the single final path above. Explicit equivalent parameters
  remain supported. Other destination directories are rejected.
- The helper builds, verifies the packaged ARM64 Flutter engine and SHA256,
  then moves the generated Flutter APK into the final path. A different final
  APK is replaced only after preserving/verifying the preceding distinct version.
  After successful promotion, trim this APK's hash-named history to three
  distinct preceding versions; do not retain a duplicate of the current APK.
  Build/ABI failures preserve the existing final APK and do not prune history.
- The user explicitly authorized deleting older generated APK versions and
  retaining this small history. Only prune this helper's known hash-named APK
  history; do not bulk-delete unrelated variants or recursively delete build
  internals, source or configuration files. Keep the current Android Studio
  debug APK and Flutter/Gradle internal outputs.
- Do not edit APK Analyzer extracts or Android Studio project files.
- Request execution/write approval when the sandbox requires it. If the build,
  promotion or verification fails, report it without claiming an updated APK.
- This is a local profile artifact, not a release or production deployment.
  It does not install the APK on a device unless the user asks for installation.

## Local notes and Obsidian updates (user workflow)

- Latest user preference, 2026-10-22: reduce generated documentation and group
  it by macro feature. Read `../../notes/README.md` and update existing feature
  documents instead of adding a note, Event or dated staging folder per edit.
- Current local note entry points live under `../../notes/`: account, cardex,
  marketplace, scanner, cart, android-apk, architecture and performance.
  They are workspace indexes; the repo documents remain operational truth.
- Reuse `build/obsidian/<feature>/` for helper scripts, staging and compact
  snapshots of affected text files. Do not create top-level Cardvault folders
  such as `*-docs-YYYYMMDD`, `*-notes-staging-*` or `obsidian-*-backup-*`.
- Update the existing relevant feature note in the local Obsidian vault for a
  meaningful behavioral/architectural change. Minor fixes, class-level edits,
  style tweaks, routine QA and this local workspace cleanup do not require a
  new Permanent note or dated Event. One new page/Event is appropriate only
  for an independent macro feature, significant milestone or explicit request.
- The vault remains `C:\Users\raffa\Documents\Obsidian\Pokoin Collaborator\Pokoin`.
  Do not reorganize existing vault notes as part of a Cardvault-only cleanup.
  Maintain a concise feature-level MOC entry when useful; avoid repeated
  file-by-file entries and copies of the entire hub/MOC for every adjustment.
- Preserve existing material. Before a structural note rewrite, back up only
  the affected files in the reusable feature work folder; keep a maximum of
  three compact snapshots under an explicit safe retention policy.
- The user-protected `../../rebuild-cart-check-20261017/build/qa` and its
  parent workspace must stay at the same paths and must not be cleaned,
  regenerated or overwritten during note organization.
- These local user preferences supersede older per-file/per-session note
  generation rules in `../memory/obsidian-documentation.md`. The existing
  remote/canonical vault topology is unchanged; no synchronization is implied.

## Mobile fork boundary

- This fork is `SabatinoRaffaella/cardvault`; `AppMobile` is its sole default branch.
- `origin` is the user fork; `upstream` is the original project. Do not push to or
  deploy the original project as part of work in this fork.
- Site/backend implementation, SQL migrations, workers and deployment scripts
  were removed after auditing mobile imports and bundled assets. They remain in
  the history at `v1.2.1` and upstream. Historical documentation is reference only.
- Preserve the remote API clients, Firebase configuration/rules, native projects,
  scanner models, local suggestion package/assets, Flutter tests and APK helper.
- `lib/old/` remains a reference client; its shared SVG now uses
  `assets/brand/pokoin.svg`. Do not restore the deleted web folder to load a logo.
- The app still depends on live Pokoin/Firebase services. Removing local server
  source does not change, deploy, stop or replace those services.
- Public marketplace IDs are canonical card IDs, never a CardTrader ID in URLs.
  See `docs/marketplace-public-ids.md` before changing card IDs or image URLs.
