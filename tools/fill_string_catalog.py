#!/usr/bin/env python3
"""Fills App/JagtFokus/Localizable.xcstrings with the English translation.

The catalogue is generated from the keys Xcode extracts at build time, so a key
that is not in the source any more shows up as an error here instead of silently
staying Danish. Run after a build:

    python3 tools/fill_string_catalog.py [stringsdata-dir]

Write new copy in the code first, build, then add the English line below.
A count that changes the words ("1 art", "2 arter") goes in PLURALS instead.
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
    "%@ m/s fra %@": "%@ m/s from %@",
    "%@ noteret": "%@ recorded",
    "%@ oplyst": "%@ lit",
    "%@, %@ oplyst.": "%@, %@ lit.",
    "%@ · %@": "%@ · %@",
    "%@ – %@": "%@ – %@",
    "%@, %@": "%@, %@",
    "%@, den %@": "%@, %@",
    "%lld": "%lld",
    "+1": "+1",
    "Alle arter": "All species",
    "Andefugle": "Ducks",
    "Annuller": "Cancel",
    "Anskudt": "Wounded",
    "Anskudt og påkørt hjortevildt.": "Wounded and vehicle-hit deer.",
    "Aftagende måne": "Waning moon",
    "Aftagende månesegl": "Waning crescent",
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
    "Hele dagen": "All day",
    "Kraftigste vind": "Strongest wind",
    "Lufttryk": "Pressure",
    "Midt på dagen": "Midday",
    "Nu": "Now",
    "Op til %@ m/s": "Up to %@ m/s",
    "Op til %@ m/s fra %@": "Up to %@ m/s from %@",
    "Resten af dagen": "Rest of the day",
    "Biologisk opslag. Ikke jagtloven. Kilden står under teksten.": (
        "Biology reference. Not the hunting regulations. The source is shown below the text."
    ),
    "Brug GPS": "Use GPS",
    "Bruger indbygget data": "Using built-in data",
    "Data": "Data",
    "Dataversion": "Data version",
    "Dato": "Date",
    "Delvis skyet": "Partly cloudy",
    "Dato og sted": "Date and place",
    "Den du ringer til, skal sikre at eftersøgningen bliver løst. Det er ikke sikkert, det er den person, der kommer.": (
        "Whoever you call must make sure the search is carried out. Someone else may be the one who turns up."
    ),
    "Denne app": "This app",
    "Derefter spørger JagtFokus om din position.": "JagtFokus then asks for your location.",
    "Din position": "Your location",
    "Er der tegn på anskydning af hjortevildt, og dyret ikke er fundet, skal du senest efter seks dagtimer tilkalde en hundefører fra Schweiss-registret.": (
        "If there are signs that deer has been wounded and the animal has not been found, "
        "you must call a handler from the Schweiss register no later than six daylight hours afterwards."
    ),
    "Fejl i ny data. Bruger gemt data.": "Error in new data. Using saved data.",
    "Find hundefører på schweiss.dk": "Find a handler at schweiss.dk",
    "Finder position…": "Finding your location…",
    "Fjern": "Remove",
    "Forstået": "Understood",
    "Fortryd": "Undo",
    "Foto af %@": "Photo of %@",
    "Foto: %@ · %@ · Wikimedia Commons": "Photo: %@ · %@ · Wikimedia Commons",
    "Fotokredit: %@, %@": "Photo credit: %@, %@",
    "Fotos": "Photos",
    "Fuldmåne": "Full moon",
    "Færdig": "Done",
    "Første kvarter": "First quarter",
    "Generel jagttid": "General season",
    "Generelle jagttider": "General seasons",
    "Generelle jagttider i Danmark. Lokale tider kan afvige. Se dem under Jagtbart.": (
        "General seasons in Denmark. Local seasons may differ. See them under Huntable."
    ),
    "Gælder for": "Applies to",
    "Gæs": "Geese",
    "Hele landet": "All of Denmark",
    "Henter vejret…": "Fetching the weather…",
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
    "Ingen konto. Ingen tracking. Din position bruges kun til sted, sol og vejr.": (
        "No account. No tracking. Your location is used only for place, sun and weather."
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
    "Jagttiderne virker offline": "Seasons work offline",
    "Jagtåret %@": "Hunting year %@",
    "Jagtåret vist fra 1. april til 31. marts.": "The hunting year is shown from 1 April to 31 March.",
    "Journal": "Journal",
    "Kilde": "Source",
    "Kilde hos Naturstyrelsen": "Source at the Danish Nature Agency",
    "Kilde: Meteorologisk institutt (MET). Vejr og måne er kun visning.": (
        "Source: the Norwegian Meteorological Institute (MET). Weather and moon are display only."
    ),
    "Klart": "Clear sky",
    "Klovbærende": "Cloven-hoofed game",
    "Kort": "Map",
    "Baggrundskort": "Basemap",
    "Brug præcis position": "Use precise location",
    "Centrér på din position": "Centre on your location",
    "Gemt område: %@, hentet %@": "Saved area: %@, downloaded %@",
    "Gem område": "Save area",
    "Gemte områder": "Saved areas",
    "5 × 5 km om midten": "5 × 5 km around the centre",
    "Gem": "Save",
    "Område": "Area",
    "Navn": "Name",
    "Gemmer %@ …": "Saving %@ …",
    "%@ er gemt": "%@ saved",
    "Området kunne ikke gemmes. Prøv igen med net.": "The area could not be saved. Try again online.",
    "Hentet %@ · %@": "Downloaded %@ · %@",
    "Ingen gemte områder.": "No saved areas.",
    "Henter skel …": "Loading boundaries …",
    "Kortet mangler adgang til Datafordeler.": "The map has no access to Datafordeler.",
    "Licens": "Licence",
    "Matrikelskel": "Property boundaries",
    "Om kortet": "About the map",
    "Præcis position er slået fra": "Precise location is off",
    "Skel kunne ikke hentes.": "Boundaries could not be loaded.",
    "Skel på kortet er fra matrikelkortet og er vejledende. De afviger typisk 0,1–4 m og nogle steder mere. Kun en praktiserende landinspektør kan fastlægge et skel.": (
        "Boundaries on the map come from the cadastral map and are indicative. "
        "They typically differ by 0.1–4 m, in places more. Only a practising land surveyor can determine a boundary."
    ),
    "Uden net. Viser gemte områder.": "Offline. Showing saved areas.",
    "Zoom ind for at se skel": "Zoom in to see boundaries",
    "Kraftig regn": "Heavy rain",
    "Kraftig regn og torden": "Heavy rain and thunder",
    "Kraftig slud": "Heavy sleet",
    "Kraftig slud og torden": "Heavy sleet and thunder",
    "Kraftig sne": "Heavy snow",
    "Kraftig sne og torden": "Heavy snow and thunder",
    "Kraftige regnbyger": "Heavy rain showers",
    "Kraftige regnbyger og torden": "Heavy rain showers and thunder",
    "Kraftige sludbyger": "Heavy sleet showers",
    "Kraftige sludbyger og torden": "Heavy sleet showers and thunder",
    "Kraftige snebyger": "Heavy snow showers",
    "Kraftige snebyger og torden": "Heavy snow showers and thunder",
    "Kron- og dåvildt har store lokale forvaltningsplaner. Appen viser kun de generelle tider.": (
        "Red deer and fallow deer have large local management plans. The app shows the general seasons only."
    ),
    "Kunne ikke finde din position. Listen viser hele Danmark. Vælg sted.": (
        "Could not find your location. The list shows all of Denmark. Pick a place."
    ),
    "Kunne ikke hente vejret. Tjek forbindelsen.": (
        "Could not fetch the weather. Check the connection."
    ),
    "Kunne ikke finde position": "Could not find your location",
    "Kunne ikke opdatere din position. Viser sidst kendte sted: %@.": (
        "Could not update your location. Showing the last known place: %@."
    ),
    "Latinsk navn": "Latin name",
    "Licenser: CC0, public domain, CC BY og CC BY-SA. Fotograf og licens står under hvert billede. Billederne er beskåret og skaleret.": (
        "Licences: CC0, public domain, CC BY and CC BY-SA. "
        "The photographer and the licence are shown under each image. Images are cropped and scaled."
    ),
    "Let regn": "Light rain",
    "Let regn og torden": "Light rain and thunder",
    "Let regnbyger": "Light rain showers",
    "Let regnbyger og torden": "Light rain showers and thunder",
    "Let skyet": "Fair",
    "Let slud": "Light sleet",
    "Let slud og torden": "Light sleet and thunder",
    "Let sludbyger": "Light sleet showers",
    "Let sludbyger og torden": "Light sleet showers and thunder",
    "Let sne": "Light snow",
    "Let sne og torden": "Light snow and thunder",
    "Let snebyger": "Light snow showers",
    "Let snebyger og torden": "Light snow showers and thunder",
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
    "Fugtighed": "Humidity",
    "↑ Stigende": "↑ Rising",
    "↓ Faldende": "↓ Falling",
    "→ Uændret": "→ Steady",
    "Mangler data": "Missing data",
    "Maks %@° · Min %@°": "Max %@° · Min %@°",
    "Maks %@°, min %@°.": "Max %@°, min %@°.",
    "Markeret": "Selected",
    "Mest specifikke sted gælder: ø før område før region før Danmark.": (
        "The most specific place wins: island before area before region before Denmark."
    ),
    "Min position": "My location",
    "Månen": "Moon",
    "Mørk": "Dark",
    "Nedbør": "Precipitation",
    "Nedbør %@ mm.": "Precipitation %@ mm.",
    "Nedlagt vildt": "Game taken",
    "Nymåne": "New moon",
    "N": "N",
    "NØ": "NE",
    "NV": "NW",
    "Note": "Note",
    "Notér %@": "Record %@",
    "Næste: %@, %@": "Next: %@, %@",
    "Offline. Bruger gemt data.": "Offline. Using saved data.",
    "Om registret": "About the register",
    "Områder": "Areas",
    "Opdateret": "Updated",
    "Opdateret fra net": "Updated from the web",
    "Position er slået fra. Listen viser hele Danmark. Vælg sted, eller slå position til.": (
        "Location is off. The list shows all of Denmark. Pick a place, or turn location on."
    ),
    "Positionen bruges kun til sted, sol og vejr": "Location used only for place, sun and weather",
    "Posten er slettet.": "The entry has been deleted.",
    "Privat og offline": "Private and offline",
    "Privatliv": "Privacy",
    "Påkørt hjortevildt": "Deer hit by a vehicle",
    "Regioner": "Regions",
    "Regler": "Rules",
    "Regn": "Rain",
    "Regn og torden": "Rain and thunder",
    "Regnbyger": "Rain showers",
    "Regnbyger og torden": "Rain showers and thunder",
    "Ret": "Edit",
    "Ring 1812": "Call 1812",    "Ring 1812, Dyrenes Beskyttelses Vagtcentral": (
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
    "S": "S",
    "SV": "SW",
    "SØ": "SE",
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
    "Sidste kvarter": "Last quarter",
    "Skjult": "Hidden",
    "Skriver til Schweiss-sekretariatet": "Emails the Schweiss secretariat",
    "Slet": "Delete",
    "Skyet": "Cloudy",
    "Slud": "Sleet",
    "Slud og torden": "Sleet and thunder",
    "Sludbyger": "Sleet showers",
    "Sludbyger og torden": "Sleet showers and thunder",
    "Sne": "Snow",
    "Sne og torden": "Snow and thunder",
    "Snebyger": "Snow showers",
    "Snebyger og torden": "Snow showers and thunder",
    "Slået fra i Indstillinger": "Turned off in Settings",
    "Sol og måne": "Sun and moon",
    "Sol og vejr": "Sun and weather",
    "Solopgang %@, solnedgang %@. %@": "Sunrise %@, sunset %@. %@",
    "Sorteret efter næste åbning.": "Sorted by next opening.",
    "Solnedgang": "Sunset",
    "Solopgang": "Sunrise",
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
    "Temperatur": "Temperature",
    "Tilføj": "Add",
    "Tiltagende måne": "Waxing moon",
    "Tiltagende månesegl": "Waxing crescent",
    "Tilføj til journal": "Add to journal",
    "Tåge": "Fog",
    "Udseende": "Appearance",
    "Ukendt": "Unknown",
    "Valgt": "Selected",
    "Velkommen til JagtFokus": "Welcome to JagtFokus",
    "Vejret": "Weather",
    "Vejret hentes fra MET i Norge med din position afrundet til omkring en kilometer. Stednavnet slår Apple op. Vi får aldrig din position.": (
        "The weather comes from MET Norway with your location rounded to about 1 km. "
        "Apple looks up the place name. We never receive your location."
    ),
    "Vejret vises kun for de næste ti dage.": "The weather is shown only for the next ten days.",
    "Version": "Version",
    "Vigtigt": "Important",
    "V": "W",
    "Vildtudbytte": "Bag",
    "Vind": "Wind",
    "Vind op til %@ m/s.": "Wind up to %@ m/s.",
    "Vind op til %@ m/s fra %@.": "Wind up to %@ m/s from %@.",
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
    "Åbn privatlivspolitikken": "Open the privacy policy (in Danish)",
    "Åbn sol og vejr for dagen": "Open the day's sun and weather",
    "Åbner": "Opens",
    "Åbner Naturstyrelsen": "Opens the Danish Nature Agency",
    "Åbner billedet på Wikimedia Commons": "Opens the image at Wikimedia Commons",
    "Åbner schweiss.dk": "Opens schweiss.dk",
    "Øer": "Islands",
    "Ø": "E",
    "Øer og områder med egne tider slår de generelle.": (
        "Islands and areas with their own seasons beat the general ones."
    ),
    "Øvrige fugle": "Other birds",
    "Øvrige pattedyr": "Other mammals",
    "åbner %@": "opens %@",
}

# Keys with a count that changes the words around it. Danish is the source language,
# so it gets its own forms too. Each language: (one, other).
PLURALS = {
    "%lld arter": {
        "da": ("%lld art", "%lld arter"),
        "en": ("%lld species", "%lld species"),
    },
    "%lld har sidste dag inden for en uge": {
        "da": ("%lld har sidste dag inden for en uge", "%lld har sidste dag inden for en uge"),
        "en": ("%lld has its last day within a week", "%lld have their last day within a week"),
    },
    "%lld lokale tider": {
        "da": ("%lld lokal tid", "%lld lokale tider"),
        "en": ("%lld local season", "%lld local seasons"),
    },
    "%lld stykker": {
        "da": ("%lld stykke", "%lld stykker"),
        "en": ("%lld animal", "%lld animals"),
    },
}

# Keys whose meaning is not obvious from the text alone.
COMMENTS = {
    "%@ %@": "Weekday and date on a day button, e.g. “Saturday 24 Oct”.",
    "%@ · %@": "A date and a place, separated by a middle dot.",
    "%@, %@": "A place, then a date, e.g. “Zealand, 16 October”.",
    "%@, den %@": "The place and date the sun times belong to, e.g. “Zealand, 16 October”.",
    "%@ m/s fra %@": "Wind speed and where it comes from, e.g. “6,8 m/s fra Ø”.",
    "Nu": "Weather page section: the forecast hour nearest now.",
    "Midt på dagen": "Weather page section on later days: the forecast at 12:00.",
    "Resten af dagen": "Weather page section for today: the hours from now to midnight.",
    "Hele dagen": "Weather page section on later days: the whole day.",
    "Sol og vejr": "The sun card on the first tab, and the page it opens.",
    "↑ Stigende": "How the barometer has moved over the next three hours: rising.",
    "↓ Faldende": "How the barometer has moved over the next three hours: falling.",
    "→ Uændret": "How the barometer has moved over the next three hours: steady.",
    "%@, %@ oplyst.": "The moon's name and how much of its disc is lit, read aloud by VoiceOver.",
    "N": "Compass point for the wind, eight points, e.g. “Vind op til 6,8 m/s fra NØ”.",
    "Op til %@ m/s": "The strongest wind of the day, on the sun card, e.g. “Op til 6,8 m/s”.",
    "Op til %@ m/s fra %@": "The strongest wind of the day and where it comes from, e.g. “Op til 6,8 m/s fra Ø”.",
    "%lld": "A count on its own, shown in a large font.",
    "%@ oplyst": "How much of the moon's disc is lit, e.g. “63 % oplyst”.",
    "%@. %@ oplyst.": "The moon's name and how much of its disc is lit, read aloud by VoiceOver.",
    "til": "Between the first and the last day of a season, read aloud by VoiceOver.",
    "%lld stykker": "How many animals were taken. The app never says which sex or age.",
    "stykke": "Follows a count of animals taken.",
    "Jagtbart": "The first tab, and the word for a species with an open season.",
    "Note": "A short note from the hunting regulations, shown as plain text.",
    "Data": "A section about where the season data comes from.",
    "Gemt område: %@, hentet %@": "The map's status inside a saved area: its name, then the date it was downloaded.",
    "Licens": "A link to the licence terms of the cadastral data.",
    "Gem": "The button that saves the map area the frame shows.",
    "Område": "The first word of a saved area's default name, followed by a number.",
    "Navn": "The placeholder of the field where a saved map area is named.",
    "Gemmer %@ …": "The card while an area is being saved: the area's name.",
    "%@ er gemt": "The card when an area has been saved: the area's name.",
    "Hentet %@ · %@": "A saved area in the list: the date it was downloaded, then its size on disk.",
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


def plural_variations(one, other):
    """A String Catalog entry that picks the form from the count."""
    return {
        "variations": {
            "plural": {
                "one": {"stringUnit": {"state": "translated", "value": one}},
                "other": {"stringUnit": {"state": "translated", "value": other}},
            }
        }
    }


def main():
    directory = sys.argv[1] if len(sys.argv) > 1 else None
    if directory and os.path.isdir(directory):
        found = extracted_keys(directory)
        known = set(ENGLISH) | set(PLURALS)
        missing = sorted(found - known)
        extra = sorted(known - found)
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

    both = set(ENGLISH) & set(PLURALS)
    if both:
        print("In both ENGLISH and PLURALS:", sorted(both))
        return 1

    strings = {}
    for key in sorted(set(ENGLISH) | set(PLURALS)):
        if key in PLURALS:
            localizations = {
                language: plural_variations(*forms) for language, forms in PLURALS[key].items()
            }
        else:
            localizations = {
                "en": {"stringUnit": {"state": "translated", "value": ENGLISH[key]}}
            }
        entry = {"localizations": localizations}
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
