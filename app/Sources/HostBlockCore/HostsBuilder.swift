import Foundation

/// Assembles the deduplicated, sorted domain set from the enabled lists (from cache
/// or a fresh download) and writes the staging hosts file. `Sendable` so the whole
/// heavy pipeline — multi-megabyte cache reads, the set union, the sort, and the file
/// write — can run off the main actor, keeping the UI responsive while a toggle
/// applies.
public struct HostsBuilder: Sendable {
    public struct List: Sendable {
        public let id: String
        public let name: String
        public let url: String
        public init(id: String, name: String, url: String) {
            self.id = id
            self.name = name
            self.url = url
        }
    }

    public struct Result: Sendable {
        public let counts: [String: Int]
        public let total: Int
        public let errors: [String]
        public let wroteStaging: Bool
    }

    private let cacheDir: URL
    private let stagingURL: URL
    private let fetcher = BlocklistFetcher()

    public init(cacheDir: URL, stagingURL: URL) {
        self.cacheDir = cacheDir
        self.stagingURL = stagingURL
    }

    public func build(lists: [List], forceRefresh: Bool) async -> Result {
        var all = Set<String>()
        var counts: [String: Int] = [:]
        var errors: [String] = []
        for list in lists {
            do {
                let domains = try await domains(for: list, forceRefresh: forceRefresh)
                all.formUnion(domains)
                counts[list.id] = domains.count
            } catch {
                errors.append("\(list.name): \(error.localizedDescription)")
            }
        }
        let sorted = all.sorted()
        let wrote = (try? DomainParser.hostsLines(for: sorted)
            .write(to: stagingURL, atomically: true, encoding: .utf8)) != nil
        return Result(counts: counts, total: sorted.count, errors: errors, wroteStaging: wrote)
    }

    private func domains(for list: List, forceRefresh: Bool) async throws -> [String] {
        if !forceRefresh, let cached = readCache(list.id) { return cached }
        do {
            let source = BlocklistSource(id: list.id, name: list.name, url: list.url, enabled: true)
            let domains = try await fetcher.download(source)
            writeCache(list.id, domains)
            return domains
        } catch {
            // Fall back to a stale cache if the download fails.
            if let cached = readCache(list.id) { return cached }
            throw error
        }
    }

    private func cacheURL(_ id: String) -> URL { cacheDir.appendingPathComponent("\(id).txt") }

    private func readCache(_ id: String) -> [String]? {
        guard let text = try? String(contentsOf: cacheURL(id), encoding: .utf8) else { return nil }
        let domains = text.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        return domains.isEmpty ? nil : domains
    }

    private func writeCache(_ id: String, _ domains: [String]) {
        let text = domains.joined(separator: "\n") + "\n"
        try? text.write(to: cacheURL(id), atomically: true, encoding: .utf8)
    }
}
