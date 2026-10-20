import Foundation
import Testing
@testable import JagtFokusCore

/// Paging is decided from the raw page, not from the parcels the parser kept.
struct CadastrePagingTests {
    static func member(_ id: Int, geometry: String) -> String {
        """
          <wfs:member>
            <mat:Jordstykke_Gaeldende gml:id="Jordstykke_Gaeldende.\(id)">
              <mat:matrikelnummer>\(id)a</mat:matrikelnummer>
              <mat:geometri>\(geometry)</mat:geometri>
            </mat:Jordstykke_Gaeldende>
          </wfs:member>
        """
    }

    static let polygon = """
    <gml:Polygon><gml:exterior><gml:LinearRing><gml:posList>10.201 56.161 10.202 56.161 10.202 56.162 10.201 56.161</gml:posList></gml:LinearRing></gml:exterior></gml:Polygon>
    """

    /// A geometry the parser does not read.
    static let point = "<gml:Point><gml:pos>10.201 56.161</gml:pos></gml:Point>"

    static func page(_ members: [String], attributes: String) -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <wfs:FeatureCollection xmlns:wfs="http://www.opengis.net/wfs/2.0" xmlns:mat="http://data.gov.dk/schemas/matrikel/1" xmlns:gml="http://www.opengis.net/gml/3.2" \(attributes)>
        \(members.joined(separator: "\n"))
        </wfs:FeatureCollection>
        """.utf8)
    }

    @Test func readsTheCountsOnTheCollection() throws {
        let data = Self.page([Self.member(1, geometry: Self.polygon), Self.member(2, geometry: Self.polygon)],
                             attributes: #"numberMatched="273" numberReturned="2""#)
        let page = try CadastrePage.decode(from: data)
        #expect(page.numberReturned == 2)
        #expect(page.numberMatched == 273)
        #expect(page.members == 2)
        #expect(page.skipped == 0)
        #expect(page.parcels.count == 2)
    }

    @Test func aSkippedMemberStillCountsTowardsAFullPage() throws {
        // Three members, one without a polygon: the page is full, though only two parcels came out.
        let data = Self.page(
            [Self.member(1, geometry: Self.polygon), Self.member(2, geometry: Self.point), Self.member(3, geometry: Self.polygon)],
            attributes: #"numberMatched="10" numberReturned="3""#
        )
        let page = try CadastrePage.decode(from: data)
        #expect(page.parcels.count == 2)
        #expect(page.skipped == 1)
        #expect(CadastrePaging.hasMore(page, startIndex: 0, pageSize: 3))
    }

    @Test func withoutNumberReturnedTheRawMembersCount() throws {
        let data = Self.page(
            [Self.member(1, geometry: Self.polygon), Self.member(2, geometry: Self.point), Self.member(3, geometry: Self.polygon)],
            attributes: ""
        )
        let page = try CadastrePage.decode(from: data)
        #expect(page.numberReturned == nil)
        #expect(page.numberMatched == nil)
        #expect(page.members == 3)
        #expect(CadastrePaging.hasMore(page, startIndex: 0, pageSize: 3))
        #expect(!CadastrePaging.hasMore(page, startIndex: 0, pageSize: 4))
    }

    @Test func aShortPageEndsEvenWithANextLink() throws {
        // Datafordeler sends `next` on the last page too (startIndex past numberMatched), so `next` is not trusted.
        let data = Self.page(
            [Self.member(1, geometry: Self.polygon)],
            attributes: #"next="https://wfs.datafordeler.dk/x?STARTINDEX=275" numberMatched="273" numberReturned="1""#
        )
        let page = try CadastrePage.decode(from: data)
        #expect(!CadastrePaging.hasMore(page, startIndex: 270, pageSize: 5))
    }

    @Test func aFullPageThatReachesNumberMatchedEnds() throws {
        let data = Self.page([Self.member(1, geometry: Self.polygon), Self.member(2, geometry: Self.polygon)],
                             attributes: #"numberMatched="4" numberReturned="2""#)
        let page = try CadastrePage.decode(from: data)
        #expect(CadastrePaging.hasMore(page, startIndex: 0, pageSize: 2))
        #expect(!CadastrePaging.hasMore(page, startIndex: 2, pageSize: 2))
    }

    @Test func numberMatchedUnknownIsIgnored() throws {
        let data = Self.page([Self.member(1, geometry: Self.polygon)], attributes: #"numberMatched="unknown" numberReturned="1""#)
        let page = try CadastrePage.decode(from: data)
        #expect(page.numberMatched == nil)
        #expect(CadastrePaging.hasMore(page, startIndex: 0, pageSize: 1))
    }

    /// GML 3.2 may send a parcel as a Surface of PolygonPatch, not a Polygon.
    @Test func readsASurfaceOfPolygonPatches() throws {
        let surface = """
        <gml:Surface><gml:patches><gml:PolygonPatch>\
        <gml:exterior><gml:LinearRing><gml:posList>10.201 56.161 10.203 56.161 10.203 56.162 10.201 56.161</gml:posList></gml:LinearRing></gml:exterior>\
        <gml:interior><gml:LinearRing><gml:posList>10.2014 56.1612 10.2018 56.1612 10.2018 56.1615 10.2014 56.1612</gml:posList></gml:LinearRing></gml:interior>\
        </gml:PolygonPatch></gml:patches></gml:Surface>
        """
        let data = Self.page([Self.member(7, geometry: surface)], attributes: #"numberReturned="1""#)
        let page = try CadastrePage.decode(from: data)
        #expect(page.skipped == 0)
        let parcel = try #require(page.parcels.parcels.first)
        #expect(parcel.number == "7a")
        #expect(parcel.polygons.count == 1)
        #expect(parcel.polygons[0].count == 2)
        // The plain decode reads it too.
        #expect(try ParcelSet.decodeChecked(from: data).count == 1)
    }

    @Test func theCompactFileCountsItsFeatures() throws {
        let set = ParcelSet(parcels: [Parcel(id: "a", number: "1", district: "", polygons: [[[
            Coordinate(latitude: 56.161, longitude: 10.201), Coordinate(latitude: 56.162, longitude: 10.202),
            Coordinate(latitude: 56.161, longitude: 10.202), Coordinate(latitude: 56.161, longitude: 10.201),
        ]]])])
        let page = try CadastrePage.decode(from: set.geoJSON())
        #expect(page.members == 1)
        #expect(page.parcels.count == 1)
    }
}
