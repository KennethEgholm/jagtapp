# AGENTS.md — JagtFokus

Guidance for AI agents working in this repo.

## What this is

iPhone-app: **hvad er jagtbart her og nu?** Danske jagttider efter dato og sted.

v1, inklusive jagtjournalen, står i `spec/v1.md`. Detaljer og den ubyggede indberetning står i `spec/v2.md`. Design og UX i `spec/design.md`. Backlog i `spec/ideas.md`.

## Stack

| Layer | Tech |
|-------|------|
| App | Swift, SwiftUI, iOS 18+ (bygget med iOS 27 SDK), bundle `dk.jagtfokus.app` |
| Core | `JagtFokusCore` (Swift package, macOS-testbar). Kompileres også direkte ind i app-target |
| Data | `data/jagttider.json` (BEK 470/2024) |
| Tests | `swift test` (Swift Testing) |

Sprog: dansk. Ingen konto. Ingen tracking.

## Layout

```
spec/v1.md                         # v1, inklusive journal
spec/v2.md                         # Journal-detaljer og ubygget indberetning
spec/design.md                     # Designsystem, skærme, beslutninger
spec/ideas.md                      # Backlog
spec/appstore/                     # App Store-tekster, svar, review-noter, screenshots
docs/                              # GitHub Pages: support (index.html) og privatlivspolitik
data/jagttider.json                # Jagttider + steder + lokale overrides
Sources/JagtFokusCore/             # Modeller, kalender, status, tidslinje, sted-opløsning, soltider, fotos
Tests/JagtFokusCoreTests/          # 59 tests
App/JagtFokus.xcodeproj            # Xcode-projekt (synkroniserede mapper)
App/JagtFokus/
  JagtFokusApp.swift, RootView.swift, Copy.swift
  Store/                           # SeasonStore (@Observable), LocationService, Appearance
  DesignSystem/                    # Theme (tokens), SeasonBar, StatusViews, ScrollTitle
  Features/Today/                  # Jagtbar, dato/sted-rækker, sheets
  Features/Species/                # SpeciesRow, SpeciesDetailView
  Features/AllSpecies/             # Alle arter
  Features/Settings/               # Indstillinger (udseende)
  Features/About/                  # Om
  Features/Onboarding/             # Velkomst + fraskrivelse
  Resources/species-photos.json    # Fotokreditter: art → foto, fotograf, licens
  Assets.xcassets                  # AppIcon, BrandMark, farver, SpeciesPhotos/photo-<id>
tools/add_species_photo.py         # Hent artsfoto fra Wikimedia Commons
tools/bump_build.sh                # Tæl build-nummer op før upload
assets/                            # Kilde-ikoner og logo (ikke bundlet direkte)
```

`App/JagtFokus/` og `Sources/JagtFokusCore/` er synkroniserede mapper i Xcode. Nye `.swift`-filer kommer automatisk med. Ret ikke `project.pbxproj` for at tilføje filer.

## Screens (v1)

1. **Jagtbar** — overskrift “Jagtbart vildt efter tid og sted”. Dato-, sted- og sol-række. Svar-kort (antal jagtbare). Jagtbare arter grupperet. Sammenfoldet “Ikke jagtbar her” sorteret efter næste åbning. Standard: i dag + her (GPS).
2. **Alle arter** — generelle jagttider, søgbar, SeasonBar pr. art. Ingen dato/sted. Ingen status.
3. **Artsdetalje** — push fra begge lister. Status kun fra Jagtbar.
4. **Indstillinger** — Udseende System / Lys / Mørk (`@AppStorage("udseende")`).
5. **Om** — kilde, ansvar, fotos, privatliv, version.
6. **Velkomst** — første start. Kræver “Forstået”. Altid mørk.

## Rules

- Dato og sted afgør Jagtbar-listen. Ikke klokkeslæt.
- Soltider er visning. Ingen logik må bruge dem (fx “jagtbar nu”).
- Lokal jagttid slår generel. Ø > område > region > Danmark.
- Tom periode = ingen jagttid på stedet.
- Noter er tekst, ikke logik.
- Appen er ikke loven.
- Kron- og dåvildt: kun generelle tider + note. Kortbilag er ikke i v1.

## UI rules

- Læs `spec/design.md` før UI-arbejde. Opdater den når du træffer en designbeslutning.
- Brug tokens fra `DesignSystem/Theme.swift` (`Spacing`, `Radius`, `.seasonOpen`, `.seasonClosingSoon`, `.localTime`). Ingen hex-farver i views.
- Kun Dynamic Type-stilarter. Test med AX-størrelse (se Run).
- Status = tekst + ikon. Aldrig kun farve.
- Logik (datoer, status, tidslinje) i `JagtFokusCore` med tests. Views formaterer kun.
- Fælles tekster i `Copy.swift`.
- Knapper i `List` arver tint. Brug `.tint(.primary)` på række-knapper der ikke er links.
- Sheets hænges på skærmens `List`/`NavigationStack`, ikke på en `Section`.

## Run

```sh
swift test
```

Fejler `swift test` med “TestingMacros … not found”, så kør igen. Det sker ved første build efter en ændret testfil. `swift build --build-tests` viser de rigtige compile-fejl.

`xcode-select` peger på CommandLineTools. Brug Xcode via `DEVELOPER_DIR`:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project App/JagtFokus.xcodeproj -scheme JagtFokus \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath /tmp/jf/DerivedData build CODE_SIGNING_ALLOWED=NO
```

Læg aldrig DerivedData i `.build/` — det ødelægger `swift test`.

Simulator-loggen er fuld af systemstøj, især når tastaturet vises (fx i søgefelter): `UIKBRenderingLog`, `CHHapticPattern … hapticpatternlibrary.plist` (simulatoren har ingen haptik), constraints i `TUIPredictionViewCell`, `cannot add handler to 0 from 0`. Det er iOS, ikke appen. Filtrér på appens egne fejl og på `com.apple.runtime-issues` (lilla advarsler i Xcode):

```sh
xcrun simctl spawn booted log show --last 10m --style compact \
  --predicate 'process == "JagtFokus" AND subsystem == "com.apple.runtime-issues"'
```

CoreLocation: læs aldrig `authorizationStatus` eller `locationServicesEnabled()` uden for `locationManagerDidChangeAuthorization`. Det blokerer main thread (runtime-issue).

Xcode: åbn `App/JagtFokus.xcodeproj`, iPhone 18 Pro, Cmd-R. Xcode 27 har ingen Simulator-app. Brug **Device Hub**.

Simulator har ingen GPS. Sæt dansk position:

```sh
xcrun simctl location booted set 56.1629,10.2039
```

Debug-launch-argumenter (kun DEBUG) til screenshots og manuel test:

| Argument | Effekt |
|---|---|
| `-harGodkendtFraskrivelse YES` | Spring velkomst over (`NO` viser den) |
| `-date 2026-11-15` | Valgt dato |
| `-place als` | Valgt sted (place id) |
| `-tab bag` / `-tab all` / `-tab settings` / `-tab about` | Start-fane |
| `-udseende dark` / `light` / `system` | Udseende, uanset simulatorens tema |
| `-species raabuk` | Åbn artsdetalje på Jagtbar |
| `-sheet date` / `-sheet place` | Åbn vælger |
| `-closed YES` | Fold “Ikke jagtbar her” ud |
| `-search ræv` | Åbn søgning på Alle arter med tekst (brug med `-tab all`) |
| `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL` | Stor tekst |

```sh
xcrun simctl launch --terminate-running-process booted dk.jagtfokus.app \
  -harGodkendtFraskrivelse YES -place als -species raabuk
xcrun simctl ui booted appearance dark
xcrun simctl io booted screenshot /tmp/shot.png
```

## Data

Kilde: SGAV jagttabel fra 1. juli 2024, BEK 470/2024.

`version` i JSON. Bundle er fallback. Remote GitHub raw overskriver kun hvis nyere version.

Nye lokale tider: tilføj `places` og `overrides` i `data/jagttider.json`. Bump `version`.

Hvert sted har `lat`/`lon`: et repræsentativt punkt til soltider (vist som “ca.”). Nye steder skal have det; en test håndhæver det. GPS giver præcise soltider.

Soltider beregnes lokalt (NOAA-algoritme, `SunTimes.swift`). Testene bruger referenceværdier fra US Naval Observatory: `https://aa.usno.navy.mil/api/rstt/oneday?date=2026-10-11&coords=56.16,10.20&tz=2`.

Override-`note` er `null`, medmindre den siger mere end UI'et. Badget viser allerede “Lokal jagttid”, og perioden viser “Ingen jagttid”. Gælder en lokal tid, vises kun dens egen note, ikke artens generelle. En test håndhæver det.

## Fotos

Hver art har et foto på artsdetaljen. Kun Wikimedia Commons og kun licenser der tillader kommerciel brug: CC0, public domain, CC BY, CC BY-SA. Aldrig NC/ND. Fotograf + licens vises under billedet (krav i licensen).

Ny art eller bedre foto:

```sh
python3 tools/add_species_photo.py <species_id> "File:<Commons-filnavn>.jpg"
python3 tools/add_species_photo.py <species_id> --share <anden_species_id>   # samme dyr
swift test
```

Vælg foto der passer til køn og alder (hind, kalv, so med grise …). Tjek beskæringen: værktøjet beskærer midten til 3:2. `SpeciesPhotoTests` fejler hvis en art mangler foto, en licens ikke er tilladt eller en billedfil mangler. En art fra nyere remote-data uden foto vises bare uden billede.

## Release

Repo: `github.com/KennethEgholm/jagtapp` (offentligt). Remote data: `raw.githubusercontent.com/KennethEgholm/jagtapp/main/data/jagttider.json`. Support og privatliv: `kennethegholm.github.io/jagtapp/` (GitHub Pages fra `/docs`).

- App Store: gratis, kun Danmark, udvikler som privatperson. Tekster og tjekliste i `spec/appstore/README.md`.
- `App/JagtFokus/PrivacyInfo.xcprivacy`: ingen tracking, ingen indsamlede data, UserDefaults (`CA92.1`). Nyt API på Apples “required reason”-liste → tilføj årsag.
- Privatlivspolitikken (`docs/privatliv.html`) skal passe med appen. Ny dataindsamling, nyt netværkskald eller nyt tredjeparts-SDK → opdatér side, manifest og App Store-svar.
- Før hver upload: `tools/bump_build.sh` (eller `tools/bump_build.sh 1.1` for ny version). Arkivér i Xcode (Product → Archive) → Distribute App → App Store Connect.
- Datarettelser kræver ikke ny app-version: ret `data/jagttider.json`, bump `version`, push.

## Do not

- Encode fodnoter som logik.
- Vise åben/lukket på Alle arter.
- Sætte dato/sted-vælger på Alle arter.
- Scrape myndighedssider.
- Redigere `.storage` eller påstå at appen er loven.
- Bruge glas (Liquid Glass) på indhold. Kun systemets bars og kontroller.
- Bruge fotos uden kreditering eller med NC/ND-licens.
- Påstå at appen har indberettet vildtudbytte.
