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
        XCTAssertEqual(LicenseTier.detect(variants: "(Personal)"), .personal)
        XCTAssertEqual(LicenseTier.detect(variants: nil), .personal)
        XCTAssertEqual(LicenseTier.detect(variants: ""), .personal)
    }

    func testTierCodableRoundTrips() throws {
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(LicenseTier.self, from: Data("\"pro\"".utf8)), .pro)
        XCTAssertEqual(try decoder.decode(LicenseTier.self, from: Data("\"personal\"".utf8)), .personal)
    }
}

final class UpdateCheckerTests: XCTestCase {
    func testIsNewerNumericAware() {
        XCTAssertTrue(UpdateChecker.isNewer("1.1.0", than: "1.0.0"))
        XCTAssertTrue(UpdateChecker.isNewer("1.0.10", than: "1.0.9"))  // numeric, not lexical
        XCTAssertTrue(UpdateChecker.isNewer("2.0.0", than: "1.9.9"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0.0", than: "1.0.0"))  // same is not newer
        XCTAssertFalse(UpdateChecker.isNewer("0.9.0", than: "1.0.0"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0.0", than: "dev"))    // dev build never nags
    }

    func testManifestDecodes() throws {
        let json = """
        {"version":"1.2.0","url":"https://updates.hostblock.app/releases/HostBlock-1.2.0.dmg"}
        """
        let m = try JSONDecoder().decode(UpdateManifest.self, from: Data(json.utf8))
        XCTAssertEqual(m.version, "1.2.0")
        XCTAssertNil(m.notes)
    }
}

final class GistURLTests: XCTestCase {
    func testGistPageURLGetsRawSuffix() {
        XCTAssertEqual(
            GistURL.rawified("https://gist.github.com/user/abc123"),
            "https://gist.github.com/user/abc123/raw"
        )
    }

    func testTrailingSlashAndFragmentStripped() {
        XCTAssertEqual(
            GistURL.rawified("https://gist.github.com/user/abc123/"),
            "https://gist.github.com/user/abc123/raw"
        )
        XCTAssertEqual(
            GistURL.rawified("https://gist.github.com/user/abc123#file-hosts-txt"),
            "https://gist.github.com/user/abc123/raw"
        )
    }

    func testAnonymousGist() {
        XCTAssertEqual(
            GistURL.rawified("https://gist.github.com/abc123"),
            "https://gist.github.com/abc123/raw"
        )
    }

    func testAlreadyRawAndNonGistPassThrough() {
        // Already a /raw gist page link.
        XCTAssertEqual(
            GistURL.rawified("https://gist.github.com/user/abc123/raw"),
            "https://gist.github.com/user/abc123/raw"
        )
        // Already the raw content host.
        let raw = "https://gist.githubusercontent.com/user/abc123/raw/x/hosts.txt"
        XCTAssertEqual(GistURL.rawified(raw), raw)
        // A revision/file path, left alone.
        let deep = "https://gist.github.com/user/abc123/raw/abc/hosts.txt"
        XCTAssertEqual(GistURL.rawified(deep), deep)
        // Not a gist at all.
        let other = "https://big.oisd.nl/domainswild2"
        XCTAssertEqual(GistURL.rawified(other), other)
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
        XCTAssertEqual(source.domainCount, 0)
        XCTAssertNil(source.lastFetched)
        XCTAssertTrue(source.enabled)
    }

    func testCatalogEntryDecodesAndConvertsToSource() throws {
        // Older/extra keys (category, featured) are tolerated and ignored.
        let json = """
        [{"id":"easylist","name":"EasyList","description":"Ads.",
          "url":"https://easylist.to/easylist/easylist.txt","category":"ads",
          "domainCount":84000,"featured":true}]
        """
        let entries = try JSONDecoder().decode([CatalogEntry].self, from: Data(json.utf8))
        XCTAssertEqual(entries.count, 1)
        let source = entries[0].asSource(enabled: true)
        XCTAssertEqual(source.domainCount, 84000)
        XCTAssertEqual(source.detail, "easylist.to")
    }

    /// Guards the JSON resource: if catalog-fallback.json is unbundled or malformed,
    /// `Catalog.bundled` returns empty and this fails loudly rather than shipping broken.
    /// The resource is synced from site/public/catalog.json, so a list added there and
    /// not reflected here trips this too.
    func testBundledCatalogLoadsFromResource() {
        XCTAssertEqual(Catalog.bundled.count, 2)
        XCTAssertTrue(Catalog.bundled.contains { $0.id == "stevenblack-unified" && $0.enabledByDefault })
    }

    func testCatalogDecodesWrapperShape() throws {
        let json = """
        {"lists":[{"id":"x","name":"X","url":"https://x.example/list.txt","category":"ads","domainCount":1}]}
        """
        let entries = try Catalog.decode(Data(json.utf8))
        XCTAssertEqual(entries.first?.id, "x")
    }
}

final class HostsBuilderTests: XCTestCase {
    func testBuildsDedupedSortedStagingFromCache() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cacheDir = tmp.appendingPathComponent("cache")
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        try "b.example.com\na.example.com\n".write(to: cacheDir.appendingPathComponent("l1.txt"), atomically: true, encoding: .utf8)
        try "b.example.com\nc.example.com\n".write(to: cacheDir.appendingPathComponent("l2.txt"), atomically: true, encoding: .utf8)

        let staging = tmp.appendingPathComponent("hosts_block.txt")
        let builder = HostsBuilder(cacheDir: cacheDir, stagingURL: staging)
        let result = await builder.build(
            lists: [
                .init(id: "l1", name: "L1", url: "https://example.test/l1"),
                .init(id: "l2", name: "L2", url: "https://example.test/l2"),
            ],
            forceRefresh: false
        )

        XCTAssertTrue(result.wroteStaging)
        XCTAssertEqual(result.total, 3)             // a, b, c with b deduped across lists
        XCTAssertEqual(result.counts["l1"], 2)
        XCTAssertEqual(result.counts["l2"], 2)
        XCTAssertTrue(result.failedIDs.isEmpty)
        let written = try String(contentsOf: staging, encoding: .utf8)
        XCTAssertEqual(written, "0.0.0.0 a.example.com\n0.0.0.0 b.example.com\n0.0.0.0 c.example.com\n")
    }

    func testForcedRefreshFlagsFailedDownloadButKeepsCache() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cacheDir = tmp.appendingPathComponent("cache")
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // A cached list whose URL can't resolve: a forced refresh must fail to
        // download but still fall back to the cache, and report the failure.
        try "a.example.com\n".write(to: cacheDir.appendingPathComponent("l1.txt"), atomically: true, encoding: .utf8)
        let builder = HostsBuilder(cacheDir: cacheDir, stagingURL: tmp.appendingPathComponent("hosts_block.txt"))
        let result = await builder.build(
            lists: [.init(id: "l1", name: "L1", url: "https://no-such-host.invalid/list.txt")],
            forceRefresh: true
        )

        XCTAssertTrue(result.failedIDs.contains("l1"))  // download failed
        XCTAssertEqual(result.counts["l1"], 1)          // but stale cache still used
        XCTAssertEqual(result.total, 1)
    }
}
