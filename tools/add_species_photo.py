#!/usr/bin/env python3
"""Add or replace a species photo from Wikimedia Commons.

    python3 tools/add_species_photo.py <species_id> "File:Some photo.jpg"
    python3 tools/add_species_photo.py <species_id> --share <other_species_id>

Downloads a 1600 px rendition, center-crops to 3:2, saves 1200x800 JPEG into
App/JagtFokus/Assets.xcassets/SpeciesPhotos/photo-<id>.imageset and records
artist + license in App/JagtFokus/Resources/species-photos.json.
Refuses licenses that forbid commercial use. Needs Pillow (pip install pillow).
Run `swift test` afterwards: SpeciesPhotoTests checks coverage and licenses.
"""
import html, io, json, re, sys, urllib.parse, urllib.request
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
JSON = ROOT / "App/JagtFokus/Resources/species-photos.json"
ASSETS = ROOT / "App/JagtFokus/Assets.xcassets/SpeciesPhotos"
UA = "JagtFokus/1.0 (iOS app; https://github.com/dkKenEgh/jagtapp)"
OK = re.compile(r"^(cc0|public domain|cc by(-sa)? \d)", re.I)

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()

def commons(file):
    q = {"action": "query", "titles": file, "prop": "imageinfo", "iiprop": "url|extmetadata",
         "iiurlwidth": "1600", "format": "json"}
    page = next(iter(json.loads(get("https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(q)))["query"]["pages"].values()))
    ii = page["imageinfo"][0]; m = ii["extmetadata"]
    val = lambda k: html.unescape(re.sub(r"<[^>]+>", "", m.get(k, {}).get("value", ""))).strip()
    return page["title"], ii.get("thumburl", ii["url"]), ii["descriptionurl"], val("Artist"), val("LicenseShortName"), val("LicenseUrl")

def main():
    data = json.loads(JSON.read_text())
    sid = sys.argv[1]
    if sys.argv[2] == "--share":
        data["species"][sid] = data["species"][sys.argv[3]]
    else:
        title, thumb, page, artist, license, license_url = commons(sys.argv[2])
        if not OK.match(license) or "-nc" in license.lower() or "-nd" in license.lower():
            sys.exit(f"Licens ikke tilladt: {license}")
        im = Image.open(io.BytesIO(get(thumb))).convert("RGB")
        w, h = im.size
        if w / h > 1.5:
            nw = int(h * 1.5); im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
        else:
            nh = int(w / 1.5); im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
        folder = ASSETS / f"photo-{sid}.imageset"; folder.mkdir(parents=True, exist_ok=True)
        im.resize((1200, 800), Image.LANCZOS).save(folder / f"{sid}.jpg", quality=80, optimize=True)
        (folder / "Contents.json").write_text(json.dumps(
            {"images": [{"filename": f"{sid}.jpg", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, indent=2))
        data["photos"][sid] = {"file": title, "artist": artist, "license": license,
                               "license_url": license_url, "source_url": page}
        data["species"][sid] = sid
        print(f"{sid}: {artist} · {license}. Tjek at 'artist' er et navn, ikke en URL eller beskrivelse.")
    used = set(data["species"].values())
    data["photos"] = {k: v for k, v in data["photos"].items() if k in used}
    JSON.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")

if __name__ == "__main__":
    main()
