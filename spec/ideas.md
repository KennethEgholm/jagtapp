# Ideer (efter v1)

v1 er frosset i `spec/v1.md`. Nedenfor er backlog.

## Med i V1:

Soltider og Indstillinger (tema) er flyttet til `spec/v1.md` (2026-10-11).

- Kron- og dåvildt som kortbilag (regionale forvaltningsplaner)
- Sted som kort/pin i stedet for liste
- Jagttider for et givent sted

## Senere

- Alarm/vibration 10 minutter før solnedgang
- Jagt-log
  - Automatisk indberetning af udbytte
  - Spørg om API adgang her: https://sgavmst.dk/kontakt
  - Placering (GPS / manuelt)
  - Vejret på dagen
    - Vindretning
  - Udbytte på dagen
  - Antal skud
- Hunde-log
  - Antal apporteringer (vildtart, succes eller ej)
- Infosider
  - Jagtetiske regler
  - Praktisk hjælp (plukke fugle, osv.)
  - Jagtrelaterede opskrifter
- Anskudt vildt
  - Schweisshunderegister - sted fra GPS eller manuelt

- Android / Google Play
- Engelsk

## UX-ideer (fra designgennemgang 2026-10-11)

- Søgefane (`Tab(role: .search)`, iOS 26-mønster) på tværs af arter i stedet for søgefelt pr. liste
- Filter Pattedyr / Fugle på Jagtbar
- Widget: “N arter jagtbare i dag her” (WidgetKit, samme `SeasonStatus`)
- Påmindelse når en valgt art åbner (lokal notifikation, ingen konto)
- Icon Composer-ikon (lag + Liquid Glass) i stedet for flad PNG
- String Catalog (`Localizable.xcstrings`) før engelsk
- UI-tests med launch-argumenterne fra AGENTS.md (screenshots til App Store)

