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
        XCTAssertEqual(LicenseTier.detect(variants: "(Family)"), .family)
        XCTAssertEqual(LicenseTier.detect(variants: "Family License"), .family)
        XCTAssertEqual(LicenseTier.detect(variants: "(Personal)"), .personal)
        XCTAssertEqual(LicenseTier.detect(variants: nil), .personal)
        XCTAssertEqual(LicenseTier.detect(variants: ""), .personal)
    }
}
