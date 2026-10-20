import Foundation
import Testing
@testable import JagtFokusCore

struct CadastreTests {
    /// The probe box from the plan: a corner of Aarhus.
    let box = GeoBox(south: 56.160, west: 10.200, north: 56.163, east: 10.205)

    /// Recorded from Datafordeler on 20 October 2026, trimmed to three features.
    /// The service speaks GML 3.2, not GeoJSON. Coordinates are longitude then latitude.
    /// The Aarhus sample had no MultiSurface, so that shape is tested separately.
    static let fixture = """
    <?xml version="1.0" encoding="UTF-8"?>
    <wfs:FeatureCollection xmlns:wfs="http://www.opengis.net/wfs/2.0" xmlns:mat="http://data.gov.dk/schemas/matrikel/1" xmlns:gml="http://www.opengis.net/gml/3.2">
      <wfs:member>
        <mat:Jordstykke_Gaeldende gml:id="Jordstykke_Gaeldende.2505326">
          <mat:matrikelnummer>1924</mat:matrikelnummer>
          <mat:ejerlavskode>2006351</mat:ejerlavskode>
          <mat:geometri>
            <gml:Polygon srsDimension="2" srsName="http://www.opengis.net/gml/srs/epsg.xml#4326">
              <gml:exterior>
                <gml:LinearRing>
                  <gml:posList>10.200533267 56.161457358 10.200220431 56.161356227 10.200131281 56.161326066 10.200215807 56.16124771 10.200614633 56.161379957 10.200533267 56.161457358</gml:posList>
                </gml:LinearRing>
              </gml:exterior>
            </gml:Polygon>
          </mat:geometri>
        </mat:Jordstykke_Gaeldende>
      </wfs:member>
      <wfs:member>
        <mat:Jordstykke_Gaeldende gml:id="Jordstykke_Gaeldende.2915646">
          <mat:matrikelnummer>1244a</mat:matrikelnummer>
          <mat:ejerlavskode>2006351</mat:ejerlavskode>
          <mat:geometri>
            <gml:Polygon srsDimension="2" srsName="http://www.opengis.net/gml/srs/epsg.xml#4326">
              <gml:exterior>
                <gml:LinearRing>
                  <gml:posList>10.204580699 56.160808647 10.204778307 56.160842168 10.204618626 56.16113143 10.204412555 56.161096634 10.204525529 56.16090319 10.204580699 56.160808647</gml:posList>
                </gml:LinearRing>
              </gml:exterior>
            </gml:Polygon>
          </mat:geometri>
        </mat:Jordstykke_Gaeldende>
      </wfs:member>
      <wfs:member>
        <mat:Jordstykke_Gaeldende gml:id="Jordstykke_Gaeldende.2917261">
          <mat:matrikelnummer>1259h</mat:matrikelnummer>
          <mat:ejerlavskode>2006351</mat:ejerlavskode>
          <mat:geometri>
            <gml:Polygon srsDimension="2" srsName="http://www.opengis.net/gml/srs/epsg.xml#4326">
              <gml:exterior>
                <gml:LinearRing>
                  <gml:posList>10.202679373 56.159846175 10.202696439 56.159851795 10.202767853 56.159984822 10.202781758 56.159997455 10.202851942 56.160023118 10.202884908 56.160033085 10.202863439 56.160063287 10.202813572 56.16004839 10.202649356 56.159895564 10.202472256 56.159838459 10.202519445 56.15979345 10.202679373 56.159846175</gml:posList>
                </gml:LinearRing>
              </gml:exterior>
            </gml:Polygon>
          </mat:geometri>
        </mat:Jordstykke_Gaeldende>
      </wfs:member>
    </wfs:FeatureCollection>
    """

    func decode(_ xml: String) throws -> ParcelSet {
        try ParcelSet.decodeChecked(from: Data(xml.utf8))
    }

    func refused(_ data: Data) -> ParcelsRefused? {
        do {
            _ = try ParcelSet.decodeChecked(from: data)
            return nil
        } catch let error as ParcelsRefused {
            return error
        } catch {
            return nil
        }
    }

    @Test func requestURLIsHttpsOnDatafordeler() {
        let url = CadastreService.requestURL(box: box, apiKey: "test-key", startIndex: 10_000)
        #expect(url.scheme == "https")
        #expect(url.host == "wfs.datafordeler.dk")
        #expect(url.path == "/MATRIKLEN2/MatGaeldendeOgForeloebigWFS/1.0.0/WFS")

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
        #expect(query["service"] == "WFS")
        #expect(query["version"] == "2.0.0")
        #expect(query["request"] == "GetFeature")
        #expect(query["typeNames"] == "mat:Jordstykke_Gaeldende")
        #expect(query["outputFormat"] == "gml32")
        #expect(query["srsName"] == "EPSG:4326")
        #expect(query["bbox"] == "\(box.west),\(box.south),\(box.east),\(box.north),EPSG:4326")
        #expect(query["count"] == "5000")
        #expect(query["startIndex"] == "10000")
        #expect(query["apikey"] == "test-key")
        #expect(query["propertyName"] == nil)
    }

    @Test func decodesRecordedFixture() throws {
        let set = try decode(Self.fixture)
        #expect(set.count == 3)
        #expect(set.problems.isEmpty)
        let first = try #require(set.parcels.first)
        #expect(first.id == "Jordstykke_Gaeldende.2505326")
        #expect(first.number == "1924")
        // The service sends ejerlavskode, not a name. The name stays empty.
        #expect(first.district == "")
        #expect(first.polygons.count == 1)
        #expect(first.polygons[0].count == 1)
        #expect(first.polygons[0][0].count == 6)

        let latitudeMargin = 500.0 / 111_320
        let centreLatitude = (box.south + box.north) / 2
        let longitudeMargin = 500.0 / (111_320 * cos(centreLatitude * .pi / 180))
        for parcel in set.parcels {
            for polygon in parcel.polygons {
                for ring in polygon {
                    for point in ring {
                        #expect(box.south - latitudeMargin <= point.latitude
                            && point.latitude <= box.north + latitudeMargin)
                        #expect(box.west - longitudeMargin <= point.longitude
                            && point.longitude <= box.east + longitudeMargin)
                    }
                }
            }
        }
    }

    /// Swap each posList pair, as a lat/lon answer would come out.
    static func swappedAxes(_ xml: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<gml:posList>([^<]+)</gml:posList>") else {
            return xml
        }
        let range = NSRange(xml.startIndex..., in: xml)
        var result = xml
        let matches = regex.matches(in: xml, range: range).reversed()
        for match in matches {
            guard let content = Range(match.range(at: 1), in: xml) else { continue }
            let numbers = xml[content].split(whereSeparator: \.isWhitespace).map(String.init)
            var swapped: [String] = []
            var index = 0
            while index + 1 < numbers.count {
                swapped.append(numbers[index + 1])
                swapped.append(numbers[index])
                index += 2
            }
            let replacement = "<gml:posList>\(swapped.joined(separator: " "))</gml:posList>"
            if let full = Range(match.range, in: result) {
                result.replaceSubrange(full, with: replacement)
            }
        }
        return result
    }

    @Test func refusesSwappedAxes() throws {
        let data = Data(Self.swappedAxes(Self.fixture).utf8)
        let refusal = try #require(refused(data), "Expected ParcelsRefused")
        #expect(refusal.problems.contains(.outsideDenmark(id: "Jordstykke_Gaeldende.2505326")))
        #expect(refusal.problems.count == 3)
    }

    @Test func refusesOpenRing() throws {
        let open = """
        <?xml version="1.0" encoding="UTF-8"?>
        <wfs:FeatureCollection xmlns:wfs="http://www.opengis.net/wfs/2.0" xmlns:mat="http://data.gov.dk/schemas/matrikel/1" xmlns:gml="http://www.opengis.net/gml/3.2">
          <wfs:member>
            <mat:Jordstykke_Gaeldende gml:id="Jordstykke_Gaeldende.1">
              <mat:matrikelnummer>12a</mat:matrikelnummer>
              <mat:geometri>
                <gml:Polygon>
                  <gml:exterior>
                    <gml:LinearRing>
                      <gml:posList>10.201 56.161 10.202 56.161 10.202 56.162</gml:posList>
                    </gml:LinearRing>
                  </gml:exterior>
                </gml:Polygon>
              </mat:geometri>
            </mat:Jordstykke_Gaeldende>
          </wfs:member>
        </wfs:FeatureCollection>
        """
        let refusal = try #require(refused(Data(open.utf8)), "Expected ParcelsRefused")
        #expect(refusal.problems.contains(.openRing(id: "Jordstykke_Gaeldende.1")))
        #expect(!refusal.problems.contains(.outsideDenmark(id: "Jordstykke_Gaeldende.1")))
    }

    /// The Aarhus page had no MultiSurface. This one is written to the same shape.
    @Test func decodesMultiSurfaceWithHole() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <wfs:FeatureCollection xmlns:wfs="http://www.opengis.net/wfs/2.0" xmlns:mat="http://data.gov.dk/schemas/matrikel/1" xmlns:gml="http://www.opengis.net/gml/3.2">
          <wfs:member>
            <mat:Jordstykke_Gaeldende gml:id="Jordstykke_Gaeldende.9">
              <mat:matrikelnummer>9a</mat:matrikelnummer>
              <mat:geometri>
                <gml:MultiSurface>
                  <gml:surfaceMember>
                    <gml:Polygon>
                      <gml:exterior>
                        <gml:LinearRing>
                          <gml:posList>10.201 56.161 10.203 56.161 10.203 56.162 10.201 56.162 10.201 56.161</gml:posList>
                        </gml:LinearRing>
                      </gml:exterior>
                      <gml:interior>
                        <gml:LinearRing>
                          <gml:posList>10.2014 56.1612 10.2018 56.1612 10.2018 56.1616 10.2014 56.1616 10.2014 56.1612</gml:posList>
                        </gml:LinearRing>
                      </gml:interior>
                    </gml:Polygon>
                  </gml:surfaceMember>
                  <gml:surfaceMember>
                    <gml:Polygon>
                      <gml:exterior>
                        <gml:LinearRing>
                          <gml:posList>10.204 56.161 10.2045 56.161 10.2045 56.1614 10.204 56.1614 10.204 56.161</gml:posList>
                        </gml:LinearRing>
                      </gml:exterior>
                    </gml:Polygon>
                  </gml:surfaceMember>
                </gml:MultiSurface>
              </mat:geometri>
            </mat:Jordstykke_Gaeldende>
          </wfs:member>
        </wfs:FeatureCollection>
        """
        let set = try decode(xml)
        let parcel = try #require(set.parcels.first)
        #expect(parcel.polygons.count == 2)
        #expect(parcel.polygons[0].count == 2)
        #expect(parcel.polygons[1].count == 1)
    }

    @Test func refusesServiceException() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ows:ExceptionReport xmlns:ows="http://www.opengis.net/ows/1.1">
          <ows:Exception exceptionCode="InvalidParameterValue">
            <ows:ExceptionText>no</ows:ExceptionText>
          </ows:Exception>
        </ows:ExceptionReport>
        """
        #expect(throws: DecodingError.self) {
            try ParcelSet.decodeChecked(from: Data(xml.utf8))
        }
    }

    func parcel(_ id: String, number: String) -> Parcel {
        Parcel(
            id: id,
            number: number,
            district: "Ejerlav",
            polygons: [[[
                Coordinate(latitude: 56.161, longitude: 10.201),
                Coordinate(latitude: 56.161, longitude: 10.202),
                Coordinate(latitude: 56.162, longitude: 10.202),
                Coordinate(latitude: 56.162, longitude: 10.201),
                Coordinate(latitude: 56.161, longitude: 10.201),
            ]]]
        )
    }

    @Test func mergingDedupesPages() {
        let firstPage = ParcelSet(parcels: [parcel("x.1", number: "1"), parcel("x.2", number: "2")])
        let secondPage = ParcelSet(parcels: [parcel("x.2", number: "other"), parcel("x.3", number: "3")])
        let merged = firstPage.merging(secondPage)
        #expect(merged.count == firstPage.count + secondPage.count - 1)
        #expect(merged.parcels.first(where: { $0.id == "x.2" })?.number == "2")
    }

    static func rounded(_ value: Double) -> Double {
        (value * 1_000_000).rounded() / 1_000_000
    }

    static func rounded(_ set: ParcelSet) -> ParcelSet {
        ParcelSet(parcels: set.parcels.map { parcel in
            Parcel(
                id: parcel.id,
                number: parcel.number,
                district: parcel.district,
                polygons: parcel.polygons.map { polygon in
                    polygon.map { ring in
                        ring.map {
                            Coordinate(latitude: rounded($0.latitude), longitude: rounded($0.longitude))
                        }
                    }
                }
            )
        })
    }

    @Test func compactGeoJSONRoundTrips() throws {
        let set = try decode(Self.fixture)
        let data = try set.geoJSON()
        #expect(try ParcelSet.decodeChecked(from: data) == Self.rounded(set))

        let object = try JSONSerialization.jsonObject(with: data)
        let features = try #require((object as? [String: Any])?["features"] as? [[String: Any]])
        #expect(features.count == 3)
        for feature in features {
            let properties = try #require(feature["properties"] as? [String: String])
            #expect(properties.keys.sorted() == ["ejerlav", "nr"])
            #expect(properties["ejerlav"] == "")
        }
    }
}
