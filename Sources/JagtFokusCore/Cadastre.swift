import Foundation

/// One cadastral parcel (jordstykke): the service's feature id, the matrikelnummer
/// shown on the map, the ejerlav it belongs to, and its boundaries. Display only —
/// no logic may use the boundaries.
public struct Parcel: Sendable, Equatable, Identifiable {
    /// GeoJSON feature id from the service.
    public var id: String
    /// Matrikelnummer, for example "12a".
    public var number: String
    /// Ejerlavsnavn. Empty from the service, which sends only the code.
    public var district: String
    /// Ejerlavskode, when the service sent one.
    public var districtCode: Int?
    /// Registreret areal in square metres, when the service sent one.
    public var area: Int?
    /// Polygon → ring → point. A MultiPolygon becomes several polygons, a Polygon one.
    public var polygons: [[[Coordinate]]]

    public init(
        id: String,
        number: String,
        district: String,
        districtCode: Int? = nil,
        area: Int? = nil,
        polygons: [[[Coordinate]]]
    ) {
        self.id = id
        self.number = number
        self.district = district
        self.districtCode = districtCode
        self.area = area
        self.polygons = polygons
    }
}

/// Why a parcel file was refused. The id names the feature at fault.
public enum ParcelProblem: Equatable, Sendable {
    /// A point outside Denmark — also what swapped axes look like.
    case outsideDenmark(id: String)
    /// A ring whose last point is not its first.
    case openRing(id: String)
}

/// Thrown instead of a set when a file fails a check.
public struct ParcelsRefused: Error, Equatable, Sendable {
    public var problems: [ParcelProblem]

    public init(problems: [ParcelProblem]) {
        self.problems = problems
    }
}

/// A set of parcels from the service or from a compact file on disk.
public struct ParcelSet: Sendable, Equatable {
    public var parcels: [Parcel]

    public init(parcels: [Parcel]) {
        self.parcels = parcels
    }

    public var count: Int { parcels.count }

    /// Nothing carries a problem out of `decodeChecked` — it throws instead — so a
    /// set that exists is always clean.
    public var problems: [ParcelProblem] { [] }
}

public extension ParcelSet {
    /// Service response (GML 3.2) or our own compact GeoJSON file.
    /// Throws ParcelsRefused or DecodingError.
    static func decodeChecked(from data: Data) throws -> ParcelSet {
        try CadastrePage.decode(from: data).parcels
    }

    /// The compact GeoJSON, with the number of features in the file.
    fileprivate static func decodeJSON(_ data: Data) throws -> (parcels: ParcelSet, features: Int) {
        let raw = try JSONDecoder().decode(RawCollection.self, from: data)
        var parcels: [Parcel] = []
        for feature in raw.features {
            guard let type = feature.geometry?.type,
                  let polygons = polygons(from: feature.geometry?.coordinates, type: type) else {
                // A Point or another geometry: skip the feature, not the whole file.
                continue
            }
            let id = identifier(feature.id)
            let properties = feature.properties ?? [:]
            parcels.append(Parcel(
                id: id,
                number: properties.string(CadastreService.numberProperty)
                    ?? properties.string(Self.compactNumber) ?? "",
                district: properties.string("ejerlavsnavn")
                    ?? properties.string(Self.compactDistrict) ?? "",
                districtCode: properties.int(Self.compactDistrictCode),
                area: properties.int(Self.compactArea),
                polygons: polygons
            ))
        }
        return (try checked(parcels), raw.features.count)
    }

    /// Dedupes two pages by id, keeping the first page's parcel.
    func merging(_ other: ParcelSet) -> ParcelSet {
        var seen = Set<String>()
        var merged: [Parcel] = []
        for parcel in parcels + other.parcels {
            if seen.insert(parcel.id).inserted {
                merged.append(parcel)
            }
        }
        return ParcelSet(parcels: merged)
    }

    /// Compact FeatureCollection for MapLibre and disk: properties "nr" and "ejerlav"
    /// only, coordinates rounded to 6 decimals (~0.1 m). decodeChecked reads it back.
    func geoJSON() throws -> Data {
        let features: [[String: Any]] = parcels.map { parcel in
            var properties: [String: Any] = [
                Self.compactNumber: parcel.number,
                Self.compactDistrict: parcel.district,
            ]
            // Older files have neither, and a tap then shows the number alone.
            if let code = parcel.districtCode { properties[Self.compactDistrictCode] = code }
            if let area = parcel.area { properties[Self.compactArea] = area }
            return [
                "type": "Feature",
                "id": parcel.id,
                "properties": properties,
                "geometry": [
                    "type": "MultiPolygon",
                    "coordinates": parcel.polygons.map { polygon in
                        polygon.map { ring in
                            ring.map { [Self.rounded($0.longitude), Self.rounded($0.latitude)] }
                        }
                    },
                ],
            ]
        }
        return try JSONSerialization.data(
            withJSONObject: ["type": "FeatureCollection", "features": features]
        )
    }
}

fileprivate extension ParcelSet {
    /// Names in our own compact file — shorter than the service's.
    static let compactNumber = "nr"
    static let compactDistrict = "ejerlav"
    static let compactDistrictCode = "ejerlavskode"
    static let compactArea = "areal"

    static func isXML(_ data: Data) -> Bool {
        guard let first = data.first(where: { byte in
            byte != 0x20 && byte != 0x09 && byte != 0x0A && byte != 0x0D
        }) else { return false }
        return first == UInt8(ascii: "<")
    }

    static func decodeGML(_ data: Data) throws -> CadastrePage {
        let parser = XMLParser(data: data)
        let delegate = GMLParcelParser()
        parser.shouldProcessNamespaces = true
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "GML could not be parsed")
            )
        }
        if delegate.sawException || delegate.malformed {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "WFS exception or a broken posList")
            )
        }
        return CadastrePage(
            parcels: try checked(delegate.parcels),
            numberReturned: delegate.numberReturned,
            numberMatched: delegate.numberMatched,
            members: delegate.members,
            skipped: delegate.skipped
        )
    }

    static func checked(_ parcels: [Parcel]) throws -> ParcelSet {
        var problems: [ParcelProblem] = []
        for parcel in parcels {
            if parcel.polygons.contains(where: { $0.contains(where: { !isClosed($0) }) }) {
                problems.append(.openRing(id: parcel.id))
            }
            if !isInsideDenmark(parcel.polygons) {
                problems.append(.outsideDenmark(id: parcel.id))
            }
        }
        guard problems.isEmpty else { throw ParcelsRefused(problems: problems) }
        return ParcelSet(parcels: parcels)
    }

    /// Six decimals ≈ 0.1 m.
    static func rounded(_ value: Double) -> Double {
        (value * 1_000_000).rounded() / 1_000_000
    }

    /// String or number, as GeoJSON feature ids come.
    static func identifier(_ value: JSONValue?) -> String {
        switch value {
        case .string(let string):
            return string
        case .number(let number):
            // Whole numbers without a decimal point: 12, not 12.0.
            return number == number.rounded() ? String(Int64(number)) : String(number)
        default:
            return ""
        }
    }

    /// nil for a geometry that is not a Polygon or MultiPolygon with well-formed
    /// coordinates.
    static func polygons(from coordinates: JSONValue?, type: String) -> [[[Coordinate]]]? {
        switch type {
        case "Polygon":
            guard let coordinates, let polygon = polygon(from: coordinates) else { return nil }
            return [polygon]
        case "MultiPolygon":
            guard let coordinates, case .array(let raw) = coordinates else { return nil }
            let polygons = raw.compactMap(polygon(from:))
            guard polygons.count == raw.count, !polygons.isEmpty else { return nil }
            return polygons
        default:
            return nil
        }
    }

    static func polygon(from coordinates: JSONValue) -> [[Coordinate]]? {
        guard case .array(let raw) = coordinates else { return nil }
        let rings = raw.compactMap(ring(from:))
        guard rings.count == raw.count, !rings.isEmpty else { return nil }
        return rings
    }

    static func ring(from coordinates: JSONValue) -> [Coordinate]? {
        guard case .array(let raw) = coordinates else { return nil }
        let points = raw.compactMap(point(from:))
        guard points.count == raw.count, !points.isEmpty else { return nil }
        return points
    }

    /// GeoJSON order: [longitude, latitude].
    static func point(from coordinates: JSONValue) -> Coordinate? {
        guard case .array(let pair) = coordinates, pair.count == 2,
              let longitude = pair[0].doubleValue, let latitude = pair[1].doubleValue else { return nil }
        return Coordinate(latitude: latitude, longitude: longitude)
    }

    static func isClosed(_ ring: [Coordinate]) -> Bool {
        guard let first = ring.first, let last = ring.last else { return false }
        return first == last
    }

    static func isInsideDenmark(_ polygons: [[[Coordinate]]]) -> Bool {
        polygons.allSatisfy { polygon in
            polygon.allSatisfy { ring in ring.allSatisfy(GeoBox.denmark.contains) }
        }
    }
}

private struct RawCollection: Decodable {
    var features: [RawFeature]
}

private struct RawFeature: Decodable {
    var id: JSONValue?
    var geometry: RawGeometry?
    var properties: [String: JSONValue]?
}

private struct RawGeometry: Decodable {
    var type: String?
    var coordinates: JSONValue?
}

/// Any JSON value, for the parts of the response whose shape varies: a feature id can
/// be a string or a number, and properties are free-form.
private enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    var doubleValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func string(_ key: String) -> String? {
        self[key]?.stringValue
    }

    /// A whole number, written as a JSON number or as text.
    func int(_ key: String) -> Int? {
        if let number = self[key]?.doubleValue { return Int(number) }
        return self[key]?.stringValue.flatMap { Int($0) }
    }
}

/// One page from the service, with what paging needs: the counts the service put on the
/// collection and the raw members. The parser skips a member whose geometry it does not read,
/// so the parcels alone can make a full page look short.
public struct CadastrePage: Sendable, Equatable {
    public var parcels: ParcelSet
    /// `numberReturned` on `wfs:FeatureCollection`, when the service sent a number.
    public var numberReturned: Int?
    /// `numberMatched`, when it is a number (WFS allows "unknown").
    public var numberMatched: Int?
    /// `wfs:member` elements in the page (features in a compact file).
    public var members: Int
    /// Members that gave no parcel: a geometry the parser does not read.
    public var skipped: Int

    public init(parcels: ParcelSet, numberReturned: Int?, numberMatched: Int?, members: Int, skipped: Int) {
        self.parcels = parcels
        self.numberReturned = numberReturned
        self.numberMatched = numberMatched
        self.members = members
        self.skipped = skipped
    }

    /// Service GML or our compact GeoJSON. Throws as `ParcelSet.decodeChecked` does.
    public static func decode(from data: Data) throws -> CadastrePage {
        if ParcelSet.isXML(data) {
            return try ParcelSet.decodeGML(data)
        }
        let decoded = try ParcelSet.decodeJSON(data)
        return CadastrePage(
            parcels: decoded.parcels,
            numberReturned: nil,
            numberMatched: nil,
            members: decoded.features,
            skipped: decoded.features - decoded.parcels.count
        )
    }
}

/// When to ask for the next page.
public enum CadastrePaging {
    /// From the raw page: `numberReturned`, else the members. A full page goes on unless
    /// `numberMatched` says this was the last. `next` is not read: Datafordeler sends it on the last page too.
    public static func hasMore(_ page: CadastrePage, startIndex: Int, pageSize: Int) -> Bool {
        let returned = page.numberReturned ?? page.members
        guard returned >= pageSize else { return false }
        if let matched = page.numberMatched, startIndex + returned >= matched { return false }
        return true
    }
}

/// The Datafordeler matrikel WFS: the request the map tab sends page by page.
public enum CadastreService {
    public static let host = "wfs.datafordeler.dk"
    public static let pageSize = 5_000
    public static let attribution = "© Geodatastyrelsen, Matriklen, CC BY 4.0"
    /// Datafordeler's terms: the licence credit links here.
    public static let licenceURL = URL(string: "https://datafordeler.dk/vejledning/brugervilkaar/ejendomsoplysninger-ebr-og-mat/")!

    private static let path = "/MATRIKLEN2/MatGaeldendeOgForeloebigWFS/1.0.0/WFS"

    /// The composed WFS answers GML 3.2 only. `gml32` is the short name it accepts.
    /// GeoJSON is our own disk format, not a service format.
    static let outputFormat = "gml32"

    /// Matrikelnummer in the GML. The service has no ejerlavsnavn, only ejerlavskode,
    /// so a GML parcel's district stays empty. Compact files still use "ejerlav".
    static let numberProperty = "matrikelnummer"

    /// One page of parcels for the box, GML 3.2 in EPSG:4326 (longitude, latitude).
    public static func requestURL(box: GeoBox, apiKey: String, startIndex: Int) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = [
            URLQueryItem(name: "service", value: "WFS"),
            URLQueryItem(name: "version", value: "2.0.0"),
            URLQueryItem(name: "request", value: "GetFeature"),
            URLQueryItem(name: "typeNames", value: "mat:Jordstykke_Gaeldende"),
            URLQueryItem(name: "outputFormat", value: outputFormat),
            URLQueryItem(name: "srsName", value: "EPSG:4326"),
            URLQueryItem(name: "bbox", value: "\(box.west),\(box.south),\(box.east),\(box.north),EPSG:4326"),
            URLQueryItem(name: "count", value: String(pageSize)),
            URLQueryItem(name: "startIndex", value: String(startIndex)),
            URLQueryItem(name: "apikey", value: apiKey),
        ]
        return components.url!
    }
}

/// Reads a Jordstykke GML page. Local names only, so a prefix change does not matter.
/// posList is longitude then latitude, which is what this service returns for EPSG:4326.
private final class GMLParcelParser: NSObject, XMLParserDelegate {
    var parcels: [Parcel] = []
    var sawException = false
    var malformed = false
    var members = 0
    var skipped = 0
    var numberReturned: Int?
    var numberMatched: Int?

    private var id = ""
    private var number = ""
    private var districtCode: Int?
    private var area: Int?
    private var polygons: [[[Coordinate]]] = []
    private var rings: [[Coordinate]] = []
    private var ring: [Coordinate] = []
    private var capture: Capture?
    private var text = ""

    private enum Capture { case number, districtCode, area, pos }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch local(elementName) {
        case "Exception", "ExceptionReport":
            sawException = true
        case "FeatureCollection":
            numberReturned = attributeDict["numberReturned"].flatMap { Int($0) }
            numberMatched = attributeDict["numberMatched"].flatMap { Int($0) }
        case "member":
            members += 1
            id = ""
            number = ""
            districtCode = nil
            area = nil
            polygons = []
            rings = []
            ring = []
        case "Jordstykke_Gaeldende":
            id = attributeDict["id"] ?? attributeDict["gml:id"] ?? ""
        case "matrikelnummer":
            capture = .number
            text = ""
        case "ejerlavskode":
            capture = .districtCode
            text = ""
        case "registreretAreal":
            capture = .area
            text = ""
        case "Polygon", "PolygonPatch":
            rings = []
        case "LinearRing":
            ring = []
        case "posList", "pos":
            capture = .pos
            text = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capture != nil { text += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch local(elementName) {
        case "matrikelnummer":
            if capture == .number {
                number = text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            capture = nil
        case "ejerlavskode":
            if capture == .districtCode {
                districtCode = Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            capture = nil
        case "registreretAreal":
            if capture == .area {
                // The service writes "287.0"; the m² unit is an attribute.
                area = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)).map { Int($0.rounded()) }
            }
            capture = nil
        case "posList":
            ring = points(text)
            capture = nil
        case "pos":
            ring.append(contentsOf: points(text))
            capture = nil
        case "LinearRing":
            if !ring.isEmpty { rings.append(ring) }
            ring = []
        case "Polygon", "PolygonPatch":
            if !rings.isEmpty { polygons.append(rings) }
            rings = []
        case "member":
            if polygons.isEmpty {
                skipped += 1
            } else {
                parcels.append(Parcel(
                    id: id,
                    number: number,
                    district: "",
                    districtCode: districtCode,
                    area: area,
                    polygons: polygons
                ))
            }
        default:
            break
        }
    }

    private func local(_ name: String) -> String {
        guard let colon = name.lastIndex(of: ":") else { return name }
        return String(name[name.index(after: colon)...])
    }

    /// Space-separated pairs. An odd count is a broken list, not a parcel to skip.
    private func points(_ text: String) -> [Coordinate] {
        let numbers = text.split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
        let tokens = text.split(whereSeparator: \.isWhitespace)
        if tokens.count != numbers.count || !numbers.count.isMultiple(of: 2) {
            malformed = true
            return []
        }
        var points: [Coordinate] = []
        var index = 0
        while index < numbers.count {
            points.append(Coordinate(latitude: numbers[index + 1], longitude: numbers[index]))
            index += 2
        }
        return points
    }
}
