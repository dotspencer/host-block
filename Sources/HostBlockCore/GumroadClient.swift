import Foundation

public enum GumroadError: LocalizedError, Equatable {
    case notConfigured
    case invalidKey(String)
    case refunded
    case deviceLimitReached
    case badResponse

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "This build isn't configured with a Gumroad product ID yet."
        case .invalidKey(let message):
            return message.isEmpty ? "That license key isn't valid." : message
        case .refunded:
            return "This license was refunded or disputed and is no longer valid."
        case .deviceLimitReached:
            return "This Personal license is already active on another device. Upgrade to a Family license for unlimited devices."
        case .badResponse:
            return "Couldn't understand the response from Gumroad. Try again."
        }
    }
}

public struct GumroadClient: Sendable {
    public let productID: String

    public init(productID: String) {
        self.productID = productID
    }

    public struct VerificationResult: Sendable {
        public let info: LicenseInfo
        public let uses: Int
    }

    /// Verifies a license key against the Gumroad license API.
    /// `incrementUses` should be true only for first-time activation so the
    /// uses count can act as a device counter for Personal licenses.
    public func verify(licenseKey: String, incrementUses: Bool) async throws -> VerificationResult {
        guard !productID.isEmpty, !productID.hasPrefix("YOUR_") else { throw GumroadError.notConfigured }

        var request = URLRequest(url: URL(string: "https://api.gumroad.com/v2/licenses/verify")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let params = [
            "product_id": productID,
            "license_key": licenseKey,
            "increment_uses_count": incrementUses ? "true" : "false",
        ]
        request.httpBody = params
            .map { "\($0.key)=\(Self.formEncode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let response = try? JSONDecoder().decode(VerifyResponse.self, from: data) else {
            throw GumroadError.badResponse
        }
        guard response.success == true, let purchase = response.purchase else {
            throw GumroadError.invalidKey(response.message ?? "That license key isn't valid.")
        }
        if purchase.refunded == true || purchase.disputed == true || purchase.chargebacked == true {
            throw GumroadError.refunded
        }

        let info = LicenseInfo(
            licenseKey: licenseKey,
            email: purchase.email ?? "unknown",
            fullName: purchase.full_name,
            tier: LicenseTier.detect(variants: purchase.variants),
            productName: purchase.product_name,
            purchaseDate: purchase.sale_timestamp.flatMap { Self.parseDate($0) },
            cardVisual: purchase.card?.visual,
            cardType: purchase.card?.type,
            orderNumber: purchase.order_number
        )
        return VerificationResult(info: info, uses: response.uses ?? 1)
    }

    static func formEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
    }

    static func parseDate(_ string: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        return plain.date(from: string)
    }

    struct VerifyResponse: Decodable {
        let success: Bool?
        let uses: Int?
        let message: String?
        let purchase: Purchase?

        struct Purchase: Decodable {
            let email: String?
            let full_name: String?
            let product_name: String?
            let variants: String?
            let sale_timestamp: String?
            let order_number: Int?
            let refunded: Bool?
            let disputed: Bool?
            let chargebacked: Bool?
            let card: Card?

            struct Card: Decodable {
                let visual: String?
                let type: String?
            }
        }
    }
}
