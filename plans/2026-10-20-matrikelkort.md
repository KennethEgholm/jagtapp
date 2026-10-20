# Matrikelkort (Kort tab) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new **Kort** tab that shows Danish cadastral parcel boundaries (matrikelskel) over an OpenFreeMap basemap around the hunter's position, and works with no network for areas the hunter has saved.

**Architecture:** Parcels come from Datafordeler's matrikel WFS as **vector polygons (GeoJSON)**, not as WMS image tiles. So a saved 5×5 km area is a few MB, renders sharp at every zoom offline, and can later answer "which parcel am I in". The basemap is OpenFreeMap vector tiles in MapLibre Native iOS. A saved area also downloads a MapLibre offline pack for the same box. Geometry, request building, GeoJSON checks, the saved-area index and the request limiter live in `JagtFokusCore` with tests. The app target wraps MapLibre and formats.

**Tech Stack:** Swift 6, SwiftUI, iOS 18+, MapLibre Native iOS 6.31.x (SPM `https://github.com/maplibre/maplibre-gl-native-distribution`, product `MapLibre`), OpenFreeMap, Datafordeler MATRIKLEN2 WFS (Klimadatastyrelsen), Swift Testing.

**Spec:** `spec/kort.md` (written in Task 1 from "Product spec" below; Danish, like the rest of `spec/`).

**Execution:** When this plan is approved, save it as `plans/2026-10-20-matrikelkort.md` in the repo (not `docs/`: that folder is GitHub Pages and would publish it). Implementation starts when the user says so.

## Context

The hunting right follows the property, so knowing exactly where the boundary runs keeps a hunter off the neighbour's land. The user wants a map in the app that shows matrikelgrænser / ejendomsskel for the area they hunt. Coverage "i marken" is poor, so the map must work offline.

**User decisions (2026-10-20):** offline by **Gem område** (saved at home on wifi, kept until deleted; no silent disk caching of browsed areas). A new tab **Kort**. Basemap **OpenFreeMap** only. Saved area up to **5×5 km**.

**Research findings that shape the plan (2026-10-20):**
- Dataforsyningen's matrikel WMS/WFS (`MatGaeldendeOgForeloebigWMS_DAF`, `…WFS_DAF`, INSPIRE `cp_inspire`) **close for good** at the platform move on 29 Oct–2 Nov 2026. The listed replacement is **Datafordeler** (same agency): `wfs.datafordeler.dk`, free `apikey` (created in Datafordeler Administration; valid 2 years, renewable; public data only). No token-free source remains.
- WFS: GeoServer, WFS 2.0.0, max 30,000 features/request, paging with `startIndex`. GeoJSON output and `srsName=EPSG:4326` are standard GeoServer but **not confirmed** for this service. With GeoServer, `EPSG:4326` means lon/lat and `urn:ogc:def:crs:EPSG::4326` means lat/lon. The expected properties are `matrikelnummer` and `ejerlavsnavn`; the geometry property name is unknown. Datafordeler's own map viewer caps a bbox at 10 km², so the save is split in four quadrants.
- Licence CC BY 4.0: "Du skal kreditere Geodatastyrelsen på et passende sted".
- Geodatastyrelsen, verbatim: „Matrikelkortets visning af skel skal dermed betragtes som vejledende, da de er behæftet med en usikkerhed på typisk 0,1-4,0 m …" and „Kun en praktiserende landinspektør kan fastlægge en gældende ejendomsgrænse." Datafordeler says some boundaries are off by up to 20 m.
- OpenFreeMap: no key, commercial and mobile use allowed. Style `https://tiles.openfreemap.org/styles/liberty`. Vector source `https://tiles.openfreemap.org/planet` (TileJSON, tile paths **versioned weekly**, maxzoom 14). Attribution "OpenFreeMap © OpenMapTiles Data from OpenStreetMap". Offline download allowed if each download is **≤ 3,000 tiles or 50 MB, ≤ 4 parallel requests, unique User-Agent**. The service is as-is.
- MapLibre: telemetry removed. The SDK ships its own PrivacyInfo.xcprivacy (no tracking, no collected data). `MLNTilePyramidOfflineRegion` with an https style works and fetches the style, TileJSON, tiles, glyphs and sprites. Max zoom above 14 stops at 14 and the map overzooms. The downloader runs up to **20 parallel requests**, which breaks OpenFreeMap's rule, so the app throttles through a `URLProtocol` (Task 4). The SwiftUI DSL is pre-1.0, so the app uses `UIViewRepresentable` around `MLNMapView`.

**Calls made by the planner (the user can overrule while reviewing):**
- MapLibre Native, not Leaflet (Leaflet needs a WKWebView; offline packs are native in MapLibre). MapKit was rejected: no OpenFreeMap vector styles, no offline packs.
- Vector parcels, not WMS raster: raster for 5×5 km at z14–19 is ~5,000 tiles and tens of MB, and blurry when over-zoomed.
- Online, the map also shows boundaries for the visible region without saving (memory only), so the tab is useful before saving. Only saved areas go to disk.
- Tab order **Jagtbart, Kort, Journal, Alle arter, Indstillinger**. This reverses "fem faner blev til fire" (Design-gennemgang 4); the reason then was that Om was thin, and a map is a field tool.
- The save area is a fixed 5×5 km square around the map centre, drawn on the map before saving. No size picker.
- The map uses the `liberty` style in light and dark mode. A dark style would double every offline pack.
- Boundary colour: a new asset `Boundary` (red `#C62828`, both appearances, because the map stays light), with a white casing under the line. It is not Brass ("Lokal jagttid") and not Forest or Amber (status).
- Matrikelnummer labels from zoom 16. Boundaries from zoom 13.
- Not in this slice (goes to `spec/ideas.md`): "hvilket jordstykke står jeg på" with ejerlav, aerial photo, "opdater gemt område", automatic storage of browsed areas.

## Before you start (the user)

1. Create a Datafordeler API key: datafordeler.dk → Datafordeler Administration → log in (MitID or e-mail) → create an IT-system → create an API key. It works 15 minutes after creation and expires after 2 years: set a reminder.
2. After Task 4 creates the example file: `cp App/Config/Secrets.example.xcconfig App/Config/Secrets.xcconfig` and put the key in it. Never commit it.

## Product spec (save verbatim as `spec/kort.md` in Task 1)

```markdown
# JagtFokus — Kort med matrikelskel

## Job

Jægeren skal kunne se, hvor skellet går, der hvor jagten er. Jagtretten følger ejendommen. Også uden net i marken.

## Med

- Fane **Kort** (`map`), nummer to: Jagtbart, Kort, Journal, Alle arter, Indstillinger
- Baggrundskort fra OpenFreeMap. Matrikelskel fra Datafordeler (Klimadatastyrelsen) som linjer
- Matrikelnummer på jordstykket ved tæt zoom
- Din position på kortet. Kortet starter, hvor du er. Uden position: Jagtbarts valgte sted, ellers hele Danmark
- **Gem område**: et felt på 5 × 5 km om kortets midte vises på kortet. Gem henter skel og baggrundskort til telefonen
- **Gemte områder**: navn, dato for hentning, størrelse. Slet med swipe. Tryk viser området
- Uden net vises gemte områder med skel. Uden for dem: kun det baggrundskort, telefonen har
- Skel vises fra zoom 13. Længere ude: “Zoom ind for at se skel”
- Kilde og forbehold ét tryk væk (info-knap) og i Indstillinger

## Ikke med

Hvilket jordstykke du står på, ejer, luftfoto, opdatering af et gemt område, automatisk lagring af det, du har set, kortbilag for kron- og dåvildt.

## Regler

- Skel er visning. Ingen logik må bruge dem (fx “jagtbar her”). Jagtbart afgøres stadig af dato og sted
- Matrikelkortet er ikke loven. Kun en praktiserende landinspektør kan fastlægge et skel
- Et gemt område viser datoen, det blev hentet
- Højst 5 × 5 km pr. gemt område

## Forbehold (tekst)

Skel på kortet er fra matrikelkortet og er vejledende. De afviger typisk 0,1–4 m og nogle steder mere. Kun en praktiserende landinspektør kan fastlægge et skel.

Kilde: Geodatastyrelsen, gst.dk/data-og-kort/matrikelkort-og-data/matrikelkort.

## Privatliv

Kortet sender kun det udsnit, der skal vises eller gemmes, til OpenFreeMap og Datafordeler. Ikke positionen og intet om brugeren. Positionen bliver på telefonen. Gemte områder ligger på telefonen, til de slettes.
```

## Global Constraints

- iOS 18.0 deployment target; built with the iOS 27 SDK. Core is `swift-tools-version: 6.0`.
- `JagtFokusCore` must not import MapLibre, UIKit or CoreLocation. CI (`.github/workflows/tests.yml`, `macos-26`) runs `swift test` on it.
- `App/JagtFokus/` and `Sources/JagtFokusCore/` are synchronized folders: new `.swift` files need no `project.pbxproj` edit. The SPM dependency and the xcconfig do (Task 4).
- Copy is Danish in code. Every new key gets its English line in `ENGLISH` in `tools/fill_string_catalog.py` in the same task (pairs in "Copy" below). Literals landing in a `String` use `String(localized:)`. Shared copy goes in `Copy.swift`. Attribution strings are `Text(verbatim:)`, not translated.
- Colours only through tokens (`Theme.swift`, `Assets.xcassets`). Dynamic Type styles only. Status never by colour alone. Dates through `SeasonCalendar.dateTime` and the app locale.
- No Liquid Glass on content. The map and the status card under it are content. Only system bars and controls get glass.
- CoreLocation rule: never read `authorizationStatus` / `locationServicesEnabled()` outside `locationManagerDidChangeAuthorization`. Check `com.apple.runtime-issues` once MapLibre's puck is on.
- No key or secret committed. The Datafordeler key lives in gitignored `App/Config/Secrets.xcconfig`. Recorded fixtures must not contain it (`grep -r apikey Tests/` finds only test code).
- OpenFreeMap downloads: ≤ 4 parallel requests, the app's own User-Agent, ≤ 3,000 tiles and ≤ 50 MB per saved area.
- Privacy text changes ship in the same push as the network calls. Tasks 4–7 are committed locally and pushed to `main` only together with Task 8, and only when the user says so.
- DerivedData in `/tmp/jf/DerivedData`, never `.build/`. Each cycle ends with build + install + launch on the booted simulator (iPhone 18 Pro).

## Copy (Danish → English for `ENGLISH`)

| Danish (key) | English |
|---|---|
| Kort | Map |
| Zoom ind for at se skel | Zoom in to see boundaries |
| Henter skel … | Loading boundaries … |
| Uden net. Viser gemte områder. | Offline. Showing saved areas. |
| Skel kunne ikke hentes. | Boundaries could not be loaded. |
| Kortet mangler adgang til Datafordeler. | The map has no access to Datafordeler. |
| Gemt område: %@, hentet %@ | Saved area: %@, downloaded %@ |
| Præcis position er slået fra | Precise location is off |
| Brug præcis position | Use precise location |
| Gem område | Save area |
| Gemte områder | Saved areas |
| 5 × 5 km om midten | 5 × 5 km around the centre |
| Gem | Save |
| Område | Area |
| Navn | Name |
| Gemmer %@ … | Saving %@ … |
| %@ er gemt | %@ saved |
| Området kunne ikke gemmes. Prøv igen med net. | The area could not be saved. Try again online. |
| Hentet %@ · %@ | Downloaded %@ · %@ |
| Ingen gemte områder. | No saved areas. |
| Slet | Delete |
| Om kortet | About the map |
| Centrér på din position | Centre on your location |
| Baggrundskort | Basemap |
| Matrikelskel | Property boundaries |
| Skel på kortet er fra matrikelkortet og er vejledende. De afviger typisk 0,1–4 m og nogle steder mere. Kun en praktiserende landinspektør kan fastlægge et skel. | Boundaries on the map come from the cadastral map and are indicative. They typically differ by 0.1–4 m, in places more. Only a practising land surveyor can determine a boundary. |
| `InfoPlist.xcstrings` key `Skel`: Præcis position viser, hvilken side af skellet du står på. | Precise location shows which side of the boundary you are on. |

Keys already in the table (e.g. "Annuller") are reused, not added twice.

## Review Focus

1. **Axis order.** WFS in EPSG:4326 can return lat/lon instead of GeoJSON lon/lat, and the boundaries land off Somalia. `ParcelSet.problems` refuses points outside Denmark, and the fixture test checks every point is inside the requested box (Task 2).
2. **Basemap blank offline after a new OpenFreeMap week.** MapLibre likely stores one copy per URL. Once an online session refreshes the `planet` TileJSON to a newer weekly path, the pack's tiles are unreachable offline. Each area stores the tile template it was saved with, and the app re-downloads stale packs when online (Task 3 test, Task 6).
3. **Offline launch.** App started with no network: a saved area shows boundaries, no endless spinner, no alert per request, and the status says the map is offline. DEBUG `-offline YES` reproduces it (Task 6).
4. **Interrupted save.** App killed or network lost mid-download: no half area in the list. An area enters the index only after parcels are written and the pack completes. A failed pack is removed, and orphans are cleaned on launch (Task 3 tests, Task 6).
5. **Reduced accuracy.** The user granted approximate location. The puck becomes a 1–3 km circle, and a boundary map is misleading. The status says so and offers temporary full accuracy (Task 5).

---

### Task 1: Spec and backlog

**Files:**
- Create: `spec/kort.md` (the Product spec block, verbatim)
- Modify: `spec/ideas.md` — under "Senere": "Kort: vis jordstykket, du står på (matrikelnr. og ejerlav)", "Kort: luftfoto som baggrund", "Kort: opdater et gemt område", "Kort: automatisk lagring af det, du har set"
- Modify: `AGENTS.md` — Layout: `spec/kort.md  # Kort med matrikelskel`
- Create: `plans/2026-10-20-matrikelkort.md` (this plan), if not already saved

- [ ] **Step 1:** Write the files.
- [ ] **Step 2: Commit** `git add spec/kort.md spec/ideas.md AGENTS.md plans/ && git commit -m "Kort: spec og plan for matrikelskel offline"`

---

### Task 2: Core — geometry, cadastre request, parcel GeoJSON

**Files:**
- Create: `Sources/JagtFokusCore/MapGeometry.swift`, `Sources/JagtFokusCore/Cadastre.swift`
- Test: `Tests/JagtFokusCoreTests/MapGeometryTests.swift`, `Tests/JagtFokusCoreTests/CadastreTests.swift` (inline `static let fixture`, like `MetForecastTests.fixture`)

**Interfaces (Produces):**
```swift
public struct GeoBox: Codable, Sendable, Equatable, Hashable {
    public var south: Double, west: Double, north: Double, east: Double
    public init(south: Double, west: Double, north: Double, east: Double)
    public static func around(_ center: Coordinate, sideMeters: Double) -> GeoBox
    public var center: Coordinate { get }
    public var widthMeters: Double { get }    // along the centre latitude
    public var heightMeters: Double { get }
    public func contains(_ point: Coordinate) -> Bool
    public func intersects(_ other: GeoBox) -> Bool
    public func quadrants() -> [GeoBox]       // SW, SE, NW, NE; union == self
    public static let denmark: GeoBox         // 54.5…57.8 N, 8.0…15.3 E (incl. Bornholm)
}

public struct MapCamera: Equatable, Sendable {
    public var center: Coordinate
    public var zoom: Double
    public static let denmark: MapCamera      // 56.0 N, 10.8 E, zoom 6
    /// Exact GPS → zoom 15. A place's representative point → zoom 10. None → .denmark.
    public static func start(at point: Coordinate?, isExact: Bool) -> MapCamera
}

public enum MapRules {
    public static let saveSideMeters: Double = 5_000
    public static let boundaryMinZoom: Double = 13
    public static let labelMinZoom: Double = 16
    public static let liveFetchMaxSideMeters: Double = 3_000   // ≤ 9 km², under the 10 km² viewer cap
}

public struct Parcel: Sendable, Equatable, Identifiable {
    public var id: String                     // GeoJSON feature id from the service
    public var number: String                 // matrikelnummer, e.g. "12a"
    public var district: String               // ejerlavsnavn
    public var polygons: [[[Coordinate]]]     // polygon → rings → points
}

public enum ParcelProblem: Equatable, Sendable {
    case outsideDenmark(id: String)           // also catches swapped axes
    case openRing(id: String)
}
public struct ParcelsRefused: Error, Equatable, Sendable { public var problems: [ParcelProblem] }

public struct ParcelSet: Sendable, Equatable {
    public var parcels: [Parcel]
    public var count: Int { get }
    public var problems: [ParcelProblem] { get }
    /// Service response or our own compact file. Throws ParcelsRefused or DecodingError.
    public static func decodeChecked(from data: Data) throws -> ParcelSet
    public func merging(_ other: ParcelSet) -> ParcelSet       // dedupe by id, keep first
    /// Compact FeatureCollection for MapLibre and disk: properties "nr" and "ejerlav" only,
    /// coordinates rounded to 6 decimals (~0.1 m). decodeChecked reads it back.
    public func geoJSON() throws -> Data
}

public enum CadastreService {
    public static let host = "wfs.datafordeler.dk"
    public static let pageSize = 5_000
    public static func requestURL(box: GeoBox, apiKey: String, startIndex: Int) -> URL
    public static let attribution = "© Geodatastyrelsen, Matriklen, CC BY 4.0"
    public static let licenceURL: URL         // datafordeler.dk/vejledning/brugervilkaar/ejendomsoplysninger-ebr-og-mat/
}
```

- [ ] **Step 0: Probe the service** (needs the key; read it from `App/Config/Secrets.xcconfig` into `$KEY`, never echo it into a file):
  ```sh
  BASE="https://wfs.datafordeler.dk/MATRIKLEN2/MatGaeldendeOgForeloebigWFS/1.0.0/WFS?apikey=$KEY&service=WFS&version=2.0.0"
  curl -s "$BASE&request=DescribeFeatureType&typeNames=mat:Jordstykke_Gaeldende"
  curl -s "$BASE&request=GetFeature&typeNames=mat:Jordstykke_Gaeldende&outputFormat=application/json&srsName=EPSG:4326&bbox=10.200,56.160,10.205,56.163,EPSG:4326&count=3"
  ```
  Record the geometry property name and the number and district property names. Then branch:
  - JSON + EPSG:4326 in lon/lat, points near 56.16 N 10.20 E → continue as written.
  - JSON works, EPSG:4326 does not → request `EPSG:25832` and add `UTM32.wgs84(easting:northing:) -> Coordinate` in Core, tested against one reference point converted by the agency's own tool. Note it in `spec/design.md`.
  - No JSON → **stop and ask the user** (GML parsing changes the size of this task).
  Trim the response to 2–3 features (keep a MultiPolygon if any) as the fixture.
- [ ] **Step 1: Write the failing tests** (`MapGeometryTests`)
  - `aroundIsFiveKilometresEachWay`: `GeoBox.around(Coordinate(latitude: 56.16, longitude: 10.20), sideMeters: 5_000)` → `abs(widthMeters - 5_000) < 5`, `abs(heightMeters - 5_000) < 5`, centre equal within 1e-9.
  - `containsAndIntersects`: centre inside; a point 3 km east outside; boxes with centres 4 km apart intersect, 6 km apart do not.
  - `quadrantsCoverTheBox`: 4 boxes, each 2,500 m ± 5 per side, union bounds == original.
  - `cameraStart`: exact → zoom 15; approximate → 10; nil → `.denmark`.
  - `denmarkBox`: contains (55.1, 14.9) Bornholm and (57.72, 10.58) Skagen; not (12.6, 55.7) (Copenhagen with swapped axes).
- [ ] **Step 2:** `swift test --filter MapGeometryTests` → FAIL (types missing).
- [ ] **Step 3:** Implement `MapGeometry.swift`: 111,320 m per degree latitude, longitude scaled by `cos(latitude)` at the centre (flat earth is fine at 5 km).
- [ ] **Step 4:** `swift test --filter MapGeometryTests` → PASS.
- [ ] **Step 5: Write the failing tests** (`CadastreTests`)
  - `requestURLIsHttpsOnDatafordeler`: scheme https, host `wfs.datafordeler.dk`, path `/MATRIKLEN2/MatGaeldendeOgForeloebigWFS/1.0.0/WFS`; query has `typeNames=mat:Jordstykke_Gaeldende`, `outputFormat=application/json`, `srsName=EPSG:4326`, `bbox=<west>,<south>,<east>,<north>,EPSG:4326`, `count=5000`, `startIndex=10000` when asked for it, `apikey=<the key>`, and `propertyName` with the three names from Step 0.
  - `decodesRecordedFixture`: count and the first parcel's `number` and `district` equal the fixture's values. Every point is inside the probe bbox expanded by 500 m (Review Focus 1).
  - `refusesSwappedAxes`: the fixture with each pair swapped → throws `ParcelsRefused` containing `.outsideDenmark`.
  - `refusesOpenRing`: last point ≠ first → `.openRing`.
  - `mergingDedupesPages`: two sets sharing one id → `count == a + b - 1`.
  - `compactGeoJSONRoundTrips`: `decodeChecked(geoJSON())` equals the set after rounding; each feature's properties are exactly `nr` and `ejerlav`.
- [ ] **Step 6:** `swift test --filter CadastreTests` → FAIL.
- [ ] **Step 7:** Implement `Cadastre.swift`. Accept `Polygon` and `MultiPolygon` and skip other geometry types. `decodeChecked` reads both the service's property names and `nr` / `ejerlav`.
- [ ] **Step 8:** `swift test` → all PASS (127 + new).
- [ ] **Step 9: Commit** `git commit -m "Kort: geometri og matrikel-GeoJSON i Core"`

---

### Task 3: Core — saved areas, basemap version, request gate

**Files:**
- Create: `Sources/JagtFokusCore/OfflineAreas.swift`, `Sources/JagtFokusCore/OpenFreeMap.swift`, `Sources/JagtFokusCore/RequestGate.swift`
- Test: `Tests/JagtFokusCoreTests/OfflineAreaTests.swift` (temp directory per test, like the `BagFileStore` tests), `Tests/JagtFokusCoreTests/OpenFreeMapTests.swift`, `Tests/JagtFokusCoreTests/RequestGateTests.swift`

**Interfaces (Produces):**
```swift
public struct OfflineArea: Codable, Sendable, Equatable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var box: GeoBox
    public var savedAt: Date
    public var parcelCount: Int
    public var bytes: Int              // parcels file + basemap pack, at save
    public var basemapTiles: String    // OpenFreeMap tile template the pack was saved with
}

public struct OfflineAreaIndex: Codable, Sendable, Equatable {
    public var areas: [OfflineArea]    // newest first
    public mutating func add(_ area: OfflineArea)
    public mutating func replace(_ area: OfflineArea)   // same id, after a basemap refresh
    public mutating func remove(id: UUID)
    public func intersecting(_ box: GeoBox) -> [OfflineArea]
    public func containing(_ point: Coordinate) -> OfflineArea?
    public func staleBasemaps(currentTiles: String) -> [OfflineArea]
    public func nextDefaultName(prefix: String) -> String  // "Område 2" when 1 and 3 exist
    public static func decode(from data: Data) throws -> OfflineAreaIndex
    public func encoded() throws -> Data
}

public struct OfflineAreaStore: Sendable {
    public let folder: URL                         // Application Support/Kort
    public init(folder: URL)
    public func loadIndex() -> OfflineAreaIndex    // missing or broken file → empty
    public func parcels(for id: UUID) -> ParcelSet?
    /// Parcels file first, index last: a crash leaves at most an orphan file.
    public func commit(_ area: OfflineArea, parcels: ParcelSet) throws
    public func saveIndex(_ index: OfflineAreaIndex) throws
    public func delete(id: UUID) throws
    public func removeOrphans() throws             // parcel files without an index row
}

public enum OpenFreeMap {
    public static let styleURL: URL                // https://tiles.openfreemap.org/styles/liberty
    public static let tileJSONURL: URL             // https://tiles.openfreemap.org/planet
    public static let attribution = "OpenFreeMap © OpenMapTiles Data from OpenStreetMap"
    public static let maxParallelRequests = 4
    public static let packZoom: ClosedRange<Double> = 8...14
    public static func tilesTemplate(fromTileJSON data: Data) throws -> String   // tiles[0]
}

public actor RequestGate {
    public init(limit: Int)
    public func run<T: Sendable>(_ work: @Sendable () async throws -> T) async throws -> T
}
```

- [ ] **Step 1: Write the failing tests**
  - Index: `roundTrips`, `newestFirst`, `removeById`, `replaceKeepsPosition`, `containingPicksTheAreaUnderThePoint`, `intersectingSkipsFarAreas`, `nextDefaultNameFillsTheGap`.
  - `staleBasemapsComparesTheTemplate` (Review Focus 2): areas saved with `…/20261008_…/{z}/{x}/{y}.pbf` and `…/20261015_…` → with current `…20261015…` only the first is stale.
  - Store (Review Focus 4): `commitWritesParcelsThenIndex`, `orphanParcelsAreRemoved` (a file with no row is deleted, the index is untouched), `brokenIndexLoadsEmpty`, `deleteRemovesBoth`. Files are `omraader.json` and `<uuid>.geojson` (from `ParcelSet.geoJSON()`), written atomically. `savedAt` lives in the index; never read file modification dates (a required-reason API).
  - `tilesTemplateFromTileJSON`: fixture `{"tiles":["https://tiles.openfreemap.org/planet/20261015_001001_pt/{z}/{x}/{y}.pbf"],"maxzoom":14}` → that string; missing `tiles` → throws.
  - `gateNeverRunsMoreThanTheLimit`: 20 tasks that each sleep 20 ms through `RequestGate(limit: 4)`. An actor counter records the peak → `peak <= 4`, and all 20 finish.
- [ ] **Step 2:** `swift test --filter "OfflineArea|OpenFreeMap|RequestGate"` → FAIL.
- [ ] **Step 3:** Implement the three files.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5: Commit** `git commit -m "Kort: gemte områder, kortversion og forespørgselsgrænse i Core"`

---

### Task 4: App — MapLibre, key config, network gate, empty Kort tab

**Files:**
- Modify: `App/JagtFokus.xcodeproj/project.pbxproj` — `XCRemoteSwiftPackageReference` for `https://github.com/maplibre/maplibre-gl-native-distribution`, `upToNextMajorVersion` from `6.31.0`; `XCSwiftPackageProductDependency` `MapLibre` on the app target (packageProductDependencies + Frameworks phase); a `PBXFileReference` for `Config/JagtFokus.xcconfig`, set as `baseConfigurationReference` on the app target's Debug and Release configurations.
- Create: `App/Config/JagtFokus.xcconfig`:
  ```
  DATAFORDELER_API_KEY =
  #include? "Secrets.xcconfig"
  ```
- Create: `App/Config/Secrets.example.xcconfig` (`DATAFORDELER_API_KEY = din-nøgle`). Modify `.gitignore`: `App/Config/Secrets.xcconfig`.
- Modify: `App/JagtFokus/Info.plist` — `<key>DatafordelerApiKey</key><string>$(DATAFORDELER_API_KEY)</string>`
- Create: `App/JagtFokus/Store/UserAgent.swift` — move `WeatherStore.userAgent` (`App/JagtFokus/Store/WeatherStore.swift:83`) here as `enum UserAgent { static var app: String }` and use it from `WeatherStore`.
- Create: `App/JagtFokus/Store/MapNetwork.swift` — `final class MapRequestProtocol: URLProtocol`. Every request runs through one shared `RequestGate(limit: OpenFreeMap.maxParallelRequests)` on an inner `URLSession(configuration: .ephemeral)`, with `User-Agent: UserAgent.app`. `stopLoading` cancels. A `URLProtocol.setProperty` marker stops loops. Also `static func install()`: a `URLSessionConfiguration.default` with `protocolClasses = [MapRequestProtocol.self]`, set as `MLNNetworkConfiguration.sharedManager.sessionConfiguration`. Call it from `JagtFokusApp.init` before any `MLNMapView` exists. DEBUG `-offline YES`: the protocol fails every request with `URLError(.notConnectedToInternet)`, and `URLProtocol.registerClass` does the same for `URLSession.shared`.
- Create: `App/JagtFokus/Features/Map/MapTab.swift`, `App/JagtFokus/Features/Map/ParcelMapView.swift`
- Modify: `App/JagtFokus/RootView.swift` — `AppTab.map`; `Tab(Copy.mapTab, systemImage: "map", value: AppTab.map)` second; `-tab map` / `-tab kort` in `applyLaunchTab` (`RootView.swift:60`).
- Modify: `App/JagtFokus/Copy.swift` (`mapTab`), `tools/fill_string_catalog.py`.
- Commit `App/JagtFokus.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

**Interfaces:**
- `ParcelMapView: UIViewRepresentable` around `MLNMapView`: `styleURL = OpenFreeMap.styleURL`, `showsUserLocation = true`, attribution button kept. Inputs `camera: MapCamera` (initial or fly-to), `parcels: Data?` (GeoJSON), `saveFrame: GeoBox?`. Callback `onRegionChange: (GeoBox, Double) -> Void` (visible bounds, zoom), sent from `regionDidChangeAnimated`.
- The key is read once: `Bundle.main.object(forInfoDictionaryKey: "DatafordelerApiKey") as? String`, treated as missing when empty or still `$(…)`.
- Start camera: `MapCamera.start(at: store.queryCoordinate?.point, isExact: store.queryCoordinate?.isExact ?? false)` (reuses `SeasonStore.queryCoordinate`, `App/JagtFokus/Store/SeasonStore.swift:96`).
- DEBUG `-map lat,lon,zoom` sets the start camera.

- [ ] **Step 1:** Add the package and config. `xcodebuild -resolvePackageDependencies -project App/JagtFokus.xcodeproj` resolves 6.31.x.
- [ ] **Step 2:** Implement `UserAgent`, `MapNetwork`, `MapTab` (a `NavigationStack` with the map full-bleed, inline title `Copy.mapTab`, system toolbar) and `ParcelMapView`.
- [ ] **Step 3:** Build, install, `xcrun simctl location booted set 56.1629,10.2039`, launch `-tab map`. Expected: liberty basemap over Aarhus, the location puck, and five tabs. Screenshot light and dark.
- [ ] **Step 4: Gate check.** A DEBUG log line counts the requests through `MapRequestProtocol`. Log show must have tile requests through it. If MapLibre bypasses `sessionConfiguration`, **stop and ask the user**: the fallback is to ask OpenFreeMap (info@openfreemap.org) to allow MapLibre's default parallelism for ~60-tile downloads.
- [ ] **Step 5:** Runtime-issues log (AGENTS.md › Run) is empty. If MapLibre's own location manager triggers the CoreLocation main-thread warning, give `MLNMapView` a custom `MLNLocationManager` that obeys the rule.
- [ ] **Step 6:** `swift test` green.
- [ ] **Step 7: Commit (local)** `git commit -m "Kort: MapLibre, fanen Kort og forespørgselsgrænse"`

---

### Task 5: App — live boundaries, labels, accuracy, info

**Files:**
- Create: `App/JagtFokus/Store/MapStore.swift`, `App/JagtFokus/Features/Map/MapStatusCard.swift`, `App/JagtFokus/Features/Map/MapInfoSheet.swift`
- Modify: `App/JagtFokus/JagtFokusApp.swift` — `@State private var map = MapStore()`, `.environment(map)` (same pattern as `BagStore`)
- Modify: `ParcelMapView.swift`, `MapTab.swift`
- Create: `App/JagtFokus/Assets.xcassets/Boundary.colorset` (`#C62828` both appearances). Modify `App/JagtFokus/DesignSystem/Theme.swift`: `static let boundary = Color("Boundary")` and `UIColor(named: "Boundary")` for MapLibre.
- Modify: `App/JagtFokus/Info.plist` — `NSLocationTemporaryUsageDescriptionDictionary` › `Skel`. Modify `InfoPlist.xcstrings` (Danish and English, from the Copy table).
- Modify: `Copy.swift` (`parcelDisclaimer` and the status strings), `tools/fill_string_catalog.py`

**Interfaces:**
```swift
@MainActor @Observable final class MapStore {
    enum Live: Equatable { case idle, loading, loaded, tooFarOut, offline, failed, noKey }
    private(set) var live: Live
    private(set) var index: OfflineAreaIndex          // filled in Task 6
    private(set) var visibleParcels: Data?            // saved ∪ live, GeoJSON
    private(set) var areaInView: OfflineArea?         // for "Gemt område: …"
    func regionChanged(_ box: GeoBox, zoom: Double)   // debounced 0.4 s, cancels the previous fetch
}
```
Behaviour:
- `zoom < MapRules.boundaryMinZoom` → `.tooFarOut`, no fetch.
- Saved areas intersecting the view are always included. A view fully inside one saved area makes no fetch.
- Otherwise, if `max(width, height) ≤ liveFetchMaxSideMeters`, fetch with `URLSession.shared` page by page (`startIndex += pageSize` until a page returns fewer than `pageSize`), `decodeChecked`, `merging`. Keep the last 8 boxes in memory.
- `.notConnectedToInternet` / `.networkConnectionLost` / `.timedOut` → `.offline`. HTTP 401/403 (an expired key) or any other failure → `.failed`. Saved areas still render in every state.
- Layers added in `mapView(_:didFinishLoading:)`:
  - `MLNShapeSource` "matrikel".
  - A white casing line (60 % opacity), then the `.boundary` line. Width interpolates 1 pt at zoom 13 to 2.5 pt at 18. `minimumZoomLevel = 13`.
  - `MLNSymbolStyleLayer` with text `{nr}`, `minimumZoomLevel = 16`, font `Noto Sans Regular` (check it against the liberty style's fonts), and a white halo.
  - Update the source's `shape` when `visibleParcels` changes.
- `MapStatusCard` sits in `.safeAreaInset(edge: .bottom)`, as a solid card (`Radius.large`), not glass. Text and an icon per state: `.loading` "Henter skel …", `.tooFarOut` "Zoom ind for at se skel", `.offline` "Uden net. Viser gemte områder.", `.failed` "Skel kunne ikke hentes.", `.noKey` "Kortet mangler adgang til Datafordeler.". Inside a saved area: "Gemt område: [navn], hentet [dato]".
- Reduced accuracy: read the accuracy authorization from MapLibre's location manager callback (`mapView(_:didChangeLocationManagerAuthorization:)`), not by polling. Show "Præcis position er slået fra" with a button "Brug præcis position" → `requestTemporaryFullAccuracyAuthorization(withPurposeKey: "Skel")` (Review Focus 5).
- Toolbar: `info.circle` → `MapInfoSheet` (title "Om kortet"): `Copy.parcelDisclaimer`, "Matrikelskel" + `Text(verbatim: CadastreService.attribution)` + a licence link, "Baggrundskort" + `Text(verbatim: OpenFreeMap.attribution)`. `location` button ("Centrér på din position") → `userTrackingMode = .follow`.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Copy: build, then `python3 tools/fill_string_catalog.py <stringsdata-dir>` until it writes.
- [ ] **Step 3:** With the key in `Secrets.xcconfig`, launch `-tab map -map 56.1629,10.2039,16`. Expected: red boundaries with matrikelnumre over Aarhus. Zoom below 13 → "Zoom ind for at se skel". Screenshots: light, dark, AX-L (`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL`), English (`-AppleLanguages "(en)"`).
- [ ] **Step 4:** Compare one parcel with the agency's own viewer at the same spot: shape and number match. This is the axis-order and projection check in the real app.
- [ ] **Step 5:** Runtime-issues log empty; `swift test` green.
- [ ] **Step 6: Commit (local)** `git commit -m "Kort: matrikelskel og numre fra Datafordeler"`

---

### Task 6: App — Gem område, Gemte områder, offline, stale packs

**Files:**
- Create: `App/JagtFokus/Store/BasemapPacks.swift` (wraps `MLNOfflineStorage`), `App/JagtFokus/Features/Map/SavedAreasView.swift`
- Modify: `MapStore.swift`, `MapTab.swift`, `ParcelMapView.swift`, `MapStatusCard.swift`, `Copy.swift`, `tools/fill_string_catalog.py`

**Interfaces:**
```swift
@MainActor final class BasemapPacks {
    /// MLNTilePyramidOfflineRegion(styleURL: OpenFreeMap.styleURL, bounds: box, zoom OpenFreeMap.packZoom),
    /// includesIdeographicGlyphs = false, context = id. Removes the half pack before throwing.
    func download(_ box: GeoBox, id: UUID, progress: @escaping (Double) -> Void) async throws -> Int   // bytes
    func remove(id: UUID) async
    func ids() async -> Set<UUID>
}

extension MapStore {
    enum Saving: Equatable { case idle, choosing, downloading(name: String, progress: Double), saved(String), failed }
    var saving: Saving { get }
    var saveFrame: GeoBox? { get }        // around the map centre while .choosing
    func beginSave()
    func save(name: String) async         // 4 quadrants × pages → merge → pack → commit
    func cancelSave()
    func delete(_ id: UUID) async         // pack + files
    func refreshStaleBasemaps() async     // online, on Kort appear
}
```
Flow:
- Toolbar **Gem område** → `.choosing`. The frame `GeoBox.around(centre, sideMeters: MapRules.saveSideMeters)` is drawn as a line layer and follows the centre. The card shows "5 × 5 km om midten" with **Gem** and **Annuller**.
- **Gem** → an alert with a `TextField` ("Navn") prefilled `index.nextDefaultName(prefix: String(localized: "Område"))` → `.downloading`. The card shows "Gemmer [navn] …", `ProgressView(value:)` and **Annuller**.
  - Parcels first: each of `box.quadrants()` page by page, then `merging`.
  - Then the pack. Assert the pack stays ≤ 3,000 tiles and ≤ 50 MB from `MLNOfflinePackProgress`, and log it.
  - Then fetch the TileJSON → `basemapTiles` → `OfflineAreaStore.commit`.
  - Any failure → `.failed` ("Området kunne ikke gemmes. Prøv igen med net."), the pack is removed, and nothing goes in the index (Review Focus 4).
- Toolbar **Gemte områder** (`square.stack.3d.down.right`) → sheet `SavedAreasView`. Rows show the name and "Hentet [dato] · [størrelse]" (`SeasonCalendar.dateTime`; `ByteCountFormatter` with the app locale). Swipe **Slet** (destructive). Tap → dismiss and fly to `area.box`. Empty: "Ingen gemte områder."
- Launch: `OfflineAreaStore.removeOrphans()`, and remove MapLibre packs whose id is not in the index.
- Kort appears while online → `refreshStaleBasemaps()`. Fetch the TileJSON. For each `staleBasemaps(currentTiles:)` area, re-download its pack under the same id, one at a time and silently. On success `replace` the area with the new `basemapTiles`. On failure keep the old one (Review Focus 2).

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Copy and catalog tool, as in Task 5.
- [ ] **Step 3:** Save an area at `56.1629,10.2039`. Log: pack tile count and bytes are within limits. Gemte områder shows it with date and size.
- [ ] **Step 4 (Review Focus 3):** Relaunch `-offline YES -tab map -map 56.1629,10.2039,16`. Expected: basemap and boundaries render, the card says "Uden net. Viser gemte områder." Panning outside the area shows no boundaries, the same card, and no alert.
- [ ] **Step 5 (Review Focus 4):** Start a save and kill the app mid-way. Relaunch: the area is not in the list, and the simulator container's `Library/Application Support/Kort` has no orphan file. Delete a saved area: its files and pack are gone after relaunch.
- [ ] **Step 6:** Runtime-issues log empty; `swift test` green.
- [ ] **Step 7: Commit (local)** `git commit -m "Kort: gem område til brug uden net"`

---

### Task 7: Indstillinger — attribution and disclaimer

**Files:**
- Modify: `App/JagtFokus/Features/About/AboutView.swift`:
  - **Ansvar**: `Label(Copy.parcelDisclaimer, systemImage: "square.dashed")`.
  - A new section **Kort** after Fotos: "Matrikelskel" + `Text(verbatim: CadastreService.attribution)` + a licence `Link`; "Baggrundskort" + `Text(verbatim: OpenFreeMap.attribution)` + a link to openfreemap.org; footer "Kortet bruger MapLibre, som er open source." (+ English "The map uses MapLibre, which is open source.").
- Modify: `Copy.swift`, `tools/fill_string_catalog.py`

- [ ] **Step 1:** Implement; build; run the catalog tool; check `-tab settings` in Danish, English and AX-L.
- [ ] **Step 2: Commit (local)** `git commit -m "Kort: kilde og forbehold i Indstillinger"`

---

### Task 8: Privacy, App Store answers, docs (pushed together with Tasks 4–7)

**Exact changes:**
- `docs/privatliv.html`:
  - Header date → the day of the change.
  - New `<h2>Kort</h2>` after Vejr:
    > Fanen Kort henter baggrundskortet fra OpenFreeMap (tiles.openfreemap.org) og matrikelskel fra Klimadatastyrelsens Datafordeler (wfs.datafordeler.dk). Der sendes kun det udsnit af kortet, der skal vises eller gemmes. Ikke din position og ikke noget om dig. Udsnittet ligger ofte der, hvor du er. Som ved ethvert besøg på en hjemmeside kan tjenesterne se telefonens IP-adresse. Din position vises på kortet, men bliver på telefonen. Kortet bruger MapLibre, som er open source og ikke sender data om dig. Vilkårene er <a href="https://openfreemap.org/tos/">OpenFreeMaps vilkår</a> og <a href="https://datafordeler.dk/vejledning/brugervilkaar/ejendomsoplysninger-ebr-og-mat/">Datafordelers brugervilkår</a>.
  - In "Det gemmer appen på telefonen": `<li>Kortområder, du gemmer til brug uden net, og et lille lager af kort, du har set. Et gemt område slettes, når du sletter det eller appen.</li>`
- `AboutView.swift` › Privatliv:
  - Label "Positionen bruges kun til sted, sol, vejr og kort".
  - Footer "Vejret hentes fra MET i Norge med din position afrundet til omkring en kilometer. Kortet hentes fra OpenFreeMap og Datafordeler ud fra det udsnit, du ser. Stednavnet slår Apple op. Vi får aldrig din position."
  - English for both in `ENGLISH`; remove the replaced keys.
- `WelcomeView.swift:38` → "Ingen konto. Ingen tracking. Din position bruges kun til sted, sol, vejr og kort."
- `project.pbxproj` `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` (both configurations) and `InfoPlist.xcstrings` → "JagtFokus bruger din position til at vise jagttider, sol og vejr for det sted, du er, og hvor du står på kortet." (English: "JagtFokus uses your location to show hunting seasons, sun and weather for where you are, and where you stand on the map.")
- `spec/appstore/README.md`:
  - App-privatliv: "Ingen konto, analyse, reklamer eller tredjeparts-SDK'er." → "Ingen konto, analyse eller reklamer. Kortet bruger MapLibre (open source, ingen telemetri, eget privatlivsmanifest)."
  - Add a bullet: "Kortet henter fliser fra OpenFreeMap og matrikelskel fra Datafordeler for det udsnit, der vises eller gemmes. Ingen position, intet om brugeren. Gemte områder ligger på telefonen."
  - The answer stays **Data indsamles ikke**.
  - App Review notes: a "Map tab" paragraph (Danish agency boundaries, map box only, offline areas, no account).
  - Checklist: "`App/Config/Secrets.xcconfig` with the Datafordeler key on the archiving Mac. The key expires 2 years after creation."
  - Do not change the listing text or keywords without asking the user.
- `tools/bump_build.sh`: stop with a message when `App/Config/Secrets.xcconfig` is missing or `DATAFORDELER_API_KEY` is empty, so no build ships without boundaries.
- `App/JagtFokus/PrivacyInfo.xcprivacy`: unchanged. No new required-reason API (file dates and disk space are avoided by design); MapLibre carries its own manifest. Confirm both in the archive's privacy report (Xcode › Organizer › Generate Privacy Report).
- `AGENTS.md`:
  - Stack: "Map | MapLibre Native iOS (SPM), OpenFreeMap basemap, Datafordeler matrikel WFS (`apikey`)".
  - Layout: `Features/Map/`, `App/Config/`, `plans/`.
  - Screens: **Kort** as screen 2; "Five tabs: Jagtbart, Kort, Journal, Alle arter, Indstillinger".
  - Rules: "Boundaries are display only. No logic may use them." and "OpenFreeMap downloads: ≤ 4 parallel, own User-Agent, ≤ 3,000 tiles / 50 MB per area."
  - Run: key setup; debug args `-tab map`, `-map lat,lon,zoom`, `-offline YES`.
  - Test count.
- `spec/design.md`:
  - Colour table row `Boundary`.
  - Screen section **Kort**.
  - Decision entry "Kort (2026-10-20)" with the planner's calls from Context and the Dataforsyningen → Datafordeler move.

- [ ] **Step 1:** Make the changes. The catalog tool writes.
- [ ] **Step 2:** `swift test` green. Build, install, launch Danish and English, and read every changed screen.
- [ ] **Step 3: Commit (local)** `git commit -m "Kort: privatliv, App Store-svar og dokumentation"`
- [ ] **Step 4:** Ask the user before pushing Tasks 1–8 to `main`. The push publishes the privacy page.

---

## Verification (end to end)

1. `swift test` → green (127 + new Core tests). CI runs the same on push.
2. Build, install and launch on iPhone 18 Pro; `xcrun simctl location booted set 56.1629,10.2039`.
3. Kort: puck at Aarhus, boundaries, numbers from zoom 16, hint below zoom 13. Light, dark, AX-L, English.
4. One parcel matches the agency's own viewer (shape and number).
5. Save an area, then relaunch with `-offline YES`: boundaries and basemap inside the area, a calm card outside.
6. Kill the app mid-save: no half area, no orphan file.
7. Approximate location (Indstillinger › Anonymitet › Lokalitet › JagtFokus › Præcis fra): the line and the button appear.
8. Runtime-issues log empty. Jagtbart, Journal and Alle arter are unchanged (boundaries drive no logic).
