import Foundation

/// One entry in the curated Browse catalog.
public struct CatalogEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var description: String
    public var url: String
    public var category: ListCategory
    /// Advertised domain count, shown until the list is added and fetched for real.
    public var domainCount: Int
    public var featured: Bool

    public init(
        id: String,
        name: String,
        description: String,
        url: String,
        category: ListCategory,
        domainCount: Int,
        featured: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.url = url
        self.category = category
        self.domainCount = domainCount
        self.featured = featured
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        url = try c.decode(String.self, forKey: .url)
        category = try c.decodeIfPresent(ListCategory.self, forKey: .category) ?? .privacy
        domainCount = try c.decodeIfPresent(Int.self, forKey: .domainCount) ?? 0
        featured = try c.decodeIfPresent(Bool.self, forKey: .featured) ?? false
    }

    public func asSource(enabled: Bool) -> BlocklistSource {
        BlocklistSource(
            id: id,
            name: name,
            detail: URL(string: url)?.host,
            url: url,
            category: category,
            enabled: enabled,
            domainCount: domainCount
        )
    }
}

public enum Catalog {
    /// Bundled fallback catalog: used before the remote catalog loads, and whenever
    /// it can't be reached. The four ids referenced by `DefaultLists.seed` live here.
    public static let bundled: [CatalogEntry] = [
        CatalogEntry(
            id: "adguard-dns",
            name: "AdGuard DNS",
            description: "Blocks ads and trackers using the AdGuard DNS filter.",
            url: "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt",
            category: .ads,
            domainCount: 48_000
        ),
        CatalogEntry(
            id: "stevenblack-unified",
            name: "StevenBlack Unified",
            description: "Unified hosts file consolidating ad, malware, and tracker sources.",
            url: "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
            category: .trackers,
            domainCount: 123_000
        ),
        CatalogEntry(
            id: "malware-domains",
            name: "Malware Domain List",
            description: "Known malware, phishing, and command-and-control domains.",
            url: "https://urlhaus.abuse.ch/downloads/hostfile/",
            category: .malware,
            domainCount: 19_000
        ),
        CatalogEntry(
            id: "oisd-small",
            name: "OISD Small",
            description: "Lightweight list blocking ads, trackers, and telemetry.",
            url: "https://small.oisd.nl/domainswild2",
            category: .privacy,
            domainCount: 56_000
        ),
        CatalogEntry(
            id: "easylist",
            name: "EasyList",
            description: "The primary filter list that removes most adverts from web pages.",
            url: "https://easylist.to/easylist/easylist.txt",
            category: .ads,
            domainCount: 84_000,
            featured: true
        ),
        CatalogEntry(
            id: "easyprivacy",
            name: "EasyPrivacy",
            description: "Removes all forms of tracking from the internet.",
            url: "https://easylist.to/easylist/easyprivacy.txt",
            category: .trackers,
            domainCount: 21_000,
            featured: true
        ),
        CatalogEntry(
            id: "oisd-full",
            name: "OISD Full",
            description: "Comprehensive blocklist covering ads, trackers, malware, and telemetry.",
            url: "https://big.oisd.nl/domainswild2",
            category: .privacy,
            domainCount: 201_000,
            featured: true
        ),
        CatalogEntry(
            id: "phishing-army",
            name: "Phishing Army",
            description: "Block phishing and fraud websites.",
            url: "https://phishing.army/download/phishing_army_blocklist_extended.txt",
            category: .malware,
            domainCount: 62_000,
            featured: true
        ),
    ]
}

public struct CatalogFetcher: Sendable {
    public let url: URL?

    public init(urlString: String) {
        self.url = URL(string: urlString)
    }

    /// Fetches and decodes the remote catalog. Accepts either a bare JSON array of
    /// entries or an object wrapping them under a `lists` key.
    public func fetch() async throws -> [CatalogEntry] {
        guard let url else { throw FetchError.badURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("HostBlock/1.0 (macOS)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FetchError.httpStatus(http.statusCode)
        }
        let decoder = JSONDecoder()
        if let entries = try? decoder.decode([CatalogEntry].self, from: data) {
            return entries
        }
        return try decoder.decode(CatalogWrapper.self, from: data).lists
    }

    private struct CatalogWrapper: Decodable {
        let lists: [CatalogEntry]
    }
}
