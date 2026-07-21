import Foundation

// MARK: - License

public enum LicenseTier: String, Sendable {
    case personal
    case pro

    public var displayName: String {
        switch self {
        case .personal: return "Personal"
        case .pro: return "Pro"
        }
    }

    public var deviceLimit: String {
        switch self {
        case .personal: return "1 device"
        case .pro: return "Unlimited devices"
        }
    }

    /// Gumroad reports the purchased variant as a string like "(Pro)". Any variant
    /// naming the paid tier maps to `.pro`; everything else is Personal. "Family" is
    /// accepted as a legacy alias so licenses sold under the old name still validate.
    public static func detect(variants: String?) -> LicenseTier {
        let value = (variants ?? "").lowercased()
        return (value.contains("pro") || value.contains("family")) ? .pro : .personal
    }
}

/// Decoded leniently so licenses saved under the old "family" tier still load as Pro.
extension LicenseTier: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self).lowercased()
        switch raw {
        case "pro", "family": self = .pro
        default: self = .personal
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct LicenseInfo: Codable, Equatable, Sendable {
    public var licenseKey: String
    public var email: String
    public var fullName: String?
    public var tier: LicenseTier
    public var productName: String?
    public var purchaseDate: Date?
    public var cardVisual: String?
    public var cardType: String?
    public var orderNumber: Int?
    public var deviceCount: Int

    public init(
        licenseKey: String,
        email: String,
        fullName: String? = nil,
        tier: LicenseTier,
        productName: String? = nil,
        purchaseDate: Date? = nil,
        cardVisual: String? = nil,
        cardType: String? = nil,
        orderNumber: Int? = nil,
        deviceCount: Int = 1
    ) {
        self.licenseKey = licenseKey
        self.email = email
        self.fullName = fullName
        self.tier = tier
        self.productName = productName
        self.purchaseDate = purchaseDate
        self.cardVisual = cardVisual
        self.cardType = cardType
        self.orderNumber = orderNumber
        self.deviceCount = deviceCount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        licenseKey = try c.decode(String.self, forKey: .licenseKey)
        email = try c.decode(String.self, forKey: .email)
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName)
        tier = try c.decode(LicenseTier.self, forKey: .tier)
        productName = try c.decodeIfPresent(String.self, forKey: .productName)
        purchaseDate = try c.decodeIfPresent(Date.self, forKey: .purchaseDate)
        cardVisual = try c.decodeIfPresent(String.self, forKey: .cardVisual)
        cardType = try c.decodeIfPresent(String.self, forKey: .cardType)
        orderNumber = try c.decodeIfPresent(Int.self, forKey: .orderNumber)
        deviceCount = try c.decodeIfPresent(Int.self, forKey: .deviceCount) ?? 1
    }
}

// MARK: - Categories

public enum ListCategory: String, Codable, Sendable, CaseIterable {
    case ads
    case trackers
    case malware
    case privacy
    case adult
    case custom

    public var label: String { rawValue.uppercased() }

    /// The categories offered as filters in the Browse catalog (custom lists never
    /// appear there — they come from user-supplied URLs).
    public static var browsable: [ListCategory] { [.ads, .trackers, .malware, .privacy, .adult] }
}

// MARK: - Installed blocklists

public struct BlocklistSource: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var detail: String?
    public var url: String
    public var category: ListCategory
    public var enabled: Bool
    /// Domains found in this list on its last successful fetch (advertised estimate until then).
    public var domainCount: Int
    public var lastFetched: Date?

    public var isCustom: Bool { category == .custom }

    public init(
        id: String,
        name: String,
        detail: String? = nil,
        url: String,
        category: ListCategory,
        enabled: Bool,
        domainCount: Int = 0,
        lastFetched: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.url = url
        self.category = category
        self.enabled = enabled
        self.domainCount = domainCount
        self.lastFetched = lastFetched
    }

    /// Lenient decoding so configs written before categories/counts existed still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        detail = try c.decodeIfPresent(String.self, forKey: .detail)
        url = try c.decode(String.self, forKey: .url)
        category = try c.decodeIfPresent(ListCategory.self, forKey: .category) ?? .custom
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        domainCount = try c.decodeIfPresent(Int.self, forKey: .domainCount) ?? 0
        lastFetched = try c.decodeIfPresent(Date.self, forKey: .lastFetched)
    }

    public static func custom(id: String = UUID().uuidString, name: String, url: String, host: String?) -> BlocklistSource {
        BlocklistSource(id: id, name: name, detail: host, url: url, category: .custom, enabled: true)
    }
}

public enum DefaultLists {
    /// Seeded on a fresh install so the app isn't empty. Matches the Browse catalog's
    /// stable ids so those entries read as "Added". Counts are advertised estimates
    /// that get replaced by real values after the first fetch.
    public static var seed: [BlocklistSource] {
        Catalog.bundled
            .filter { ["adguard-dns", "stevenblack-unified", "malware-domains", "oisd-small"].contains($0.id) }
            .map { $0.asSource(enabled: true) }
    }
}

// MARK: - App configuration

public struct AppConfig: Codable, Sendable {
    public var sources: [BlocklistSource]
    public var protectionEnabled: Bool
    public var lastUpdated: Date?
    public var blockedCount: Int

    public init(
        sources: [BlocklistSource] = DefaultLists.seed,
        protectionEnabled: Bool = true,
        lastUpdated: Date? = nil,
        blockedCount: Int = 0
    ) {
        self.sources = sources
        self.protectionEnabled = protectionEnabled
        self.lastUpdated = lastUpdated
        self.blockedCount = blockedCount
    }
}
