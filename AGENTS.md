# AGENTS.md — JagtFokus

Guidance for AI agents working in this repo.

## Language

Talk to the user in Danish.

Write agent and developer docs in English. That includes this file and `README.md`.

Keep Danish for `spec/`, App Store text, support, and the privacy policy. Quote those strings verbatim. Do not translate them.

The app ships two languages: **Danish** (source) and **English**. Danish is the key in `App/JagtFokus/Localizable.xcstrings`, English is the value. Species names, place names, notes and biology come from the data files and stay Danish. So does the App Store listing.

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

Language: Danish and English. No account. No tracking.

## Layout

```
spec/v1.md                         # v1, including the journal
spec/v2.md                         # Journal details and the unbuilt bag report
spec/design.md                     # Design system, screens, decisions
spec/ideas.md                      # Backlog
spec/appstore/                     # App Store copy, replies, review notes, screenshots
docs/                              # GitHub Pages: support (index.html) and privacy policy
data/jagttider.json                # Seasons + places + local overrides
Sources/JagtFokusCore/             # Models, calendar, status, timeline, Jagtbart lists, search, place resolution, sun and moon, MET weather decode, photos, catalog check

Tests/JagtFokusCoreTests/          # 122 tests
.github/workflows/tests.yml        # swift test on every push to main and every PR
.github/workflows/appstore.yml     # App Store upload, manual and off
App/JagtFokus.xcodeproj            # Xcode project (synchronized folders)
App/JagtFokus/
  JagtFokusApp.swift, RootView.swift, Copy.swift, Localization.swift
  Localizable.xcstrings            # UI copy: Danish source, English translation
  InfoPlist.xcstrings              # The system's location prompt
  Store/                           # SeasonStore (@Observable), WeatherStore, LocationService, Appearance
  DesignSystem/                    # Theme (tokens), SeasonBar, StatusViews, ScrollTitle, GroupHeader, CountCard, QueryRow
  Features/Today/                  # Jagtbart, date/place rows, sheets
  Features/Weather/                # Vejr og måne (push from the sun card; MET Norway)
  Features/Species/                # SpeciesRow, SpeciesDetailView
  Features/AllSpecies/             # Alle arter
  Features/Settings/               # Indstillinger (appearance, lists), with the Om sections below
  Features/About/                  # Om sections (AboutSections), shown inside Indstillinger
  Features/Schweiss/               # Schweiss-registret (info, no handler phones)
  Features/Onboarding/             # Welcome + disclaimer
  Resources/species-photos.json    # Photo credits: species → photo, photographer, license
  Resources/biologi.json           # Biology notes. Not hunting seasons. Not remote
  AppIcon.icon                     # Icon Composer app icon (layers + Liquid Glass)
  Assets.xcassets                  # BrandMark, colors, SpeciesPhotos/photo-<id>
tools/add_species_photo.py         # Fetch a species photo from Wikimedia Commons
tools/fill_string_catalog.py       # Write the English String Catalog from the source
tools/bump_build.sh                # Bump the build number before upload
assets/                            # Source icons and logo (not bundled directly)
```

`App/JagtFokus/` and `Sources/JagtFokusCore/` are synchronized folders in Xcode. New `.swift` files are included automatically. Do not edit `project.pbxproj` to add files.

## Screens (v1)

1. **Jagtbart** — heading “Jagtbart vildt efter tid og sted”. Date and place rows, then the answer card (count of open species), then the sun card. Open groups start collapsed, each with a line sketch. A group with a species in its last week says so under its name. Collapsed “Ikke jagtbar her”, sorted by next opening. Default: today + here (GPS).
2. **Alle arter** — general seasons, searchable, SeasonBar per species. Groups start collapsed, each with a line sketch. Search expands hits. No date or place. No status.
3. **Artsdetalje** — push from both lists. Status only from Jagtbart.
4. **Indstillinger** — Appearance System / Lys / Mørk (`@AppStorage("udseende")`). **Sammenfold grupper** (`@AppStorage("sammenfoldGrupper")`, default on) collapses groups on Jagtbart and Alle arter. The Om sections follow in the same list. Four tabs: Jagtbart, Journal, Alle arter, Indstillinger.
5. **Journal** — local bag. Tab icon `book.closed`, system large title “Jagtjournal”. **Artsliste** is species taken at least once, one row each. A journal note adds the species. Deleting a journal row does not remove it.
6. **Om** — not a tab. Sections under Indstillinger: source, responsibility, Schweiss, photos, privacy. Bottom section **Denne app**: mark, release version and data version.
7. **Velkomst** — first launch. Requires “Forstået”. Always dark.
8. **Schweiss-registret** — info page, not a tab. Toolbar **Anskudt** on Jagtbart (sheet) and a row in Indstillinger. Wounded game opens schweiss.dk. A traffic collision calls 1812. No handler phone list.

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
- Logic (dates, status, timeline) lives in `JagtFokusCore` with tests. Views only format. Jagtbart's lists come from `SeasonCalendar.openGroups`, `closedSpecies` and `closingSoonCount`. Every search uses `TextSearch`.
- A component used on two screens lives in `DesignSystem/`. Do not copy a row from one feature to another.
- Shared copy lives in `Copy.swift`.
- Buttons in a `List` inherit the tint. Use `.tint(.primary)` on row buttons that are not links.
- Attach sheets to the screen's `List` or `NavigationStack`, not to a `Section`.

## Copy and translation

Write the copy in Danish where it is used. A literal in `Text`, `Label`, `Button`, `Section`
and the accessibility modifiers is a `LocalizedStringKey` and is translated on its own.
A literal that lands in a `String` is not: wrap those in `String(localized:)`. That catches
computed strings, `QueryRow(title:value:detail:)`, `Feature(title:text:)` and the `label:`
and `hint:` parameters on the Schweiss page.

Today's date, numbers and the system's own controls follow the app's language, not the
device region. `AppLanguage.locale` feeds `SeasonCalendar` and the `\.locale` environment.
Never hardcode `Locale(identifier: "da_DK")` in a view.

After adding or changing copy:

```sh
python3 tools/fill_string_catalog.py <stringsdata-dir>   # see the tool for the path
```

It compares the keys Xcode extracted with the English table and refuses to write when the
two do not match, so a forgotten translation is an error rather than a Danish sentence in
the English app. Add the English line to the table in the same change.

The check cannot see a key that Xcode extracted from another call site. `QueryRow(title: "Dato")`
was never translated, because `DatePicker("Dato")` put "Dato" in the catalogue anyway. Run the
app in English after copy changes.

A count that changes the words ("1 art", "2 arter") goes in `PLURALS` in the tool, with Danish
and English forms. Do not branch on `count == 1` in Swift. Shared counts are `Copy.speciesCount`
and `Copy.pieces`.

`SeasonCalendar` takes a locale, so date text is testable. Pass `Locale(identifier: "da_DK")`
in tests; never rely on the machine.

`SeasonCalendar` counts days in Europe/Copenhagen, and its text must too. Format through
`SeasonCalendar.dateTime`, never `.dateTime` on its own: that uses the phone's zone, and a phone
west of Denmark then shows a season opening 1 October as “30. sep.”. CI runs in UTC, so a test
that leans on the machine's zone fails there.

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

The simulator's own language may be English. Make the app open in Danish anyway, stored
in the app's preference domain (persists across launches; a `-AppleLanguages` launch
argument still wins when you want to check the English app):

```sh
xcrun simctl spawn booted defaults write dk.jagtfokus.app AppleLanguages -array da
xcrun simctl spawn booted defaults write dk.jagtfokus.app AppleLocale -string da_DK
```

Debug launch arguments (DEBUG only) for screenshots and manual checks:

| Argument | Effect |
|---|---|
| `-harGodkendtFraskrivelse YES` | Skip welcome (`NO` shows it) |
| `-date 2026-11-15` | Selected date |
| `-place als` | Selected place (place id) |
| `-tab bag` / `-tab all` / `-tab settings` | Start tab (`-tab about` is the same as settings) |
| `-udseende dark` / `light` / `system` | Appearance, regardless of the simulator theme |
| `-species raabuk` | Open the species page from Jagtbart |
| `-sheet date` / `-sheet place` / `-sheet schweiss` | Open a picker, or the Schweiss page from Jagtbart |
| `-closed YES` | Expand “Ikke jagtbar her” |
| `-open vejr` | Push the weather page from Jagtbart |
| `-search ræv` | Open search on Alle arter with that text (use with `-tab all`) |
| `-groups open` | Expand every group on Jagtbart, or on Alle arter with `-tab all` |
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

A push to `main` reaches every phone within minutes. Three guards:

- `HuntingCatalog.decodeChecked` refuses a downloaded or cached file with `problems`: no species, no `dk`, a repeated species or place id, a parent or override pointing at nothing, or a `source_url` that is not https on retsinformation.dk. The app keeps the data it has and shows “Fejl i ny data. Bruger gemt data.”
- The tests read `data/jagttider.json` (`bundledDataPasses` and others), and `.github/workflows/tests.yml` runs them on every push. A red run after a data push means phones may already have the file, unless the check above refuses it. Fix it right away.
- `main` has a ruleset: no force-push, no deletion.

The source link opens only through `HuntingCatalog.sourceLink`. Never build it with `URL(string: catalog.sourceURL)`.

New local seasons: add `places` and `overrides` in `data/jagttider.json`. Bump `version`.

Every place has `lat`/`lon`: a representative point for sun times. The sun row repeats the chosen place and date, for example “Sjælland, den 16. oktober”. New places must have coordinates; a test enforces that.

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
- GitHub Actions upload is prepared in `.github/workflows/appstore.yml` and is off. The Apple developer account is not approved. Do not run it with upload on, and do not add API keys to the repo. Secrets and the later steps are in `spec/appstore/README.md`. The workflow uploads a build only. It does not submit or release. The number in the **Denne app** section (Indstillinger) is `MARKETING_VERSION` from the Xcode project, the same number the archive uses.
- Data fixes do not need a new app version: edit `data/jagttider.json`, bump `version`, push.

## Commits

Include `spec/ideas.md` when it has the user's notes. Do not leave those notes uncommitted.

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
