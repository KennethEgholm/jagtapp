# JagtFokus

iPhone-app: **hvad må jeg jage i dag, her?** Danske jagttider efter dato og sted.

v1 er frosset i `spec/v1.md`. v2 (Vildtudbytte) ligger i `spec/v2.md` på branch `v2/vildtudbytte` og er ikke med i App Store-v1. Design og UX: `spec/design.md`. Agent-guide: `AGENTS.md`.

## Kør appen

1. Installer Xcode fra App Store.
2. Åbn `App/JagtFokus.xcodeproj`.
3. Vælg simulator eller iPhone.
4. Sæt dit Team under Signing.
5. Run.

Kræver iOS 18. Bundle id: `dk.jagtfokus.app`.

## Data og tests

Jagttider: `data/jagttider.json` (BEK 470/2024, SGAV-tabel fra 1. juli 2024).

```sh
swift test
```

59 tests dækker åben/lukket, årsskifte, næste åbning, sidste dag, jagtårs-tidslinje, lokale tider, GPS-stedmatch, soltider og fotolicenser.

Remote JSON: GitHub raw. Indtil repo er public, bruger appen den indbyggede fil.

## Ikke i v1

Soltider, log, hunde, opskrifter, Android.
