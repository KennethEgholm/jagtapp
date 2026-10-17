#!/usr/bin/env python3
"""Fills App/JagtFokus/Localizable.xcstrings with the English translation.

The catalogue is generated from the keys Xcode extracts at build time, so a key
that is not in the source any more shows up as an error here instead of silently
staying Danish. Run after a build:

    python3 tools/fill_string_catalog.py [stringsdata-dir]

Write new copy in the code first, build, then add the English line below.
"""
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(REPO, "App/JagtFokus/Localizable.xcstrings")

# Danish source text -> English. The Danish text is the key, so it must match
# the literal in the code exactly.
ENGLISH = {
    "%@ %@": "%@ %@",
    "%@ noteret": "%@ recorded",
    "%@ · %@": "%@ · %@",
    "%@ – %@": "%@ – %@",
    "%@, %@": "%@, %@",
    "%@, %lld arter": "%@, %lld species",
    "%@, den %@": "%@, %@",
    "%lld": "%lld",
    "%lld arter": "%lld species",
    "%lld har sidste dag inden for en uge": "%lld have their last day within a week",
    "%lld lokale tider": "%lld local seasons",
    "%lld stykker": "%lld animals",
    "+1": "+1",
    "1 art": "1 species",
    "1 har sidste dag inden for en uge": "1 has its last day within a week",
    "1 lokal tid": "1 local season",
    "1 stykke": "1 animal",
    "Alle arter": "All species",
    "Andefugle": "Ducks",
    "Annuller": "Cancel",
    "Anskudt": "Wounded",
    "Anskudt og påkørt hjortevildt.": "Wounded and vehicle-hit deer.",
    "Anskudt under jagt": "Wounded during a hunt",
    "Ansvar": "Responsibility",
    "Antal %lld": "Count %lld",
    "Appen er ikke loven. Tjek altid bekendtgørelsen og lokale regler.": (
        "The app is not the law. Always check the regulations and local rules."
    ),
    "Art": "Species",
    "Arten findes ikke": "Species not found",
    "Artsfotos fra Wikimedia Commons": "Species photos from Wikimedia Commons",
    "Artsliste": "Species list",
    "Biologi": "Biology",
    "Biologisk opslag. Ikke jagtloven. Kilden står under teksten.": (
        "Biology reference. Not the hunting regulations. The source is shown below the text."
    ),
    "Brug GPS": "Use GPS",
    "Bruger indbygget data": "Using built-in data",
    "Data": "Data",
    "Dataversion": "Data version",
    "Dato": "Date",
    "Dato og sted": "Date and place",
    "Den du ringer til, skal sikre at eftersøgningen bliver løst. Det er ikke sikkert, det er den person, der kommer.": (
        "Whoever you call must make sure the search is carried out. Someone else may be the one who turns up."
    ),
    "Denne app": "This app",
    "Derefter spørger JagtFokus om din position.": "JagtFokus then asks for your location.",
    "Din position": "Your location",
    "Din position bliver på telefonen": "Your location stays on your phone",
    "Er der tegn på anskydning af hjortevildt, og dyret ikke er fundet, skal du senest efter seks dagtimer tilkalde en hundefører fra Schweiss-registret.": (
        "If there are signs that deer has been wounded and the animal has not been found, "
        "you must call a handler from the Schweiss register no later than six daylight hours afterwards."
    ),
    "Find hundefører på schweiss.dk": "Find a handler at schweiss.dk",
    "Finder position…": "Finding your location…",
    "Fjern": "Remove",
    "Forstået": "Understood",
    "Fortryd": "Undo",
    "Foto af %@": "Photo of %@",
    "Foto: %@ · %@ · Wikimedia Commons": "Photo: %@ · %@ · Wikimedia Commons",
    "Fotokredit: %@, %@": "Photo credit: %@, %@",
    "Fotos": "Photos",
    "Færdig": "Done",
    "Generel jagttid": "General season",
    "Generelle jagttider": "General seasons",
    "Generelle jagttider i Danmark. Lokale tider kan afvige. Se dem under Jagtbart.": (
        "General seasons in Denmark. Local seasons may differ. See them under Huntable."
    ),
    "Gælder for": "Applies to",
    "Gæs": "Geese",
    "Hele landet": "All of Denmark",
    "Hvad kan jeg forvente?": "What can I expect?",
    "Hverdagskontakt. Ikke en vagttelefon.": "Weekday contact. Not an emergency line.",
    "Hønsefugle": "Game birds",
    "I dag": "Today",
    "I morgen": "Tomorrow",
    "Ifølge Naturstyrelsen. Appen er ikke loven. Siden kræver net.": (
        "From the Danish Nature Agency. The app is not the law. The page needs a connection."
    ),
    "Ikke jagtbar": "Not huntable",
    "Ikke jagtbar her": "Not huntable here",
    "Ikke jagtbar, åbner %@": "Not huntable, opens %@",
    "Ikke markeret": "Not selected",
    "Indbygget data er nyere": "Built-in data is newer",
    "Indstillinger": "Settings",
    "Ingen arter": "No species",
    "Ingen arter.": "No species.",
    "Ingen generel jagttid.": "No general season.",
    "Ingen jagttid": "No season",
    "Ingen jagttid her i jagtåret.": "No season here in the hunting year.",
    "Ingen jagttid her.": "No season here.",
    "Ingen konto": "No account",
    "Ingen konto. Ingen tracking. Din position bliver på telefonen.": (
        "No account. No tracking. Your location stays on your phone."
    ),
    "Ingen poster": "No entries",
    "Ingen poster.": "No entries.",
    "Ingen tracking": "No tracking",
    "Intet jagtbart i dag.": "Nothing huntable today.",
    "Intet jagtbart.": "Nothing huntable.",
    "Intet sted": "No place",
    "Jagt må som hovedregel kun ske mellem solopgang og solnedgang. Appen viser soltider, men tjekker ikke klokkeslæt.": (
        "As a rule you may hunt only between sunrise and sunset. "
        "The app shows sun times, but does not check the clock."
    ),
    "JagtFokus": "JagtFokus",
    "JagtFokus viser jagttider ud fra bekendtgørelsen, valgt dato og sted. Listen kan være ufuldstændig eller forældet. Særlige regler (område, køn, kvote, jagtform) står i noten og i loven. Du er selv ansvarlig for at jage lovligt.": (
        "JagtFokus shows open seasons from the hunting regulations, the date and the place you pick. "
        "The list may be incomplete or out of date. "
        "Special rules (area, sex, quota, hunting method) are in the note and in the law. "
        "You are responsible for hunting legally."
    ),
    "Jagtbar": "Huntable",
    "Jagtbar, %@": "Huntable, %@",
    "Jagtbar, sidste dag": "Huntable, last day",
    "Jagtbart": "Huntable",
    "Jagtbart i dag": "Huntable today",
    "Jagtbart og Alle arter starter med grupperne lukket. Slå fra for at se alle arter med det samme.": (
        "Huntable and All species start with the groups closed. Turn off to see every species at once."
    ),
    "Jagtbart vildt efter tid og sted": "Huntable game by date and place",
    "Jagtjournal": "Hunting journal",
    "Jagttid i %@": "Season in %@",
    "Jagttider efter dato og sted": "Seasons by date and place",
    "Jagtåret %@": "Hunting year %@",
    "Jagtåret vist fra 1. april til 31. marts.": "The hunting year is shown from 1 April to 31 March.",
    "Journal": "Journal",
    "Kilde": "Source",
    "Kilde hos Naturstyrelsen": "Source at the Danish Nature Agency",
    "Klovbærende": "Cloven-hoofed game",
    "Kron- og dåvildt har store lokale forvaltningsplaner. Appen viser kun de generelle tider.": (
        "Red deer and fallow deer have large local management plans. The app shows the general seasons only."
    ),
    "Kunne ikke finde din position. Listen viser hele Danmark. Vælg sted.": (
        "Could not find your location. The list shows all of Denmark. Pick a place."
    ),
    "Kunne ikke finde position": "Could not find your location",
    "Kunne ikke opdatere din position. Viser sidst kendte sted.": (
        "Could not update your location. Showing the last known place."
    ),
    "Kunne ikke opdatere din position. Viser sidst kendte sted: %@.": (
        "Could not update your location. Showing the last known place: %@."
    ),
    "Latinsk navn": "Latin name",
    "Licenser: CC0, public domain, CC BY og CC BY-SA. Fotograf og licens står under hvert billede. Billederne er beskåret og skaleret.": (
        "Licences: CC0, public domain, CC BY and CC BY-SA. "
        "The photographer and the licence are shown under each image. Images are cropped and scaled."
    ),
    "Listen følger dagens dato og din position. Du kan vælge en anden dag og et andet sted.": (
        "The list follows today's date and your location. You can pick another day and another place."
    ),
    "Lister": "Lists",
    "Lokal jagttid": "Local season",
    "Lokale jagttider": "Local seasons",
    "Luk": "Close",
    "Luk bekræftelse": "Close confirmation",
    "Lys": "Light",
    "Lørdag": "Saturday",
    "Mangler data": "Missing data",
    "Markeret": "Selected",
    "Mest specifikke sted gælder: ø før område før region før Danmark.": (
        "The most specific place wins: island before area before region before Denmark."
    ),
    "Min position": "My location",
    "Mørk": "Dark",
    "Nedlagt vildt": "Game taken",
    "Note": "Note",
    "Notér %@": "Record %@",
    "Næste: %@, %@": "Next: %@, %@",
    "Offline. Bruger gemt data.": "Offline. Using saved data.",
    "Om": "About",
    "Om registret": "About the register",
    "Områder": "Areas",
    "Opdateret": "Updated",
    "Opdateret fra net": "Updated from the web",
    "Position er slået fra. Listen viser hele Danmark. Vælg sted, eller slå position til.": (
        "Location is off. The list shows all of Denmark. Pick a place, or turn location on."
    ),
    "Posten er slettet.": "The entry has been deleted.",
    "Privat og offline": "Private and offline",
    "Privatliv": "Privacy",
    "Påkørt hjortevildt": "Deer hit by a vehicle",
    "Regioner": "Regions",
    "Regler": "Rules",
    "Ret": "Edit",
    "Ring 1812": "Call 1812",
    "Ring 1812, Dyrenes Beskyttelses Vagtcentral": (
        "Call 1812, the Danish Animal Welfare Society emergency line"
    ),
    "Ring 93 59 70 80": "Call 93 59 70 80",
    "Ring 93 59 70 80, Schweiss-sekretariatet": "Call 93 59 70 80, the Schweiss secretariat",
    "Ring, hvis dyret ikke er dødt. Vagtcentralen kontakter en schweisshundefører, hvis det er løbet væk. Afmærk stedet tydeligt i rabatten, og oplys sted, hændelse og flugtretning.": (
        "Call if the animal is not dead. The emergency line contacts a Schweiss handler if it has run off. "
        "Mark the spot clearly in the verge, and say where, what happened and which way it ran."
    ),
    "Rovdyr": "Predators",
    "Sammenfold grupper": "Collapse groups",
    "Schweiss-registret": "The Schweiss register",
    "Schweiss-registret er frivillige hundeførere med specialtrænede hunde. De er legitimeret af Naturstyrelsen og må eftersøge og aflive nødstedt vildt på anden mands grund. Du betaler kun kørsel.": (
        "The Schweiss register is volunteer handlers with specially trained dogs. "
        "They are authorised by the Danish Nature Agency and may track and put down wounded game "
        "on another person's land. You pay for travel only."
    ),
    "Schweiss-sekretariatet": "The Schweiss secretariat",
    "Se hvad der er jagtbart i dag, der hvor du er.": "See what you can hunt today, where you are.",
    "Se året": "See the year",
    "Senest nedlagt": "Recently taken",
    "Sidste dag": "Last day",
    "Sidste dag %@": "Last day %@",
    "Skjult": "Hidden",
    "Skriver til Schweiss-sekretariatet": "Emails the Schweiss secretariat",
    "Slet": "Delete",
    "Slået fra i Indstillinger": "Turned off in Settings",
    "Sol": "Sun",
    "Solopgang %@, solnedgang %@. %@": "Sunrise %@, sunset %@. %@",
    "Sorteret efter næste åbning.": "Sorted by next opening.",
    "Sted": "Place",
    "Swipe fjerner arten her. Journalen ændres ikke.": (
        "Swiping removes the species here. The journal is not changed."
    ),
    "System": "System",
    "System følger telefonens indstilling for lys og mørk.": (
        "System follows the phone's light and dark setting."
    ),
    "Sætter arten på artslisten eller tager den af": (
        "Puts the species on the species list, or takes it off"
    ),
    "Søg": "Search",
    "Søg art": "Search species",
    "Søg i alle arter": "Search all species",
    "Søg ø, område eller region": "Search island, area or region",
    "Søndag": "Sunday",
    "Tilføj": "Add",
    "Tilføj til journal": "Add to journal",
    "Udseende": "Appearance",
    "Ukendt": "Unknown",
    "Valgt": "Selected",
    "Velkommen til JagtFokus": "Welcome to JagtFokus",
    "Version": "Version",
    "Vigtigt": "Important",
    "Vildtudbytte": "Bag",
    "Virker offline": "Works offline",
    "Vis arter du har nedlagt": "Show the species you have taken",
    "Vis årets poster": "Show this year's entries",
    "Viser arter uden jagttid lige nu, sorteret efter næste åbning": (
        "Shows species with no open season right now, sorted by next opening"
    ),
    "Viser arterne i gruppen": "Shows the species in this group",
    "Vist": "Shown",
    "Vælg": "Choose",
    "Vælg dag": "Choose day",
    "Vælg en anden dag": "Pick another day",
    "Vælg en anden dag eller et andet sted.": "Pick another day, or another place.",
    "Vælg et andet sted": "Pick another place",
    "Vælg sted": "Choose place",
    "art er jagtbar": "species is huntable",
    "arter er jagtbare": "species are huntable",
    "i dag": "today",
    "i dag, %@": "today, %@",
    "i morgen": "tomorrow",
    "om %lld dage": "in %lld days",
    "sidste dag %@": "last day %@",
    "stykke": "animal",
    "stykker": "animals",
    "til": "to",
    "til %@": "until %@",
    "ukendt": "unknown",
    "Åbn Indstillinger-appen": "Open the Settings app",
    "Åbn Schweiss-registret": "Open the Schweiss register",
    "Åbn Wikimedia Commons": "Open Wikimedia Commons",
    "Åbn bekendtgørelsen": "Open the regulation",
    "Åbner": "Opens",
    "Åbner Naturstyrelsen": "Opens the Danish Nature Agency",
    "Åbner billedet på Wikimedia Commons": "Opens the image at Wikimedia Commons",
    "Åbner schweiss.dk": "Opens schweiss.dk",
    "Øer": "Islands",
    "Øer og områder med egne tider slår de generelle.": (
        "Islands and areas with their own seasons beat the general ones."
    ),
    "Øvrige fugle": "Other birds",
    "Øvrige pattedyr": "Other mammals",
    "åbner %@": "opens %@",
}

# Keys whose meaning is not obvious from the text alone.
COMMENTS = {
    "%@ %@": "Weekday and date on a day button, e.g. “Saturday 24 Oct”.",
    "%@ · %@": "A date and a place, separated by a middle dot.",
    "%@, %@": "A place, then a date, e.g. “Zealand, 16 October”.",
    "%@, den %@": "The place and date the sun times belong to, e.g. “Zealand, 16 October”.",
    "%@, %lld arter": "A group heading and how many species it holds.",
    "%lld": "A count on its own, shown in a large font.",
    "til": "Between the first and the last day of a season, read aloud by VoiceOver.",
    "1 stykke": "How many animals were taken. The app never says which sex or age.",
    "stykke": "Follows a count of animals taken.",
    "Jagtbart": "The first tab, and the word for a species with an open season.",
    "Note": "A short note from the hunting regulations, shown as plain text.",
    "Data": "A section about where the season data comes from.",
}


def extracted_keys(directory):
    """Every key Xcode found in the Swift sources, from the .stringsdata files."""
    import glob

    keys = set()
    for path in glob.glob(os.path.join(directory, "*.stringsdata")):
        with open(path) as handle:
            document = json.load(handle)
        for items in document.get("tables", {}).values():
            for item in items:
                keys.add(item["key"])
    return keys


def main():
    directory = sys.argv[1] if len(sys.argv) > 1 else None
    if directory and os.path.isdir(directory):
        found = extracted_keys(directory)
        missing = sorted(found - set(ENGLISH))
        extra = sorted(set(ENGLISH) - found)
        if missing:
            print("In the code but not translated:")
            for key in missing:
                print("   ", repr(key))
        if extra:
            print("Translated but no longer in the code:")
            for key in extra:
                print("   ", repr(key))
        if missing or extra:
            print()
            print("Fix the table above, then run this script again.")
            return 1

    strings = {}
    for key in sorted(ENGLISH):
        entry = {
            "localizations": {
                "en": {"stringUnit": {"state": "translated", "value": ENGLISH[key]}}
            }
        }
        if key in COMMENTS:
            entry["comment"] = COMMENTS[key]
        strings[key] = entry

    document = {"sourceLanguage": "da", "strings": strings, "version": "1.0"}
    with open(CATALOG, "w") as handle:
        json.dump(document, handle, ensure_ascii=False, indent=2, separators=(",", " : "))
        handle.write("\n")
    print(f"wrote {len(strings)} strings to {os.path.relpath(CATALOG, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
