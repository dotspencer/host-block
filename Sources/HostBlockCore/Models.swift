import Foundation

// MARK: - License

public enum LicenseTier: String, Codable, Sendable {
    case personal
    case family

    public var displayName: String {
        switch self {
        case .personal: return "Personal"
        case .family: return "Family"
        }
    }

    public var deviceLimitDescription: String {
        switch self {
        case .personal: return "1 device"
        case .family: return "Unlimited devices"
        }
    }

    /// Gumroad reports the purchased variant as a string like "(Family)". A single
    /// product with a "Family" variant maps to the family tier; everything else is personal.
    public static func detect(variants: String?) -> LicenseTier {
        (variants ?? "").lowercased().contains("family") ? .family : .personal
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

    public init(
        licenseKey: String,
        email: String,
        fullName: String? = nil,
        tier: LicenseTier,
        productName: String? = nil,
        purchaseDate: Date? = nil,
        cardVisual: String? = nil,
        cardType: String? = nil,
        orderNumber: Int? = nil
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
    }
}

// MARK: - Blocklists

public struct BlocklistSource: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var detail: String?
    public var url: String
    public var isBuiltIn: Bool
    public var enabled: Bool

    public init(id: String, name: String, detail: String? = nil, url: String, isBuiltIn: Bool, enabled: Bool) {
        self.id = id
        self.name = name
        self.detail = detail
        self.url = url
        self.isBuiltIn = isBuiltIn
        self.enabled = enabled
    }
}

public enum BuiltinLists {
    public static let oisd = BlocklistSource(
        id: "oisd-big",
        name: "oisd · Ads, Malware, Tracking",
        detail: "big.oisd.nl",
        url: "https://big.oisd.nl/domainswild2",
        isBuiltIn: true,
        enabled: true
    )

    public static let oisdNSFW = BlocklistSource(
        id: "oisd-nsfw",
        name: "oisd · NSFW",
        detail: "nsfw.oisd.nl",
        url: "https://nsfw.oisd.nl/domainswild2",
        isBuiltIn: true,
        enabled: false
    )

    public static var all: [BlocklistSource] { [oisd, oisdNSFW] }
}

// MARK: - App configuration

public struct AppConfig: Codable, Sendable {
    public var sources: [BlocklistSource]
    public var protectionEnabled: Bool
    public var lastUpdated: Date?
    public var blockedCount: Int

    public init(
        sources: [BlocklistSource] = BuiltinLists.all,
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
