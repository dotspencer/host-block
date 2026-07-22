import Foundation

/// One built-in "default" list. The catalog defines the set every user always has.
public struct CatalogEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var description: String
    public var url: String
    /// Advertised domain count, shown until the list is fetched for real.
    public var domainCount: Int
    /// Whether this list is on by default when it first appears for a user.
    public var enabledByDefault: Bool

    public init(id: String, name: String, description: String, url: String, domainCount: Int, enabledByDefault: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.url = url
        self.domainCount = domainCount
        self.enabledByDefault = enabledByDefault
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        url = try c.decode(String.self, forKey: .url)
        domainCount = try c.decodeIfPresent(Int.self, forKey: .domainCount) ?? 0
        enabledByDefault = try c.decodeIfPresent(Bool.self, forKey: .enabledByDefault) ?? false
    }

    public func asSource(enabled: Bool) -> BlocklistSource {
        BlocklistSource(
            id: id,
            name: name,
            detail: URL(string: url)?.host,
            url: url,
            enabled: enabled,
            isCustom: false,
            domainCount: domainCount
        )
    }
}

public enum Catalog {
    static let fallbackResource = "catalog-fallback"

    /// Bundled fallback catalog loaded from `Resources/catalog-fallback.json`: used
    /// before the remote catalog loads, and whenever it can't be reached. Edit the
    /// JSON to change the shipped fallback — no code change needed. The ids referenced
    /// by `DefaultLists.seed` must exist here; `CatalogTests` enforces that.
    public static let bundled: [CatalogEntry] = {
        guard
            let url = Bundle.module.url(forResource: fallbackResource, withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let entries = try? decode(data)
        else {
            assertionFailure("Bundled catalog-fallback.json is missing or malformed")
            return []
        }
        return entries
    }()

    /// Decodes catalog JSON in either shape: a bare array of entries, or an object
    /// wrapping them under a `lists` key. Shared by the bundled file and remote fetch.
    static func decode(_ data: Data) throws -> [CatalogEntry] {
        let decoder = JSONDecoder()
        if let entries = try? decoder.decode([CatalogEntry].self, from: data) {
            return entries
        }
        return try decoder.decode(CatalogWrapper.self, from: data).lists
    }

    struct CatalogWrapper: Decodable {
        let lists: [CatalogEntry]
    }
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
        return try Catalog.decode(data)
    }
}
