# Dungeon Crawler

Optional, device-local Pokoin appearance. The app still starts with Default
unless the user has saved another choice via the palette beside their email
in Profile -> Tema dell'app (also available beside the guest description).

`dungeon_crawler_theme.dart` owns the icon-slot manifest, illustrated surfaces
and warm brown/cream/gold toolbar and navigation palette. The main five-tab
shell uses Mappa.png as its background and Botttom_bar.png behind the existing
navigation controls. Default retains its original palette and Flutter icons.
Cardex, Portfolio and Scanner use supplied custom icons; unfilled slots retain Flutter
icons. Portfolio is also used by the collection shortcut in Profile.

## Adding artwork

Keep bitmap files under `assets/`, not under `lib/style/`. Register their exact
case-sensitive path in pubspec when required, then add an AppThemeIcon slot to
the manifest. The existing `assets/icons/` declaration already bundles
`assets/icons/Cardex.png`, `assets/icons/Portfolio.png` and
`assets/icons/Scanner.png`; no duplicate copy or
network download is needed.
The explicit `assets/images/Dungeon Crawler Themed/` bundle contains Mappa.png
and Botttom_bar.png. Original colours are preserved: the map covers the body
proportionally, aligned at the top; the chest fills the navigation height,
including the safe bottom inset. Labels and touch targets remain unchanged.
AppThemeSurfaces configures local backgrounds separately from AppThemeIcons.
No card cropping, API fetching or image processing is involved. Existing panels
keep their own readable surfaces. The map does not replace pushed detail pages.

Navigation slots: market, scanner, portfolio, cardex, profile. Shared marketplace
slots: cart, filters, search, wallet, clipboard. Reuse ThemedIcon for new themed
surfaces so missing or broken assets retain a functional Flutter icon.
Pixel art is drawn without smoothing and with bounded dimensions; changing the
theme must not fetch card images, recreate services, log out users, clear the
cart, or affect API/search/inventory data. Existing card-specific palettes and
album crops remain independent of this app-wide appearance.

## Poko wardrobe

Profile places a wardrobe button beside the palette, available to guests too.
Head (Batty/Skellyyyy), hand (Lumachina) and feet (fairy boots/magic carpet)
are independent slots; each includes None. Preview changes are drafts until
Save look; cancelling leaves the saved outfit unchanged. Saving failures keep
the previous look and offer a retry. Selections are device-local cosmetics,
not an account avatar upload or a server-side inventory/unlock feature.

The toolbar uses the composed Poko only in Dungeon Crawler; Default keeps its
original brand PNG. The editor is available from either theme. WardrobeController
is owned at the composition root, independently of login, cart and API services.
Its service validates accessory IDs; WardrobeProvider stores one versioned
SharedPreferences snapshot. Unknown IDs become empty slots.

`assets/icons/wardrobe/` contains the original trimmed PNGs. The five subfolders
are explicitly bundled. `wardrobe_style.dart` owns an 80 x 80 logical canvas,
per-sprite bounds and local paths. Background, carpet, body, headgear, boots and
hand are drawn in that order with no smoothing. The canvas is reused for the
editor, choices and toolbar, without cropping or rewriting supplied images.
Headgear uses the original sprite dimensions: Batty 44 x 20 at (15, 16), and
the reduced Skellyyyy 41 x 26 at (19, 11). Their brims overlap Poko's crown
without the previous floating gap or enlarging Skelly back to its old size.
For another accessory, add its slot/label/ID to wardrobe_constants.dart and its
path/bounds to WardrobeStyle (and adjust layering for a new type of foot item).
