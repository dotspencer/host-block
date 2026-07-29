import Foundation

/// Extracts bare domains from blocklists in common formats: plain domain lists,
/// hosts files ("0.0.0.0 domain"), wildcard lists ("*.domain"), and Adblock-style
/// filters ("||domain^"). Everything that doesn't reduce to a valid domain is dropped.
public enum DomainParser {

    /// Domains that must never be blocked via /etc/hosts.
    static let excludedHostnames: Set<String> = [
        "localhost", "localhost.localdomain", "local",
        "broadcasthost", "ip6-localhost", "ip6-loopback",
        "ip6-localnet", "ip6-mcastprefix", "ip6-allnodes",
        "ip6-allrouters", "ip6-allhosts",
    ]

    /// Parses a whole blocklist into a sorted, deduplicated set of domains.
    public static func domains(in text: String) -> [String] {
        var result = Set<String>()
        for line in text.split(omittingEmptySubsequences: true, whereSeparator: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }) {
            if let domain = domain(fromLine: String(line)) {
                result.insert(domain)
            }
        }
        return result.sorted()
    }

    /// Reduces a single blocklist line to a domain, or nil if the line carries none.
    public static func domain(fromLine rawLine: String) -> String? {
        var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }
        if line.hasPrefix("#") || line.hasPrefix("!") { return nil }

        if let hash = line.firstIndex(of: "#") {
            // An inline comment needs whitespace before the '#'; a bare '#' mid-token
            // is an Adblock element-hiding rule (example.com##.ad), which carries no domain.
            let before = line[line.startIndex..<hash]
            guard let last = before.last, last == " " || last == "\t" else { return nil }
            line = String(before).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { return nil }
        }

        // Adblock-style: ||domain^ (drop everything at or after ^; reject rules with paths)
        if line.hasPrefix("||") {
            line = String(line.dropFirst(2))
            if let caret = line.firstIndex(of: "^") {
                line = String(line[..<caret])
            }
            if line.contains("/") { return nil }
        }

        let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard let first = parts.first else { return nil }

        var candidate: String
        if parts.count >= 2, isIPv4(String(first)) || first.contains(":") {
            // hosts-file format: "<ip> domain [aliases...]" — take the first hostname
            candidate = String(parts[1])
        } else {
            candidate = String(first)
        }

        if candidate.hasPrefix("*.") { candidate = String(candidate.dropFirst(2)) }
        candidate = candidate.lowercased()
        while candidate.hasSuffix(".") { candidate.removeLast() }

        guard !isIPv4(candidate), !candidate.contains(":") else { return nil }
        guard isValidDomain(candidate) else { return nil }
        guard !excludedHostnames.contains(candidate) else { return nil }
        return candidate
    }

    static func isIPv4(_ string: String) -> Bool {
        let octets = string.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return false }
        for octet in octets {
            guard let value = Int(octet), (0...255).contains(value), octet.count <= 3 else { return false }
        }
        return true
    }

    static func isValidDomain(_ string: String) -> Bool {
        guard string.count >= 3, string.count <= 253, string.contains(".") else { return false }
        let labels = string.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        for label in labels {
            guard !label.isEmpty, label.count <= 63 else { return false }
            guard label.first != "-", label.last != "-" else { return false }
            for scalar in label.unicodeScalars {
                switch scalar {
                case "a"..."z", "0"..."9", "-", "_":
                    continue
                default:
                    return false
                }
            }
        }
        // TLD sanity: at least 2 chars and not purely numeric (rules out stray IPs)
        guard let tld = labels.last, tld.count >= 2, !tld.allSatisfy({ $0.isNumber }) else { return false }
        return true
    }

    /// Formats domains as strict hosts-file lines: "0.0.0.0 domain", one per line.
    public static func hostsLines(for domains: [String]) -> String {
        guard !domains.isEmpty else { return "" }
        return domains.map { "0.0.0.0 \($0)" }.joined(separator: "\n") + "\n"
    }
}
