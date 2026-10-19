import Foundation

/// Shared copy. One place, so onboarding and Om never drift apart.
/// The Danish text is the source key; English lives in `Localizable.xcstrings`.
enum Copy {
    static let headline = String(localized: "Jagtbart vildt efter tid og sted")

    static let disclaimer = String(localized: "JagtFokus viser jagttider ud fra bekendtgørelsen, valgt dato og sted. Listen kan være ufuldstændig eller forældet. Særlige regler (område, køn, kvote, jagtform) står i noten og i loven. Du er selv ansvarlig for at jage lovligt.")

    static let daylight = String(localized: "Jagt må som hovedregel kun ske mellem solopgang og solnedgang. Appen viser soltider, men tjekker ikke klokkeslæt.")

    static let notTheLaw = String(localized: "Appen er ikke loven. Tjek altid bekendtgørelsen og lokale regler.")

    static let biologyDisclaimer = String(localized: "Biologisk opslag. Ikke jagtloven. Kilden står under teksten.")

    static let deerNote = String(localized: "Kron- og dåvildt har store lokale forvaltningsplaner. Appen viser kun de generelle tider.")

    static let todayTab = String(localized: "Jagtbart")
    static let bagTab = String(localized: "Journal")
    static let bagHeading = String(localized: "Jagtjournal")
    static let bagYearRow = String(localized: "Nedlagt vildt")
    static let speciesListTitle = String(localized: "Artsliste")
    static let speciesListAdd = String(localized: "Tilføj")
    static let speciesListRemove = String(localized: "Fjern")
    static let speciesListEmpty = String(localized: "Ingen arter.")
    static let bagRecord = String(localized: "Tilføj til journal")
    static let bagTitle = String(localized: "Vildtudbytte")

    static let schweissTitle = String(localized: "Schweiss-registret")
    static let schweissToolbar = String(localized: "Anskudt")
    static let schweissClose = String(localized: "Luk")
    static let schweissHuntHeading = String(localized: "Anskudt under jagt")
    static let schweissHuntDuty = String(localized: "Er der tegn på anskydning af hjortevildt, og dyret ikke er fundet, skal du senest efter seks dagtimer tilkalde en hundefører fra Schweiss-registret.")
    static let schweissHuntFooter = String(localized: "Ifølge Naturstyrelsen. Appen er ikke loven. Siden kræver net.")
    static let schweissFindHandler = String(localized: "Find hundefører på schweiss.dk")
    static let schweissSource = String(localized: "Kilde hos Naturstyrelsen")
    static let schweissTrafficHeading = String(localized: "Påkørt hjortevildt")
    static let schweissCall1812 = String(localized: "Ring 1812")
    static let schweissTrafficFooter = String(localized: "Ring, hvis dyret ikke er dødt. Vagtcentralen kontakter en schweisshundefører, hvis det er løbet væk. Afmærk stedet tydeligt i rabatten, og oplys sted, hændelse og flugtretning.")
    static let schweissAboutHeading = String(localized: "Om registret")
    static let schweissAbout = String(localized: "Schweiss-registret er frivillige hundeførere med specialtrænede hunde. De er legitimeret af Naturstyrelsen og må eftersøge og aflive nødstedt vildt på anden mands grund. Du betaler kun kørsel.")
    static let schweissReferral = String(localized: "Den du ringer til, skal sikre at eftersøgningen bliver løst. Det er ikke sikkert, det er den person, der kommer.")
    static let schweissAboutLink = String(localized: "Om registret")
    static let schweissRules = String(localized: "Regler")
    static let schweissExpect = String(localized: "Hvad kan jeg forvente?")
    static let schweissSecretariatHeading = String(localized: "Schweiss-sekretariatet")
    static let schweissCallSecretariat = String(localized: "Ring 93 59 70 80")
    /// An address, the same in every language.
    static let schweissSecretariatMail = "schweiss@nst.dk"
    static let schweissSecretariatFooter = String(localized: "Hverdagskontakt. Ikke en vagttelefon.")

    /// `@AppStorage` key. On: Jagtbart and Alle arter start with groups collapsed.
    static let collapseGroupsKey = "sammenfoldGrupper"
    static let collapseGroupsTitle = String(localized: "Sammenfold grupper")
    static let collapseGroupsFooter = String(localized: "Jagtbart og Alle arter starter med grupperne lukket. Slå fra for at se alle arter med det samme.")

    /// “[Sted], den [dato]”: what the sun and weather clock times belong to.
    static func basis(place: String, day: String) -> String {
        String(localized: "\(place), den \(day)")
    }

    /// The sun card's title and the page it opens. One name, so the tap lands where it says.
    static let sunWeatherTitle = String(localized: "Sol og vejr")

    /// "Maks 11,9° · Min 9,1°", on the sun card and the weather page.
    static func maxMin(_ max: Double, _ min: Double, locale: Locale) -> String {
        String(localized: "Maks \(WeatherSymbols.decimal(max, locale))° · Min \(WeatherSymbols.decimal(min, locale))°")
    }

    /// "1 art", "14 arter". The plural forms live in the String Catalog.
    static func speciesCount(_ count: Int) -> String {
        String(localized: "\(count) arter")
    }

    /// "3 har sidste dag inden for en uge". Jagtbart's answer card and its group rows.
    static func closingSoon(_ count: Int) -> String {
        String(localized: "\(count) har sidste dag inden for en uge")
    }

    /// "1 stykke", "11 stykker". A count of animals taken.
    static func pieces(_ count: Int) -> String {
        String(localized: "\(count) stykker")
    }

    /// "Vist" / "Skjult", for the accessibility value on a row that folds out.
    static func showState(_ shown: Bool) -> String {
        shown ? String(localized: "Vist") : String(localized: "Skjult")
    }

    /// "Markeret" / "Ikke markeret", for a row with a checkmark.
    static func selectionState(_ selected: Bool) -> String {
        selected ? String(localized: "Markeret") : String(localized: "Ikke markeret")
    }

    /// Group headings come from the data in Danish. These are the app's own names for
    /// the same groups. An unknown id falls back to the data title.
    static func groupTitle(id: String, fromData title: String) -> String {
        switch id {
        case "klovbaerende": String(localized: "Klovbærende")
        case "rovdyr": String(localized: "Rovdyr")
        case "ovrige_pattedyr": String(localized: "Øvrige pattedyr")
        case "andefugle": String(localized: "Andefugle")
        case "gaes": String(localized: "Gæs")
        case "honsefugle": String(localized: "Hønsefugle")
        case "ovrige_fugle": String(localized: "Øvrige fugle")
        default: title
        }
    }
}
