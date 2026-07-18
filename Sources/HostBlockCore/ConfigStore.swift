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

    // MARK: Blocklist caches (one plain-text domain per line)

    private func cacheURL(sourceID: String) -> URL {
        cacheDir.appendingPathComponent("\(sourceID).txt")
    }

    public func readCache(sourceID: String) -> [String]? {
        guard let text = try? String(contentsOf: cacheURL(sourceID: sourceID), encoding: .utf8) else { return nil }
        let domains = text.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        return domains.isEmpty ? nil : domains
    }

    public func writeCache(sourceID: String, domains: [String]) {
        let text = domains.joined(separator: "\n") + "\n"
        try? text.write(to: cacheURL(sourceID: sourceID), atomically: true, encoding: .utf8)
    }

    public func deleteCache(sourceID: String) {
        try? FileManager.default.removeItem(at: cacheURL(sourceID: sourceID))
    }
}
