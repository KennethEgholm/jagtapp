# JagtFokus — design og UX

Levende dokument. Gælder alle skærme. Bygger på Apple Human Interface Guidelines (iOS 18–27, Liquid Glass fra iOS 26).

## Principper

1. **5 sekunder.** Svaret står øverst: hvor mange arter er jagtbare, hvornår, hvor. Alt andet er ét tryk væk.
2. **Systemet først.** Standard-SwiftUI (List, NavigationStack, sheets, TabView, searchable). Ingen egne navigationsmønstre. Liquid Glass kommer gratis med systemets bars.
3. **Status med mere end farve.** Altid tekst + ikon/form. Farve er ekstra.
4. **Appen er ikke loven.** Noter vises som tekst. Kilde og fraskrivelse er altid ét tryk væk.
5. **Én kilde til tokens.** Farver, afstande og komponenter ligger i `App/JagtFokus/DesignSystem/`. Nye skærme bruger dem.

## Farver (Assets.xcassets)

| Token | Lys | Mørk | Brug |
|---|---|---|---|
| `AccentColor` (Forest) | `#2F6B47` | `#7FC79A` | Tint, Jagtbar-status, valgt |
| `Brass` | `#7A5C17` | `#D9B65E` | Lokal jagttid-mærke |
| `Amber` | `#A35200` | `#FFB547` | Lukker snart |
| `BrandDeep` | `#0D2A1C` | `#0D2A1C` | Velkomst-baggrund (fra ikonet) |

Kontrast er ≥ 4,5:1 mod systembaggrunde i begge tilstande (WCAG AA). Resten er systemfarver (`.primary`, `.secondary`, grouped backgrounds).

## Typografi og afstand

- Kun SF Pro via Dynamic Type-stilarter (`.title2`, `.headline`, `.subheadline`, `.footnote`). Ingen faste punktstørrelser i tekst.
- Datoer med `monospacedDigit()` hvor de står i kolonne.
- Afstande: 4, 8, 12, 16, 24 (`Spacing`). Hjørner: continuous, 12/16/22.
- Trykflader ≥ 44 × 44 pt.

## Komponenter

- **SeasonBar** (`DesignSystem/SeasonBar.swift`) — jagtåret 1. apr → 31. mar som en vandret bjælke med månedsskel. Alle perioder i data er sammenhængende i det vindue. Valgfri markør for valgt dato (kun med dato-kontekst).
- **SeasonStatusText** (`StatusViews.swift`) — trailing status i rækker: “til 31. jan”, “⏳ Sidste dag 15. okt”, “åbner 1. nov”.
- **StatusSummary** (`SpeciesDetailView.swift`) — stor Jagtbar / Ikke jagtbar med sidste dag eller åbning.
- **LocalBadge** — “Lokal jagttid”, brass. Vises når en lokal override gælder.
- **SpeciesRow** — navn, perioder, note (maks 2 linjer), evt. LocalBadge, evt. status. Tryk → detalje. `SpeciesContext.query` / `.general` styrer om status må vises.
- **QueryRows / QueryRow** — dato- og sted-række (Settings-stil med IconTile).
- **AnswerCard** — svaret på Jagtbar: antal jagtbare.
- **ListHeading** + `scrollRevealedTitle` — stor ombrydende overskrift i indholdet, titel i baren ved scroll.
- **IconTile**, **BrandMark** (`Theme.swift`).
- **SunRow** (`QueryHeader.swift`) — “Sol” med ⬆︎ solopgang og ⬇︎ solnedgang (orange hierarkiske symboler, tid i primær farve), “ca.” når tiden er for et repræsentativt punkt. Ikke trykbar.

## Skærme

### Jagtbar
- Overskrift i indholdet: “Jagtbart vildt efter tid og sted”. Navigationstitel “Jagtbart” vises først ved scroll.
- To rækker: **Dato** (I dag · lørdag 11. oktober) og **Sted** (Midtjylland · Din position). Fuld bredde, ingen afkortning. Åbner sheets.
- Svar-kort: stort tal + “arter er jagtbare” + “3 har sidste dag inden for en uge” (amber), ellers dag og sted.
- Liste: kun jagtbare arter, grupperet. Trailing: “til 31. jan”, eller “⏳ Sidste dag 15. okt” (amber) når sidste dag er inden for 7 dage.
- Nederst: sammenfoldet sektion “Ikke jagtbar her (n)” med “Åbner 1. nov”. Holder hovedlisten ren, men svarer på “hvornår må jeg?”.
- Tom tilstand: svar-kortet viser 0 og næste åbning (“Næste: Canadagås på omdriftsarealer, 1. aug”). “Ikke jagtbar her” foldes ud.
- Ingen søgning her: skærmen skal være rolig. Søgning bor på Alle arter. Træk for at opdatere (position + data).
- Position nægtet: inline-besked med “Åbn Indstillinger”.

### Soltider (på Jagtbar)
- Tredje række under Dato og Sted. Klokkeslæt i dansk format (“07.42”), afrundet til nærmeste minut som almanakker.
- GPS: præcist. Valgt sted: stedets punkt + “ca.” + footer “Soltider for et punkt i Als.”
- Kun visning. Listen afgøres stadig af dato og sted.

### Alle arter
- Generelle jagttider, grupperet, søgbar. Hver række har SeasonBar uden markør.
- Ingen dato, intet sted, ingen åben/lukket.

### Artsdetalje (push)
- Navn som stor, ombrydende overskrift i indholdet (lange navne som “Grågås på omdriftsarealer” afkortes ellers i en large title). Gruppen står over navnet.
- Fra Jagtbar: status for valgt dato og sted, SeasonBar med markør, perioder med fulde datoer, lokal tid vs. generel tid, note, kilde.
- Fra Alle arter: kun generel tid, SeasonBar uden markør, note, kilde. Ingen status.

### Artsfoto
- Under overskriften på artsdetaljen: foto i 3:2, afrundede hjørner (`Radius.xlarge`), kredit under i `caption2`: “Foto: Navn · Licens · Wikimedia Commons”, link til Commons-siden.
- Foto matcher køn/alder i artsnavnet (Kronhind = hind, Vildsvin, so og grise = grise). Grågås/Canadagås på omdriftsarealer deler foto med arten.
- Tekst i en List-række med klar baggrund skal holde afstand til rækkens afrundede hjørner. Ellers klipper iOS det første bogstav.

### Journal (v1)

- Fane **Journal** (`plus.circle`) mellem Jagtbart og Alle arter. Overskrift på siden: “Jagtjournal”. Jagtbart har ingen knap til det.
- Swipe til venstre på en artsrække i **Jagtbart** eller **Alle arter** har handlingen **Journal** (`plus.circle`): noterer 1 stykke og skifter til **Journal**-fanen med bekræftelsen klar.
- Artsdetaljen har en række **Tilføj til journal** med `IconTile`, der noterer 1 stykke og skifter til **Journal**-fanen.
- Fanen starter med række “Nedlagt vildt” (årets antal), så Dato og Sted, samme rækker som Jagtbart. Standard: i dag og din position. Et andet valg ændrer ikke Jagtbart, men listen under følger med.
- Store rækker i `.title2`, ombryder. Senest nedlagt, så jagtbart for den dato og det sted. Søgning er en knap, ikke et åbent felt. Plus-ikonet er ikke jagtbar-grønt.
- Tryk gemmer ét stykke. Bekræftelse bliver nede: “[Art] noteret”, **Fortryd** og **+1**.
- Årets liste: jagtår og antal stykker. Tom liste siger “Ingen poster.”, ikke noget om pligt.

### Indstillinger
- Fane (gearshape) mellem Alle arter og Om.
- Udseende: inline-picker System / Lys / Mørk med symboler. Anvendes via `overrideUserInterfaceStyle` på alle vinduer, så sheets følger med.

### Om
- Mærke + navn + version. Kilde (navn, opdateret, link, datastatus). Ansvar. Privatliv.

### Velkomst (første start)
- Mørkegrøn brand-baggrund, mærke, tre punkter (dato og sted, lokale tider, offline), fraskrivelse, knap “Forstået”.
- Forklarer positionsbrug før systemets dialog.

## Tilgængelighed

- VoiceOver: hver række er ét element med fuld tekst (“Råbuk. Jagtbar. 1. oktober til 31. januar. Lokal jagttid.”). Måneder udtales fuldt.
- Dynamic Type op til AX-størrelser. Rækker ombryder i stedet for at afkorte.
- Haptik (`sensoryFeedback(.selection)`) ved skift af dato/sted.
- Reduce Motion: kun systemets standardanimationer.

## Beslutninger (2026-10-11)

- “Jagtbar”-tekst på hver række fjernet: listen viser kun jagtbare. Status vises som opsummering, i detalje og i “Ikke jagtbar”-sektionen.
- Dato/sted som rækker i stedet for chips: chips afkortede stednavnet.
- App-ikonet var et kort med hvide kanter. Erstattet af fuldt kvadratisk ikon (samme motiv, baggrund forlænget).
- Xcode-gruppen `JagtFokus` er en synkroniseret mappe: nye `.swift`-filer kommer automatisk med i target.
- Søgning fjernet fra Jagtbar: den skubbede overskriften ned og gav en tom bar. Alle arter og stedvælger har søgning.
- Overskrifter i indhold + navigationstitel der toner frem ved scroll (`scrollRevealedTitle`). Samme mønster på Jagtbar og artsdetalje.
- Haptik kun ved brugerens egne valg (`userSelections`), ikke når GPS lander eller dagen skifter.
- Rækker stables lodret ved AX-tekststørrelser (`dynamicTypeSize.isAccessibilitySize`).
- Fejl fundet undervejs: `isLeapYear` regnede alle år som skudår (`Calendar.date(from:)` ruller 29. feb videre i stedet for at returnere nil). Rettet og testet.
- Fejl fundet i review: GPS-stedmatch brugte delstrenge, så “Hals”, “Nørre Alslev” og “Marstalsgade” blev til Als, og “Ry” til Strynø. Det kunne vise en art som jagtbar før den lokale start. Nu kræves hele navne (uden “ Kommune”). Rettet og testet.
- “Lokal jagttid” stod to gange (badge + note “Lokal jagttid.”). Pladsholder-noter i overrides er nu `null` (data v3), og en lokal tid viser kun sin egen note, ikke den generelle “Der findes lokale jagttider.”.
- Artsfotos (2026-10-11): 49 fotos til 51 arter fra Wikimedia Commons, bundlet (~8,6 MB) så de virker offline. Kun licenser til kommerciel brug.
- Soltider og Indstillinger flyttet ind i v1 (2026-10-11). Knappen til iOS’ Indstillinger hedder nu “Åbn Indstillinger-appen”, så den ikke forveksles med appens egen fane.
- Multicolor-symbolerne for solopgang/solnedgang tegner pilen hvid og usynlig i lyst tema. Bruger hierarkisk orange.
- Position slået fra rydder det sidste GPS-sted. Mislykket opdatering beholder det og siger det. Ny katalog-version matcher stedet igen.
- Vildtudbytte-sheets (2026-10-14) bruger inline titel som de andre sheets. Årssummen genbruger svar-kortets tal.
- Nedlagt er en fane (2026-10-14), ikke en knap på Jagtbar. “Allerede nedlagt” er første række på fanen.
- Fanen hedder **Journal**, overskriften **Jagtjournal**, rækken **Nedlagt vildt** og knappen **Tilføj til journal** (2026-10-14). Menuen **Jagtbar** hedder **Jagtbart**. Status “Jagtbar / Ikke jagtbar” er uændret.
