import XCTest
@testable import HostBlockCore

final class DomainParserTests: XCTestCase {

    func testPlainDomainList() {
        let input = """
        example.com
        Ads.Tracker.NET
        sub.domain.co.uk
        """
        XCTAssertEqual(
            DomainParser.domains(in: input),
            ["ads.tracker.net", "example.com", "sub.domain.co.uk"]
        )
    }

    func testHostsFileFormat() {
        let input = """
        0.0.0.0 blocked.example.com
        127.0.0.1 other.example.net
        0.0.0.0\ttabbed.example.org
        ::1 v6.example.io
        """
        XCTAssertEqual(
            DomainParser.domains(in: input),
            ["blocked.example.com", "other.example.net", "tabbed.example.org", "v6.example.io"]
        )
    }

    func testWildcardAndAdblockFormats() {
        let input = """
        *.wild.example.com
        ||abp.example.com^
        ||abp-path.example.com/ads^
        @@||allowlisted.example.com^
        example.com##.ad-banner
        """
        XCTAssertEqual(
            DomainParser.domains(in: input),
            ["abp.example.com", "wild.example.com"]
        )
    }

    func testCommentsAndBlanksAreSkipped() {
        let input = """
        # a comment
        ! adblock comment

        real.example.com # trailing comment
        """
        XCTAssertEqual(DomainParser.domains(in: input), ["real.example.com"])
    }

    func testDeduplicationIsCaseInsensitive() {
        let input = """
        Dup.Example.com
        dup.example.COM
        0.0.0.0 dup.example.com
        """
        XCTAssertEqual(DomainParser.domains(in: input), ["dup.example.com"])
    }

    func testGarbageAndUnsafeEntriesAreRejected() {
        let input = """
        localhost
        127.0.0.1 localhost
        0.0.0.0 broadcasthost
        not_a_domain
        192.168.1.1
        0.0.0.0 10.0.0.1
        http://example.com/path
        -leading.example.com
        trailing-.example.com
        """
        XCTAssertEqual(DomainParser.domains(in: input), [])
    }

    func testHostsLinesFormatting() {
        XCTAssertEqual(
            DomainParser.hostsLines(for: ["a.example.com", "b.example.net"]),
            "0.0.0.0 a.example.com\n0.0.0.0 b.example.net\n"
        )
        XCTAssertEqual(DomainParser.hostsLines(for: []), "")
    }

    func testTrailingDotAndCRLF() {
        let input = "dotted.example.com.\r\ncrlf.example.com\r\n"
        XCTAssertEqual(
            DomainParser.domains(in: input),
            ["crlf.example.com", "dotted.example.com"]
        )
    }
}

final class LicenseTierTests: XCTestCase {
    func testTierDetection() {
        XCTAssertEqual(LicenseTier.detect(variants: "(Pro)"), .pro)
        XCTAssertEqual(LicenseTier.detect(variants: "Pro License"), .pro)
        // "Family" is accepted as a legacy alias for the paid tier.
        XCTAssertEqual(LicenseTier.detect(variants: "(Family)"), .pro)
        XCTAssertEqual(LicenseTier.detect(variants: "(Personal)"), .personal)
        XCTAssertEqual(LicenseTier.detect(variants: nil), .personal)
        XCTAssertEqual(LicenseTier.detect(variants: ""), .personal)
    }

    func testTierDecodesLegacyFamily() throws {
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(LicenseTier.self, from: Data("\"family\"".utf8)), .pro)
        XCTAssertEqual(try decoder.decode(LicenseTier.self, from: Data("\"pro\"".utf8)), .pro)
        XCTAssertEqual(try decoder.decode(LicenseTier.self, from: Data("\"personal\"".utf8)), .personal)
    }
}

final class ModelDecodingTests: XCTestCase {
    /// A config written by the pre-redesign app (isBuiltIn, no category/counts) must
    /// still decode, defaulting missing fields rather than throwing.
    func testLegacyBlocklistSourceDecodes() throws {
        let json = """
        {"id":"oisd-big","name":"oisd","detail":"big.oisd.nl",
         "url":"https://big.oisd.nl/domainswild2","isBuiltIn":true,"enabled":true}
        """
        let source = try JSONDecoder().decode(BlocklistSource.self, from: Data(json.utf8))
        XCTAssertEqual(source.id, "oisd-big")
        XCTAssertEqual(source.category, .custom)
        XCTAssertEqual(source.domainCount, 0)
        XCTAssertNil(source.lastFetched)
        XCTAssertTrue(source.enabled)
    }

    func testCatalogEntryDecodesAndConvertsToSource() throws {
        let json = """
        [{"id":"easylist","name":"EasyList","description":"Ads.",
          "url":"https://easylist.to/easylist/easylist.txt","category":"ads",
          "domainCount":84000,"featured":true}]
        """
        let entries = try JSONDecoder().decode([CatalogEntry].self, from: Data(json.utf8))
        XCTAssertEqual(entries.count, 1)
        let source = entries[0].asSource(enabled: true)
        XCTAssertEqual(source.category, .ads)
        XCTAssertEqual(source.domainCount, 84000)
        XCTAssertEqual(source.detail, "easylist.to")
    }

    func testBundledCatalogCoversSeedIDs() {
        let catalogIDs = Set(Catalog.bundled.map(\.id))
        for source in DefaultLists.seed {
            XCTAssertTrue(catalogIDs.contains(source.id), "seed \(source.id) missing from catalog")
        }
    }

    /// Guards the JSON resource: if catalog-fallback.json is unbundled or malformed,
    /// `Catalog.bundled` returns empty and this fails loudly rather than shipping broken.
    func testBundledCatalogLoadsFromResource() {
        XCTAssertEqual(Catalog.bundled.count, 5)
        XCTAssertTrue(Catalog.bundled.contains { $0.id == "oisd-big" && $0.featured })
    }

    func testCatalogDecodesWrapperShape() throws {
        let json = """
        {"lists":[{"id":"x","name":"X","url":"https://x.example/list.txt","category":"ads","domainCount":1}]}
        """
        let entries = try Catalog.decode(Data(json.utf8))
        XCTAssertEqual(entries.first?.id, "x")
    }
}
