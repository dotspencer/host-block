import Foundation

/// Persists app configuration, the activated license, downloaded blocklist caches,
/// and the staged hosts block under ~/Library/Application Support/HostBlock.
public struct ConfigStore {
    public let baseDir: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(baseDir: URL? = nil) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.baseDir = baseDir ?? appSupport.appendingPathComponent("HostBlock", isDirectory: true)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder = enc
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        decoder = dec
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    public var cacheDir: URL { baseDir.appendingPathComponent("cache", isDirectory: true) }
    public var stagingFileURL: URL { baseDir.appendingPathComponent("hosts_block.txt") }
    private var configURL: URL { baseDir.appendingPathComponent("config.json") }
    private var licenseURL: URL { baseDir.appendingPathComponent("license.json") }
    private var catalogURL: URL { baseDir.appendingPathComponent("catalog.json") }

    // MARK: Config

    public func loadConfig() -> AppConfig? {
        guard let data = try? Data(contentsOf: configURL) else { return nil }
        return try? decoder.decode(AppConfig.self, from: data)
    }

    public func saveConfig(_ config: AppConfig) {
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: configURL, options: .atomic)
    }

    // MARK: License

    public func loadLicense() -> LicenseInfo? {
        guard let data = try? Data(contentsOf: licenseURL) else { return nil }
        return try? decoder.decode(LicenseInfo.self, from: data)
    }

    public func saveLicense(_ license: LicenseInfo) {
        guard let data = try? encoder.encode(license) else { return }
        try? data.write(to: licenseURL, options: .atomic)
    }

    public func deleteLicense() {
        try? FileManager.default.removeItem(at: licenseURL)
    }

    // MARK: Catalog cache

    public func loadCatalog() -> [CatalogEntry]? {
        guard let data = try? Data(contentsOf: catalogURL) else { return nil }
        return try? decoder.decode([CatalogEntry].self, from: data)
    }

    public func saveCatalog(_ catalog: [CatalogEntry]) {
        guard let data = try? encoder.encode(catalog) else { return }
        try? data.write(to: catalogURL, options: .atomic)
    }

    // MARK: Blocklist cache (written/read by HostsBuilder; deleted here on removal)

    public func deleteCache(sourceID: String) {
        try? FileManager.default.removeItem(at: cacheDir.appendingPathComponent("\(sourceID).txt"))
    }
}
