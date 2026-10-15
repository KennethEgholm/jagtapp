# AGENTS.md — JagtFokus

Guidance for AI agents working in this repo.

## Language

Talk to the user in Danish.

Write agent and developer docs in English. That includes this file and `README.md`.

Keep Danish for the app and its direct description: UI copy, `spec/`, App Store text, support, and the privacy policy. Quote those strings verbatim. Do not translate them.

## What this is

iPhone app: **hvad er jagtbart her og nu?** Danish hunting seasons by date and place.

v1, including the hunting journal, is in `spec/v1.md`. Journal details and the unbuilt bag report are in `spec/v2.md`. Design and UX are in `spec/design.md`. Backlog is in `spec/ideas.md`.

## Stack

| Layer | Tech |
|-------|------|
| App | Swift, SwiftUI, iOS 18+ (built with the iOS 27 SDK), bundle `dk.jagtfokus.app` |
| Core | `JagtFokusCore` (Swift package, testable on macOS). Also compiled straight into the app target |
| Data | `data/jagttider.json` (BEK 470/2024) |
| Tests | `swift test` (Swift Testing) |

Language: Danish. No account. No tracking.

## Layout

```
spec/v1.md                         # v1, including the journal
spec/v2.md                         # Journal details and the unbuilt bag report
spec/design.md                     # Design system, screens, decisions
spec/ideas.md                      # Backlog
spec/appstore/                     # App Store copy, replies, review notes, screenshots
docs/                              # GitHub Pages: support (index.html) and privacy policy
data/jagttider.json                # Seasons + places + local overrides
Sources/JagtFokusCore/             # Models, calendar, status, timeline, place resolution, sun times, photos
Tests/JagtFokusCoreTests/          # 72 tests
App/JagtFokus.xcodeproj            # Xcode project (synchronized folders)
App/JagtFokus/
  JagtFokusApp.swift, RootView.swift, Copy.swift
  Store/                           # SeasonStore (@Observable), LocationService, Appearance
  DesignSystem/                    # Theme (tokens), SeasonBar, StatusViews, ScrollTitle
  Features/Today/                  # Jagtbart, date/place rows, sheets
  Features/Species/                # SpeciesRow, SpeciesDetailView
  Features/AllSpecies/             # Alle arter
  Features/Settings/               # Indstillinger (appearance)
  Features/About/                  # Om
  Features/Schweiss/               # Schweiss-registret (info, no handler phones)
  Features/Onboarding/             # Welcome + disclaimer
  Resources/species-photos.json    # Photo credits: species → photo, photographer, license
  Resources/biologi.json           # Biology notes. Not hunting seasons. Not remote
  Assets.xcassets                  # AppIcon, BrandMark, colors, SpeciesPhotos/photo-<id>
tools/add_species_photo.py         # Fetch a species photo from Wikimedia Commons
tools/bump_build.sh                # Bump the build number before upload
assets/                            # Source icons and logo (not bundled directly)
```

`App/JagtFokus/` and `Sources/JagtFokusCore/` are synchronized folders in Xcode. New `.swift` files are included automatically. Do not edit `project.pbxproj` to add files.

## Screens (v1)

1. **Jagtbart** — heading “Jagtbart vildt efter tid og sted”. Date, place, and sun rows. Answer card (count of open species). Open species, grouped. Collapsed “Ikke jagtbar her”, sorted by next opening. Default: today + here (GPS).
2. **Alle arter** — general seasons, searchable, SeasonBar per species. No date or place. No status.
3. **Artsdetalje** — push from both lists. Status only from Jagtbart.
4. **Indstillinger** — Appearance System / Lys / Mørk (`@AppStorage("udseende")`).
5. **Om** — source, responsibility, photos, privacy, version.
6. **Velkomst** — first launch. Requires “Forstået”. Always dark.
7. **Schweiss-registret** — info page, not a tab. Toolbar **Anskudt** on Jagtbart (sheet) and a row on Om. Wounded game opens schweiss.dk. A traffic collision calls 1812. No handler phone list.

## Rules

- Date and place decide the Jagtbart list. Not the time of day.
- Sun times are display only. No logic may use them (for example “jagtbar nu”).
- Biology is display only. No logic may use it. Sources and the omitted population estimates are in `spec/design.md`.
- A local season beats the general one. Island > area > region > Denmark.
- An empty period means no season at that place.
- Notes are text, not logic.
- The app is not the law.
- Red deer and fallow deer: general seasons plus a note only. Map appendices are not in v1.

## UI rules

- Read `spec/design.md` before UI work. Update it when you make a design decision.
- Use tokens from `DesignSystem/Theme.swift` (`Spacing`, `Radius`, `.seasonOpen`, `.seasonClosingSoon`, `.localTime`). No hex colors in views.
- Dynamic Type styles only. Test at an accessibility size (see Run).
- Status is text plus an icon. Never color alone.
- Logic (dates, status, timeline) lives in `JagtFokusCore` with tests. Views only format.
- Shared copy lives in `Copy.swift`.
- Buttons in a `List` inherit the tint. Use `.tint(.primary)` on row buttons that are not links.
- Attach sheets to the screen's `List` or `NavigationStack`, not to a `Section`.

## Run

```sh
swift test
```

If `swift test` fails with “TestingMacros … not found”, run it again. That happens on the first build after a test file changes. `swift build --build-tests` shows the real compile errors.

`xcode-select` points at CommandLineTools. Use Xcode through `DEVELOPER_DIR`:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project App/JagtFokus.xcodeproj -scheme JagtFokus \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath /tmp/jf/DerivedData build CODE_SIGNING_ALLOWED=NO
```

Never put DerivedData in `.build/`. That breaks `swift test`.

After every development cycle, build and install on the booted simulator so it shows the new build. Use iPhone 18 Pro if no simulator is running. Do not end a cycle with `xcodebuild build` alone.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun simctl install booted /tmp/jf/DerivedData/Build/Products/Debug-iphonesimulator/JagtFokus.app
xcrun simctl launch booted dk.jagtfokus.app
```

The simulator log is full of system noise, especially when the keyboard is visible (for example in search fields): `UIKBRenderingLog`, `CHHapticPattern … hapticpatternlibrary.plist` (the simulator has no haptics), constraints in `TUIPredictionViewCell`, `cannot add handler to 0 from 0`. That is iOS, not the app. Filter on the app's own errors and on `com.apple.runtime-issues` (purple warnings in Xcode):

```sh
xcrun simctl spawn booted log show --last 10m --style compact \
  --predicate 'process == "JagtFokus" AND subsystem == "com.apple.runtime-issues"'
```

CoreLocation: never read `authorizationStatus` or `locationServicesEnabled()` outside `locationManagerDidChangeAuthorization`. That blocks the main thread (runtime issue).

Xcode: open `App/JagtFokus.xcodeproj`, iPhone 18 Pro, Cmd-R. Xcode 27 has no Simulator app. Use **Device Hub**.

The simulator has no GPS. Set a Danish position:

```sh
xcrun simctl location booted set 56.1629,10.2039
```

Debug launch arguments (DEBUG only) for screenshots and manual checks:

| Argument | Effect |
|---|---|
| `-harGodkendtFraskrivelse YES` | Skip welcome (`NO` shows it) |
| `-date 2026-11-15` | Selected date |
| `-place als` | Selected place (place id) |
| `-tab bag` / `-tab all` / `-tab settings` / `-tab about` | Start tab |
| `-udseende dark` / `light` / `system` | Appearance, regardless of the simulator theme |
| `-species raabuk` | Open the species page from Jagtbart |
| `-sheet date` / `-sheet place` / `-sheet schweiss` | Open a picker, or the Schweiss page from Jagtbart |
| `-closed YES` | Expand “Ikke jagtbar her” |
| `-search ræv` | Open search on Alle arter with that text (use with `-tab all`) |
| `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL` | Large text |

```sh
xcrun simctl launch --terminate-running-process booted dk.jagtfokus.app \
  -harGodkendtFraskrivelse YES -place als -species raabuk
xcrun simctl ui booted appearance dark
xcrun simctl io booted screenshot /tmp/shot.png
```

## Data

Source: SGAV hunting table from 1 July 2024, BEK 470/2024.

`version` in the JSON. The bundle is the fallback. Remote GitHub raw overwrites it only when the version is newer.

New local seasons: add `places` and `overrides` in `data/jagttider.json`. Bump `version`.

Every place has `lat`/`lon`: a representative point for sun times (shown as “ca.”). New places must have it; a test enforces that. GPS gives exact sun times.

Sun times are calculated on device (NOAA algorithm, `SunTimes.swift`). Tests use reference values from the US Naval Observatory: `https://aa.usno.navy.mil/api/rstt/oneday?date=2026-10-11&coords=56.16,10.20&tz=2`.

An override `note` is `null` unless it says more than the UI already does. The badge already shows “Lokal jagttid”, and the period shows “Ingen jagttid”. When a local season applies, show only its own note, not the species' general note. A test enforces that.

## Photos

Every species has a photo on the species page. Wikimedia Commons only, and only licenses that allow commercial use: CC0, public domain, CC BY, CC BY-SA. Never NC/ND. Photographer and license are shown under the image (required by the license).

New species or a better photo:

```sh
python3 tools/add_species_photo.py <species_id> "File:<Commons-filnavn>.jpg"
python3 tools/add_species_photo.py <species_id> --share <anden_species_id>   # same animal
swift test
```

Pick a photo that matches sex and age (hind, calf, sow with piglets, and so on). Check the crop: the tool crops the center to 3:2. `SpeciesPhotoTests` fails if a species has no photo, a license is not allowed, or an image file is missing. A species from newer remote data without a photo is shown without an image.

## Release

Repo: `github.com/KennethEgholm/jagtapp` (public). Remote data: `raw.githubusercontent.com/KennethEgholm/jagtapp/main/data/jagttider.json`. Support and privacy: `kennethegholm.github.io/jagtapp/` (GitHub Pages from `/docs`).

- App Store: free, Denmark only, developer as a private person. Copy and checklist are in `spec/appstore/README.md`.
- `App/JagtFokus/PrivacyInfo.xcprivacy`: no tracking, no collected data, UserDefaults (`CA92.1`). A new API on Apple's required-reason list needs a reason added.
- The privacy policy (`docs/privatliv.html`) must match the app. New data collection, a new network call, or a new third-party SDK means update the page, the manifest, and the App Store answers in the same change.
- Before each upload: `tools/bump_build.sh` (or `tools/bump_build.sh 1.1` for a new version). Archive in Xcode (Product → Archive) → Distribute App → App Store Connect.
- Data fixes do not need a new app version: edit `data/jagttider.json`, bump `version`, push.

## When the user says so

iCloud backup of the journal must ship **immediately**, in the message that asks for it. Not a later slice. Not a question about timing. Turn `NSUbiquitousKeyValueStore` on, put the entitlement back, and update `spec/v1.md`, `spec/v2.md`, `docs/privatliv.html`, and the App Store answers in the same change. The official bag report is a different feature and is not part of v1.

## Do not

- Encode footnotes as logic.
- Show open/closed on Alle arter.
- Put a date or place picker on Alle arter.
- Scrape authority websites.
- Edit `.storage` or claim the app is the law.
- Use glass (Liquid Glass) on content. Only the system's bars and controls.
- Use photos without credit, or with an NC/ND license.
- Claim the app has reported the hunting bag to the authorities.
