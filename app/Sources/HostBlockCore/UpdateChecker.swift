import Foundation

/// A release advertised by the update feed (`latest.json`, hosted on R2).
public struct UpdateManifest: Decodable, Sendable {
    public let version: String
    /// Where the "Update" affordance sends the user — the DMG, or a download page.
    public let url: String
    public let notes: String?
}

/// Best-effort "is there a newer version?" check. Fetches the feed, compares its
/// version to the running app, and returns a manifest only when the feed advertises
/// something strictly newer. Every failure path (bad URL, offline, non-200, malformed
/// JSON, same/older version) returns nil — the check never blocks or errors the UI.
public struct UpdateChecker: Sendable {
    private let feedURL: String
    private let currentVersion: String

    public init(feedURL: String, currentVersion: String) {
        self.feedURL = feedURL
        self.currentVersion = currentVersion
    }

    public func check() async -> UpdateManifest? {
        guard let url = URL(string: feedURL) else { return nil }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let manifest = try JSONDecoder().decode(UpdateManifest.self, from: data)
            guard URL(string: manifest.url) != nil,
                  Self.isNewer(manifest.version, than: currentVersion) else { return nil }
            return manifest
        } catch {
            return nil
        }
    }

    /// Numeric-aware dotted-version comparison ("1.0.10" > "1.0.9"). Sufficient for the
    /// plain `x.y.z` versions we ship; no pre-release or build-metadata handling.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        candidate.compare(current, options: .numeric) == .orderedDescending
    }
}
