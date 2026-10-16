import Foundation

/// Shared Danish copy. One place, so onboarding and Om never drift apart.
enum Copy {
    static let headline = "Jagtbart vildt efter tid og sted"

    static let disclaimer = "JagtFokus viser jagttider ud fra bekendtgørelsen, valgt dato og sted. Listen kan være ufuldstændig eller forældet. Særlige regler (område, køn, kvote, jagtform) står i noten og i loven. Du er selv ansvarlig for at jage lovligt."

    static let daylight = "Jagt må som hovedregel kun ske mellem solopgang og solnedgang. Appen viser soltider, men tjekker ikke klokkeslæt."

    static let notTheLaw = "Appen er ikke loven. Tjek altid bekendtgørelsen og lokale regler."

    static let biologyDisclaimer = "Biologisk opslag. Ikke jagtloven. Kilden står under teksten."

    static let deerNote = "Kron- og dåvildt har store lokale forvaltningsplaner. Appen viser kun de generelle tider."

    static let todayTab = "Jagtbart"
    static let bagTab = "Journal"
    static let bagHeading = "Jagtjournal"
    static let bagYearRow = "Nedlagt vildt"
    static let bagRecord = "Tilføj til journal"
    static let bagTitle = "Vildtudbytte"

    static let schweissTitle = "Schweiss-registret"
    static let schweissToolbar = "Anskudt"
    static let schweissClose = "Luk"
    static let schweissHuntHeading = "Anskudt under jagt"
    static let schweissHuntDuty = "Er der tegn på anskydning af hjortevildt, og dyret ikke er fundet, skal du senest efter seks dagtimer tilkalde en hundefører fra Schweiss-registret."
    static let schweissHuntFooter = "Ifølge Naturstyrelsen. Appen er ikke loven. Siden kræver net."
    static let schweissFindHandler = "Find hundefører på schweiss.dk"
    static let schweissSource = "Kilde hos Naturstyrelsen"
    static let schweissTrafficHeading = "Påkørt hjortevildt"
    static let schweissCall1812 = "Ring 1812"
    static let schweissTrafficFooter = "Ring, hvis dyret ikke er dødt. Vagtcentralen kontakter en schweisshundefører, hvis det er løbet væk. Afmærk stedet tydeligt i rabatten, og oplys sted, hændelse og flugtretning."
    static let schweissAboutHeading = "Om registret"
    static let schweissAbout = "Schweiss-registret er frivillige hundeførere med specialtrænede hunde. De er legitimeret af Naturstyrelsen og må eftersøge og aflive nødstedt vildt på anden mands grund. Du betaler kun kørsel."
    static let schweissReferral = "Den du ringer til, skal sikre at eftersøgningen bliver løst. Det er ikke sikkert, det er den person, der kommer."
    static let schweissAboutLink = "Om registret"
    static let schweissRules = "Regler"
    static let schweissExpect = "Hvad kan jeg forvente?"
    static let schweissSecretariatHeading = "Schweiss-sekretariatet"
    static let schweissCallSecretariat = "Ring 93 59 70 80"
    static let schweissSecretariatMail = "schweiss@nst.dk"
    static let schweissSecretariatFooter = "Hverdagskontakt. Ikke en vagttelefon."

    /// `@AppStorage` key. On: Jagtbart and Alle arter start with groups collapsed.
    static let collapseGroupsKey = "sammenfoldGrupper"
    static let collapseGroupsTitle = "Sammenfold grupper"
    static let collapseGroupsFooter = "Jagtbart og Alle arter starter med grupperne lukket. Slå fra for at se alle arter med det samme."
}
