# App Store — tekster, svar og tjekliste

Klar til at kopiere ind i App Store Connect. Tegngrænser er tjekket.

## Grundoplysninger

| Felt | Værdi |
|---|---|
| Navn (30) | JagtFokus – Jagttider |
| Undertitel (30) | Hvad er jagtbart i dag, her? |
| Bundle ID | `dk.jagtfokus.app` |
| SKU | `jagtfokus-ios` |
| Primært sprog | Dansk |
| Kategori | Opslagsværker (Reference). Sekundær: Sport |
| Pris | Gratis |
| Tilgængelighed | Kun Danmark |
| Support-URL | https://kennethegholm.github.io/jagtapp/ |
| Privatlivs-URL | https://kennethegholm.github.io/jagtapp/privatliv.html |
| Marketing-URL | (tom) |
| Kontakt (support- og privatlivsside) | jagtfokus@gmail.com |
| Copyright | 2026 <dit navn, som det står på udviklerkontoen> |

## Reklametekst (170)

Se på få sekunder, hvad der er jagtbart i dag, der hvor du er. Lokale tider, soltider, journal og biologi – også uden net.

## Nøgleord (100)

```
jagt,jagttid,jæger,vildt,råbuk,hjort,ræv,and,gås,fasan,hare,solnedgang,solopgang,lokale,journal
```

Navn og undertitel tæller med i søgningen, så ord derfra er ikke gentaget.

## Beskrivelse

```
JagtFokus viser, hvad der er jagtbart i dag, der hvor du er.

Åbn appen, og du ser med det samme, hvor mange arter der har jagttid på dagen og stedet – grupperet som klovbærende, rovdyr, andefugle, gæs og så videre. Arter med sidste dag inden for en uge er markeret, og nederst kan du se, hvad der åbner næste gang.

LOKALE JAGTTIDER
Mange øer og områder har egne jagttider. JagtFokus finder dit sted ud fra din position og bruger den lokale tid, når den gælder – ø før område før region før Danmark. Du kan også selv vælge sted og dag, fx når du planlægger weekendens jagt.

SOLOPGANG OG SOLNEDGANG
Se soltider for den valgte dag og dit sted, beregnet direkte på telefonen.

ALLE ARTER
Slå de generelle jagttider op for alle arter med en tidslinje over jagtåret. Hver art har en side med jagttid, biologisk opslag, noter, foto og link til bekendtgørelsen.

BIOLOGI
Opslaget fortæller det mest almindelige om arten: om den yngler i Danmark, hvor den trækker hen, og hvor mange unger den får. Fugle er fra Dansk Ornitologisk Forening. Pattedyr er fra Miljøstyrelsen. Det er ikke jagtloven.

JAGTJOURNAL
Notér nedlagt vildt på få sekunder. Journalen gemmes kun på telefonen. Appen indberetter ikke til myndighederne.

SCHWEISS-REGISTRET
Anskudt hjortevildt: appen åbner schweiss.dk, så du kan finde en hundefører. Påkørt hjortevildt: ring 1812. Appen har ikke selv telefonlisten.

PRIVAT OG OFFLINE
Ingen konto. Ingen tracking. Ingen reklamer. Din position bliver på telefonen, og appen virker uden net.

VIGTIGT
JagtFokus viser jagttider ud fra bekendtgørelsen om jagttid (BEK nr. 470/2024). Listen kan være ufuldstændig eller forældet. Særlige regler (område, køn, kvote, jagtform) står i noten og i loven. Appen er ikke loven – du er selv ansvarlig for at jage lovligt.

Fotos: Wikimedia Commons (CC0, public domain, CC BY, CC BY-SA). Fotograf og licens står ved hvert billede.
```

## Nyt i denne version

```
Første version. Jagttider efter dato og sted, soltider, jagtjournal, biologisk opslag og Schweiss-registret.
```

## Screenshots (6,9", 1320 × 2868)

I `spec/appstore/screenshots/`, i denne rækkefølge. Taget 2026-10-15 på iPhone 18 Pro Max, 1320 × 2868, statuslinje 09.41. Biologien ligger under folden på artsdetaljen, så den er ikke med på billedet.

1. `1-jagtbar.png` — Jagtbart i dag (15. okt), Midtjylland, soltider, 44 arter
2. `2-raabuk-als.png` — Råbuk på Als: lokal jagttid, foto, tidslinje, journal
3. `3-alle-arter.png` — Alle arter med tidslinjer
4. `4-jagtbar-moerk.png` — Mørkt tema, Endelave 15. nov
5. `5-velkomst.png` — Velkomst og ansvar

Lav dem igen efter ændringer (iPhone 18 Pro Max-simulatoren, statuslinje 09.41):

```sh
xcrun simctl status_bar booted override --time "09:41" --dataNetwork wifi --wifiMode active \
  --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100
xcrun simctl launch --terminate-running-process booted dk.jagtfokus.app \
  -harGodkendtFraskrivelse YES -date 2026-10-11 -place als -species raabuk
xcrun simctl io booted screenshot 2-raabuk-als.png
```

## App-privatliv (spørgeskema)

Svar: **Data indsamles ikke** (Data Not Collected).

Begrundelse:
- Ingen konto, analyse, reklamer eller tredjeparts-SDK'er.
- Position bruges på telefonen. Stednavn hentes via Apples geokodning (CLGeocoder); udvikleren modtager aldrig positionen.
- Datafilen hentes fra GitHub uden oplysninger om brugeren.
- Jagtjournalen og artslisten gemmes kun på telefonen. Udvikleren modtager dem ikke. Ingen iCloud-synk i denne udgave.
- `PrivacyInfo.xcprivacy`: ingen tracking, ingen indsamlede datatyper, UserDefaults med årsag `CA92.1`.

Tjek selv svaret, før du indsender: det er din erklæring over for Apple.

## Aldersgrænse (spørgeskema)

Alle spørgsmål: **Ingen**. Ingen vold, våben, brugerindhold, chat eller køb. Forventet: 4+.

## Eksport (kryptering)

`ITSAppUsesNonExemptEncryption = NO` står i `Info.plist`. App Store Connect spørger ikke.

## Noter til App Review (engelsk)

```
JagtFokus shows which game species may legally be hunted in Denmark on a given date and place, based on the Danish hunting-season order (BEK 470/2024, public law, linked in the app).

No login is required.

Location: used only to pick the right local hunting times (islands and areas have their own) and to show sunrise/sunset. The app works fully without location.

Outside Denmark the app falls back to the general Danish times ("Danmark"). To see local times: Jagtbart tab > Sted > choose e.g. "Als" or "Endelave". To change the day: Jagtbart tab > Dato.

Journal tab: a local hunting bag only. Nothing is submitted to the authorities, and nothing is synced to iCloud. No account.

Each species page has a short biology note (whether it breeds in Denmark, where it migrates, litter or clutch size). Birds are from the Danish Ornithological Society. Mammals are from the Danish Environmental Protection Agency via arter.dk. Display only. Not hunting law.

The app shows a disclaimer on first launch: it is not the law, and hunters must check the official rules.

Schweiss register: on the Jagtbart tab, tap Anskudt (or Indstillinger > Schweiss-registret). Wounded game during a hunt opens schweiss.dk. A traffic collision calls 1812, the Danish animal emergency line. The app does not include the handlers' phone numbers.

Species photos are from Wikimedia Commons under CC0 / public domain / CC BY / CC BY-SA, credited under each photo.
```

## Tjekliste før indsendelse

- [ ] Jagttider tjekket mod Retsinformation (er der en nyere bekendtgørelse end BEK 470/2024?)
- [ ] `data/jagttider.json` pushet til GitHub, og `version` er mindst den indbyggede
- [ ] GitHub Pages slået til (Settings > Pages > main, `/docs`), siderne svarer
- [ ] Team sat i Xcode, build-nummer talt op (`tools/bump_build.sh`)
- [ ] TestFlight på egen iPhone: position udendørs, et par steder, lyst og mørkt tema, stor tekst
- [ ] EU-erhvervsdrivende-status angivet i App Store Connect
- [ ] Privatliv og aldersgrænse besvaret
- [x] Screenshots taget om på iPhone 18 Pro Max (Journal, Jagtbart)
- [ ] Screenshots, tekster og review-noter indsat
- [ ] Udgivelse: manuel (så du selv vælger dagen)
- [ ] Udviklerkonto godkendt, før GitHub Actions må uploade

## GitHub Actions (forberedt, ikke aktiv)

Workflowet `.github/workflows/appstore.yml` kan senere uploade et build til App Store Connect. Det kører ikke af sig selv. Input **upload** er fra. Udviklerkontoen er ikke godkendt, så der må ikke uploades endnu.

Et upload lægger kun buildet op. Det indsender ikke til review og udgiver ikke. Udgivelse bliver i App Store Connect, manuelt.

Versionsnummeret i appen er `MARKETING_VERSION` fra Xcode-projektet. Samme tal arkiveres. Det står nederst i **Indstillinger**, i sektionen **Denne app**, som “Version 1.0 (1)”. Tæl op med `tools/bump_build.sh` og commit, før workflowet køres. Workflowet ændrer ikke nummeret.

Når kontoen er godkendt:

1. Opret en App Store Connect API-nøgle (Admin eller App Manager). Hent `.p8`-filen én gang.
2. Læg tre secrets på repoet. Ikke i git.

| Secret | Indhold |
|---|---|
| `APP_STORE_CONNECT_KEY_ID` | Nøglens id |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer id |
| `APP_STORE_CONNECT_API_KEY_P8` | Hele `.p8`-filen, inklusive `BEGIN` og `END` |

3. Kør **App Store** under Actions, med upload slået til. Runneren er `xcode-27`.
4. Tjek buildet i App Store Connect. Udgiv selv, når dagen er valgt.

Indtil da: Product → Archive i Xcode.
