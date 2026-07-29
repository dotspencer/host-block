import Foundation

public enum FetchError: LocalizedError {
    case badURL
    case httpStatus(Int)
    case notText
    case empty

    public var errorDescription: String? {
        switch self {
        case .badURL: return "The list URL is not valid."
        case .httpStatus(let code): return "The server responded with HTTP \(code)."
        case .notText: return "The list is not plain text."
        case .empty: return "No domains were found in the list."
        }
    }
}

public struct BlocklistFetcher: Sendable {
    public init() {}

    /// Downloads a blocklist and returns its parsed, deduplicated domains.
    public func download(_ source: BlocklistSource) async throws -> [String] {
        guard let url = URL(string: source.url) else { throw FetchError.badURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 90
        request.setValue("HostBlock/1.0 (macOS)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FetchError.httpStatus(http.statusCode)
        }
        guard let text = String(data: data, encoding: .utf8) else { throw FetchError.notText }
        let domains = DomainParser.domains(in: text)
        guard !domains.isEmpty else { throw FetchError.empty }
        return domains
    }
}
