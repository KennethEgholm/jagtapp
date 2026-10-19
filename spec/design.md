# JagtFokus — design og UX

Levende dokument. Gælder alle skærme. Bygger på Apple Human Interface Guidelines (iOS 18–27, Liquid Glass fra iOS 26).

## Principper

1. **5 sekunder.** Svaret kan ses uden at scrolle ved normal tekststørrelse: hvor mange arter er jagtbare, hvornår, hvor. Alt andet er ét tryk væk.
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
| `BrandDeep` | `#0D2A1C` | `#0D2A1C` | Velkomst-baggrund |
| `BrandGold` | `#D9B65E` | `#D9B65E` | Velkomst: knap, ikoner, “Vigtigt”-ramme |

Tokens i kode (`Theme.swift`), ikke i Assets:

| Token | Værdi | Brug |
|---|---|---|
| `.forest` | `#2F6B47` fast | `IconTile`-felt. Lys accent er for bleg bag hvidt symbol i mørk tilstand |
| `.sun` | systemets orange | Solopgang og solnedgang på sol-kortet og Sol og vejr. Kun visning, ikke status. Vejr- og måneikoner er sekundære (grå) |
| `.brandGlow` | `#214D33` | Lyset i velkomstens baggrund |

Kontrast er ≥ 4,5:1 mod systembaggrunde i begge tilstande (WCAG AA). Resten er systemfarver (`.primary`, `.secondary`, grouped backgrounds). Views bruger tokens, aldrig RGB eller hex.

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
- **DatePlaceRows / QueryRow** (`DesignSystem/QueryRow.swift`) — dato- og sted-række (Settings-stil med IconTile), med positionsproblemet i footeren. Jagtbart og Journal giver hver sit valg. Footeren siger, hvad rækken viser: sidst kendte sted eller hele Danmark.
- **CountCard** (`DesignSystem/CountCard.swift`) — stort tal med en linje ved siden af. **AnswerCard** på Jagtbart og årssummen i journalen bruger det.
- **GroupHeader / FoldButton / FoldChevron** (`DesignSystem/GroupHeader.swift`) — gruppens række på Jagtbart og Alle arter: tegning, navn, antal, pil. `FoldButton` folder sektionen og giver VoiceOver “Vist / Skjult”. “Ikke jagtbar her” bruger samme knap og pil.
- **ListHeading** + `scrollRevealedTitle` — stor ombrydende overskrift i indholdet, titel i baren ved scroll. Kun hvor titlen er lang eller har en linje over sig (eyebrow): Jagtbart, artsdetaljen, Schweiss-registret og Sol og vejr (stedet og datoen over titlen). Korte titler (Journal, Alle arter, Indstillinger) bruger systemets store titel.
- **IconTile**, **BrandMark** (`Theme.swift`).
- **GroupSketch** (`DesignSystem/GroupSketch.swift`) — stregtegning ved gruppenavnet. Kronhjort, ræv, hare, and, gås, fasan, lille fugl. Primær farve, ikke grøn: den er pynt, ikke status. Skjult for VoiceOver. Ukendt gruppe får en ring.
- **SunRow** (`Features/Today/SunRow.swift`) — sol-kortet, bygget som `QueryRow`: orange IconTile, lille titel “Sol og vejr”, så ⬆︎ solopgang og ⬇︎ solnedgang som værdien (orange hierarkiske symboler, tid i primær farve). Under tiden korte sekundære linjer: “Maks 11,9° · Min 9,2° · 0 mm” med dagens vejrsymbol og “Op til 6,8 m/s fra Ø” med kompaspilen (kun inden for MET’s horisont), så månen (“57 % oplyst”, altid). Til sidst “[Sted], den [dato]”. Alle ikoner står i én kolonne, så teksten efter dem starter samme sted. Ved AX-størrelser forsvinder IconTile, og tiderne stables. Tryk åbner Sol og vejr.
- **WindArrow** (`DesignSystem/WindArrow.swift`) — kompaspilen. Peger der, vinden blæser hen (fra øst → pil mod vest), som på vejrkort. Teksten siger altid “fra Ø” ved siden af, så pilen ikke står alene.

## Skærme

### Jagtbar
- Overskrift i indholdet: “Jagtbart vildt efter tid og sted”. Navigationstitel “Jagtbart” vises først ved scroll.
- To rækker: **Dato** (I dag · lørdag 11. oktober) og **Sted** (Midtjylland · Din position). Fuld bredde, ingen afkortning. Åbner sheets.
- Kortene står 24 pt fra hinanden (`listSectionSpacing(Spacing.l)`), lidt tættere end systemets ca. 35 pt.
- Sol-kort lige under Dato og Sted (se Soltider). Dato, sted og dagens sol og vejr hører sammen.
- Svar-kort under sol-kortet, som overskrift for grupperne, det tæller: stort tal + “arter er jagtbare” + “⏳ 3 har sidste dag inden for en uge” (amber, med timeglas), ellers dag og sted. Ved normal tekststørrelse står det over fanebaren uden at scrolle. Ved AX-størrelser skal man scrolle (valgt 2026-10-19).
- Liste: kun jagtbare arter. Hver gruppe er et kort, der starter sammenfoldet. Rækken viser en stregtegning, navn, antal og en pil. Har gruppen arter med sidste dag inden for en uge, står “⏳ 2 har sidste dag inden for en uge” i amber under navnet, også når gruppen er lukket. Så kan advarslen på svar-kortet findes uden at åbne hver gruppe. Kun på Jagtbart: Alle arter viser ingen status. Trailing i en åben gruppe: “til 31. jan”, eller “⏳ Sidste dag 15. okt” (amber) når sidste dag er inden for 7 dage.
- Nederst: sammenfoldet sektion “Ikke jagtbar her (n)” med “Åbner 1. nov”. Holder hovedlisten ren, men svarer på “hvornår må jeg?”.
- Tom tilstand: svar-kortet viser 0 og næste åbning (“Næste: Canadagås på omdriftsarealer, 1. aug”). “Ikke jagtbar her” foldes ud.
- Ingen søgning her: skærmen skal være rolig. Søgning bor på Alle arter. Træk for at opdatere (position + data).
- Position nægtet: inline-besked med “Åbn Indstillinger”.

### Soltider (på Jagtbar)
- Eget kort lige under Dato og Sted, over svar-kortet. Ikke en række i Dato og Sted. Klokkeslæt i dansk format (“07.42”), afrundet til nærmeste minut som almanakker.
- Under tiden: “[Sted], den [dato]”, samme sted og dato som rækkerne ovenfor. Fx “Sjælland, den 16. oktober”.
- Kun visning. Listen afgøres stadig af dato og sted.
- Tryk på kortet skubber **Sol og vejr** ind for samme dag og sted. Kortet og siden hedder det samme, så trykket lander, hvor det siger.

### Sol og vejr (push fra sol-kortet)
- Bygget som artsdetaljen: `ListHeading` med “[Sted], den [dato]” over titlen “Sol og vejr”, så almindelige sektioner med systemets overskrifter og rækker som `LabeledContent` (ikon og navn til venstre, værdi til højre, evt. en lille note under værdien). Ingen fliser, intet guld: siden skal ligne resten af appen.
- Tre sektioner, og hver overskrift siger, hvilke timer tallene gælder:
  - **Resten af dagen** (i dag) / **Hele dagen** (senere dage): Vejret (symbol + ord), Temperatur (“Maks 11,9° · Min 9,2°”), Nedbør (mm), Kraftigste vind (“6,8 m/s fra Ø”). Samme tal som kortet. I dag starter MET’s prognose ved den aktuelle time, derfor “resten af dagen”.
  - **Nu** (i dag) / **Midt på dagen** (senere dage): Temperatur, Vind, Fugtighed, Lufttryk (“1034 hPa”, note “↓ Faldende” — trykkets bevægelse over de næste tre timer, ±0,3 hPa grænse).
  - **Sol og måne**: Solopgang, Solnedgang, Månen (fase, note “57 % oplyst”). Footer: kilden.
- Ikoner: solens er orange (`.sun`), alt andet er sekundært. Vejr er ikke status, så ingen grøn.
- Referencetimen er den time, der ligger nærmest nu, når den valgte dag er i dag, ellers kl. 12. Nedbør tælles time for time, så længe MET har timer (`next_1_hours`), og derefter i MET’s seks-timers skridt. Skridtene følger efter hinanden uden overlap, så samme regn aldrig tælles to gange. Fra ca. tredje dag ligger MET’s skridt kl. 00, 06, 12 og 18 UTC — 02, 08, 14 og 20 dansk sommertid — ikke på det danske ur. Dagens symbol er den vådeste blok, ellers blokken over middag, ellers den første tilbage (i dag efter middag: eftermiddagen, ikke nattens symbol).
- Vejr fra MET Norway Locationforecast 2.0 (compact), hentet ved tryk og af sol-kortet. Koordinater afrundes til to decimaler. Svaret genbruges i ti minutter. Skærmen lover intet om “jagtbar nu”: vejret er kun visning.
- Ingen vejr-data (datoen er i fortiden eller MET’s horisont på ca. ti dage): én række om det, og solen og månen står stadig. Fejl eller offline: samme mønster. Kortlægningen af MET’s symbolkoder bor i `Features/Weather/WeatherSymbols.swift`.
- Sol og måne beregnes på telefonen (`SunTimes`, `MoonPhase` i `JagtFokusCore`), ligesom månefasen. Måneflisen står altid.
- Footer: “Kilde: Meteorologisk institutt (MET). Vejr og måne er kun visning.” Kreditering er også et licenskrav (NLOD/CC BY 4.0).
- Ved AX-tekststørrelser stabler `LabeledContent` selv navn og værdi under hinanden.

### Alle arter
- Generelle jagttider, grupperet, søgbar. Hver række har SeasonBar uden markør.
- Ingen dato, intet sted, ingen åben/lukket.
- Hver gruppe er et kort, der starter sammenfoldet. Rækken viser en stregtegning, navn, antal og en pil. Tryk folder ud. Søgning folder de grupper ud, der har træf, uden et ekstra tryk.

### Artsdetalje (push)
- Navn som stor, ombrydende overskrift i indholdet (lange navne som “Grågås på omdriftsarealer” afkortes ellers i en large title). Gruppen står over navnet.
- Fra Jagtbar: status for valgt dato og sted, SeasonBar med markør, perioder med fulde datoer, lokal tid vs. generel tid, note, kilde.
- Fra Alle arter: kun generel tid, SeasonBar uden markør, note, kilde. Ingen status.
- **Biologi** under noten, før jagtkilden. Latinsk navn, “I Danmark” og “Yngel”. Køn og alder deler artens opslag. Kildelink under teksten. Footer: “Biologisk opslag. Ikke jagtloven.” Ingen bestandsestimater. Ingen logik bruger teksten.

### Artsfoto
- Under overskriften på artsdetaljen: foto i 3:2, afrundede hjørner (`Radius.xlarge`), kredit under i `caption2`: “Foto: Navn · Licens · Wikimedia Commons”, link til Commons-siden.
- Foto matcher køn/alder i artsnavnet (Kronhind = hind, Vildsvin, so og grise = grise). Grågås/Canadagås på omdriftsarealer deler foto med arten.
- Tekst i en List-række med klar baggrund skal holde afstand til rækkens afrundede hjørner. Ellers klipper iOS det første bogstav.

### Journal (v1)

- Fane **Journal** (`book.closed`) mellem Jagtbart og Alle arter. Systemets store titel: “Jagtjournal”. Jagtbart har ingen knap til det. Faneikonet viser et sted i appen. Swipe-handlingen beholder `plus.circle`, for den er en handling.
- Swipe til venstre på en artsrække i **Jagtbart** eller **Alle arter** har handlingen **Journal** (`plus.circle`): noterer 1 stykke og skifter til **Journal**-fanen med bekræftelsen klar.
- Artsdetaljen har en række **Tilføj til journal** med `IconTile`, der noterer 1 stykke og skifter til **Journal**-fanen. Ingen pil: rækken er en handling, ikke navigation.
- Fanen starter med række “Nedlagt vildt” (årets antal), så Dato og Sted, samme rækker som Jagtbart. Standard: i dag og din position. Et andet valg ændrer ikke Jagtbart, men listen under følger med.
- Store rækker i `.title2`, ombryder. Senest nedlagt, så jagtbart for den dato og det sted. Søgning er en knap, ikke et åbent felt. Plus-ikonet er ikke jagtbar-grønt.
- Tryk gemmer ét stykke. Bekræftelse bliver nede: “[Art] noteret”, **Fortryd** og **+1**.
- Årets liste: jagtår og antal stykker. Tom liste siger “Ingen poster.”, ikke noget om pligt.
- **Artsliste** under Nedlagt vildt. Arter nedlagt mindst én gang. Én art én gang. Tilføj selv, eller notér i journalen. Sletning i journalen fjerner ikke arten. Swipe fjerner kun fra artslisten. Tom liste siger “Ingen arter.”

### Indstillinger
- Sidste fane (gearshape), efter Alle arter. Fire faner i alt. Øverst indstillingerne, så Om i samme liste (se nedenfor).
- Udseende: inline-picker System / Lys / Mørk med symboler. Anvendes via `overrideUserInterfaceStyle` på alle vinduer, så sheets følger med.
- Lister: **Sammenfold grupper** (standard til). Gælder Jagtbart og Alle arter. Fra: grupperne er altid åbne, uden pil. Stregtegningen bliver. “Ikke jagtbar her” foldes stadig.

### Om (i Indstillinger)
- Ikke en fane. Sektionerne står under indstillingerne i samme liste: Data, Ansvar, Schweiss-registret, Fotos, Privatliv, Denne app. Ikke en push, så kilde og fraskrivelse stadig er ét tryk væk (princip 4).
- Nederst: sektion **Denne app** med mærke + navn, **Version** (`1.0 (1)`, udgivelse og build) og **Dataversion** (`v6`). Samme udgivelsesnummer som App Store-arkivet.
- Række **Schweiss-registret** åbner infosiden (push).

### Schweiss-registret
- Ikke en fane. Knappen **Anskudt** på Jagtbart åbner den som sheet. Indstillinger skubber den ind.
- To veje, begge synlige. Ingen omskifter. Anskudt under jagt: link til schweiss.dk. Påkørt hjortevildt: ring 1812.
- Seks dagtimer er tekst med kilde. Ingen timer. Appen er ikke loven.
- Sekretariatet er hverdagskontakt, ikke en vagttelefon.
- Ingen telefonliste. Ingen scrape. Ingen gade eller mail på førere.
- Når en tilladt fil findes, får samme skærm de nærmeste numre. Ikke i denne udgave.

### Velkomst (første start)
- Mørkegrøn brand-baggrund, mærke, tre punkter (dato og sted, lokale tider, offline), fraskrivelse, knap “Forstået”.
- Forklarer positionsbrug før systemets dialog.

## Tilgængelighed

- VoiceOver: hver række er ét element med fuld tekst (“Råbuk. Jagtbar. 1. oktober til 31. januar. Lokal jagttid.”). Måneder udtales fuldt.
- Dynamic Type op til AX-størrelser. Rækker ombryder i stedet for at afkorte.
- Haptik (`sensoryFeedback(.selection)`) ved skift af dato/sted.
- Tal med ord bøjes i String Catalog (“1 art”, “2 arter”), ikke med `count == 1` i koden. VoiceOver siger aldrig “1 arter”.
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
- Biologi (2026-10-15): eget opslag på artsdetaljen, ikke i `jagttider.json`. Fugle fra DOF Danmarks Fugle. Pattedyr fra Arter.dk (Miljøstyrelsen), med Lex eller Dansk Pattedyratlas hvor Arter mangler yngeltekst. “Invasiv” kun for arter styrelsen lister til regulering hele året. Bestandsestimater udelades, fordi de forældes.
- App-ikonet (2026-10-15): feltet var næsten sort, så fasan og sigtekors forsvandt i lille størrelse. Feltet er nu skovgrøn `#2F6B47`, samme som AccentColor. Velkomst bliver på BrandDeep.
- Schweiss-registret (2026-10-15): infoside i v1, ikke en fane. Knappen Anskudt på Jagtbart, række på Om. Telefonlisten venter på tilladelse. Ingen scrape. Seks dagtimer er tekst.
- Alle arter (2026-10-16): grupperne starter sammenfoldet, med antal og pil. Søgning åbner træffene.
- Jagtbart (2026-10-16): de jagtbare grupper starter også sammenfoldet. Svar-kortet bliver stående. “Ikke jagtbar her” er uændret.
- Sammenfold grupper (2026-10-16): én kontakt i Indstillinger, standard til. Fra viser grupperne åbne, som før. Gemmes på telefonen. Ingen ny indsamling.
- Gruppetegninger (2026-10-16): enkel stregtegning ved hvert gruppenavn. Pynt, ikke status, derfor ikke grøn. “Ikke jagtbar her” har ingen tegning.
- Soltider (2026-10-16): under tiden står “[Sted], den [dato]”, samme valg som rækkerne ovenfor. Fx “Sjælland, den 16. oktober”.
- Engelsk UI (2026-10-16): appen findes på dansk og engelsk. Dansk er kilden og nøglen i `Localizable.xcstrings`, engelsk er oversættelsen. Arter, steder, noter og biologi kommer fra data og er danske i begge sprog. App Store-teksten er dansk. Datoer, klokkeslæt og systemets egne kontroller følger appens sprog, ikke telefonens område. Gruppetitlerne er appens egne ord (data har de danske), så en ny gruppe fra remote data falder tilbage til data-titlen. `SeasonCalendar` tager en locale, så datoformater kan testes på begge sprog.
- App-ikonet (2026-10-16): flad PNG erstattet af Icon Composer, `App/JagtFokus/AppIcon.icon`. To lag med Liquid Glass: sigtekors bagved, fasan foran. Feltet er stadig `#2F6B47`. Mørk tilstand er dybere skovgrøn `#1E4D34`, ikke næsten sort, så fasanen kan læses i lille størrelse. Farvet tilstand bruger en grå fasan og et hvidt sigtekors. Ringen er et PNG-lag, ikke SVG: den ældre renderer fyldte cirklen ud. Xcode laver flade ikoner til iOS 18–25 ud fra samme fil. BrandMark i Velkomst og Om bliver den flade tegning. Ingen glas på indhold.
- Design-gennemgang 1 (2026-10-17): “Dato” og “Sted” stod på dansk i den engelske app, fordi `QueryRow` tager en `String`. Nu `String(localized:)`. Bekræftelsens luk-knap har 44 × 44 pt trykflade. Flertal ligger i String Catalog, også for dansk. Amber-linjen på svar-kortet har timeglas. Solens orange og velkomstens grønne lys er tokens. “Tilføj til journal” har ingen pil.
- Design-gennemgang 2 (2026-10-17): grupperækken, dato/sted-rækkerne og tal-kortet fandtes i to kopier. Nu én komponent hver i `DesignSystem/`. Journalens positionstekst sagde “Viser sidst kendte sted”, mens rækken viste Danmark. Nu siger footeren, hvad rækken viser. Listerne på Jagtbart (åbne grupper, lukkede arter efter næste åbning, antal der lukker snart), søgning og hjortenoten er flyttet til Core med tests. Søgning ignorerer store bogstaver og accenter ens på alle skærme (“gas” finder “Grågås”). Solen står som sit eget kort.
- Design-gennemgang 3 (2026-10-17): svaret var gledet ned under overskrift, dato, sted og sol (ca. 60 % nede, under folden ved AX-L). Rækkefølgen er nu Dato og Sted → svar-kort → sol → grupper. Grupperne starter stadig sammenfoldet, men en gruppe med arter der lukker inden for en uge viser det i amber under navnet. Antallet til højre brydes aldrig.
- Design-gennemgang 4 (2026-10-17): fem faner blev til fire. Indstillinger havde kun to kontroller, så Om står nu under dem i samme fane, som i iOS’ egen Indstillinger. Om er sektioner, ikke en push, så kilde og fraskrivelse er ét tryk væk. Journal har systemets store titel som Alle arter og Indstillinger, så titlen ikke hopper mellem fanerne. Journal-ikonet er `book.closed`: et faneikon viser et sted, ikke en handling.
- Vejr og måne (2026-10-19): tryk på sol-kortet skubber Vejr-siden ind. Vejr fra MET Norway Locationforecast 2.0 med User-Agent, der identificerer appen, koordinater afrundet til to decimaler og et svar genbrugt i ti minutter (MET’s krav). Dagsopsummering, ikke time-rækker; fortid og horisont udenfor ca. ti dage skjuler vejret, sol og måne bliver. Månefasen er en synodisk beregning i Core, testet mod forholds- og måneformørkelser som ankre. Privatlivssiden, reklameteksten og beskrivelsen er opdateret i samme ændring. `QueryRow` fik `showsChevron: false`, for vejr-rækkerne er tal, ikke navigation. Cachen bor i hukommelsen; disk-cache kan komme senere, hvis MET-mængden nogensinde kræver det.
- SunRow (2026-10-19): basis-linjen (“Als, den 19. oktober”) stod i samme smalle kolonne som klokkeslættet og brød i to linjer, så kortet blev unødig højt. Den står nu på hele kortbredden under ikon og tider.
- Vejr-siden som flisegitter (2026-10-19): rækkerne blev skiftet ud med almanak-fliser i to kolonner — guldetiket, stor værdi, lille note (`Gold`-farven i Assets, samme par som Brass). MET’s compact-svar giver også luftfugtighed og tryk; tryktrenden ser fremad (næste tre timer), for prognosen ikke har tre timer tilbage. `Grid` frem for `LazyVGrid` inde i en List: det lazy gitter satte cellerne forkert. Fliserne er én VoiceOver-element hver. `QueryRow`’s `showsChevron`-parameter er fjernet igen — fliserne overtog opgaven.
- Sol-kortet med vejr og måne (2026-10-19): kortet viser kompakte linjer — temperaturer (“Maks 11,9° · Min 9,1°” med termometer), dagens vejr (“0 mm · [pil] op til 6,8 m/s”) når datoen ligger inden for MET’s horisont, og månen (“57 % oplyst”), som altid kan beregnes. Vindpilen er kompasset: den peger der, vinden blæser hen (fra øst → pil mod vest), som på vejrkort; VoiceOver hører “fra Ø”. `WeatherStore` er flyttet til `Store/` og ejes af `SeasonStore`, så kortet og Vejr-siden deler ét svar og højst ét kald pr. sted og dag (ti minutters genbrug). Vindretningen er retningen ved dagens kraftigste vind, i otte streger. Linjerne ombryder ved AX-størrelser.
- Design-gennemgang 5 (2026-10-19): sol-kortet og Sol og vejr. Kortet hed “Sol”, men viste vejr og måne, og siden hed “Vejr”, men viste sol og måne. Nu hedder begge “Sol og vejr”. Kortet havde to venstrekanter og ikoner af forskellig bredde, så teksten efter dem startede tre steder. Nu står alle ikoner i én kolonne under titlen, som i `QueryRow`. Stedet og datoen står i samme tekstkolonne og ikke længere i fuld bredde. Kun det længste stednavn (“Syddanmark vest for Lillebælt”) brydes, og det ville det også gøre i fuld bredde. Vinden siger “fra Ø” ved siden af pilen, for jægere taler om, hvor vinden står fra. Vejr-siden var et gitter af guldfliser, som ingen anden skærm bruger, med ulige høje fliser, ord der brød midt i (“VEJ-RET”) og ingen én-kolonne ved AX. Nu er den sektioner og `LabeledContent` som artsdetaljen, og stedet og datoen står over titlen. `Gold` er fjernet: farven var den samme som `Brass`, der betyder “Lokal jagttid”. Månen er grå, ikke indigo, så kun solen har farve. Tallene blandede “nu” og “hele dagen” uden at sige det. Nu siger sektionens overskrift det. Lufttryk skrives “1034 hPa” uden tusindtalspunktum. Fejl fundet i samme gennemgang og rettet med tests: fra ca. tredje dag ligger MET’s skridt på UTC-timer, så vejrsymbol og nedbør manglede (“–”). I dag talte nedbøren kun kl. 18–24, og dagens symbol var nattens. Kortets vindlinje kunne starte med et løst “·”.
- Jagtbart-rækkefølge (2026-10-19): Dato og Sted → Sol og vejr → svar-kort → grupper. Brugerens valg: dato, sted og dagens sol og vejr hører sammen, og svaret står lige over de grupper, det tæller. Det vender Design-gennemgang 3. Ved normal tekststørrelse står svaret stadig over fanebaren (ca. 78 % nede, før ca. 47 %). Ved AX-L ligger det under folden, og det er accepteret. At bytte rækkefølgen kun ved AX-størrelser blev valgt fra: det er enklere, at skærmen har samme rækkefølge for alle. Afstanden mellem kortene på Jagtbart er 24 pt (`Spacing.l`) i stedet for systemets ca. 35 pt, så kortene hænger sammen, og den næste gruppe kommer med over folden.
