# Ideer (efter v1)

v1 står i `spec/v1.md` og inkluderer jagtjournalen. Indberetning er ikke bygget (`spec/v2.md`). Nedenfor er resten af backloggen.

## Med i V1:

Soltider og Indstillinger (tema) er flyttet til `spec/v1.md` (2026-10-11).

- Kron- og dåvildt som kortbilag (regionale forvaltningsplaner)
- Sted som kort/pin i stedet for liste
- Jagttider for et givent sted

## Senere

- Alarm/vibration 10 minutter før solnedgang
- Vind ved solopgang og solnedgang på Sol og vejr: morgen- og aftenjagten afgøres af vinden da, ikke af dagens kraftigste
- Jagt-log (ud over journalen i v1)
  - Placering (GPS / manuelt)
  - Vejret på dagen
    - Vindretning
  - Antal skud
- Hunde-log
  - Antal apporteringer (vildtart, succes eller ej)
- Infosider
  - Jagtetiske regler
  - Praktisk hjælp (plukke fugle, osv.)
  - Jagtrelaterede opskrifter
- Nærmeste schweisshundefører i appen (navn og telefon, sted fra GPS eller manuelt). Venter på tilladelse fra Schweiss-sekretariatet. Ingen scrape. Infosiden er i v1


- Android / Google Play
- Engelsk

- Brande appen for f.eks Huntinglife mod et lille beløb, der kan dække omkostningerne ved at holde det kørende.


## UX-ideer (fra designgennemgang 2026-10-11)

- Søgefane (`Tab(role: .search)`, iOS 26-mønster) på tværs af arter i stedet for søgefelt pr. liste
- Filter Pattedyr / Fugle på Jagtbar
- Widget: “N arter jagtbare i dag her” (WidgetKit, samme `SeasonStatus`)
- Påmindelse når en valgt art åbner (lokal notifikation, ingen konto)
- UI-tests med launch-argumenterne fra AGENTS.md (screenshots til App Store)
