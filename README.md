# JagtFokus

iPhone app: **hvad må jeg jage i dag, her?** Danish hunting seasons by date and place.

v1, including the hunting journal, is in `spec/v1.md`. The bag report is not built (`spec/v2.md`). Design and UX: `spec/design.md`. Agent guide: `AGENTS.md`.

## Run the app

1. Install Xcode from the App Store.
2. Open `App/JagtFokus.xcodeproj`.
3. Pick a simulator or an iPhone.
4. Set your Team under Signing.
5. Run.

Requires iOS 18. Bundle id: `dk.jagtfokus.app`.

## Data and tests

Seasons: `data/jagttider.json` (BEK 470/2024, SGAV table from 1 July 2024). Biology: `App/JagtFokus/Resources/biologi.json` (DOF and Arter.dk). Biology is not part of the season data.

```sh
swift test
```

72 tests cover open/closed, the year boundary, next opening, last day, the hunting-year timeline, local seasons, GPS place matching, sun times, photo licenses, and biology.

Remote JSON: GitHub raw. Until the repo is public, the app uses the bundled file.

## Not in v1

Sunset alarm, log beyond the journal, dogs, recipes, Android.
