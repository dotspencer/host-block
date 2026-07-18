import AppKit
import Foundation
import HostBlockCore
import ServiceManagement
import SwiftUI

enum AppConstants {
    /// Gumroad product ID from the product's edit page (Settings → Advanced,
    /// or the `product_id` shown in the license key section).
    static let gumroadProductID = "YOUR_GUMROAD_PRODUCT_ID"
    static let purchaseURL = URL(string: "https://gumroad.com")! // TODO: your product page
    static let appVersion = "1.0.0"
    static let refreshInterval: TimeInterval = 24 * 60 * 60
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published private(set) var license: LicenseInfo?
    @Published private(set) var sources: [BlocklistSource] = BuiltinLists.all
    @Published private(set) var protectionEnabled = true
    @Published private(set) var helperInstalled = false
    @Published private(set) var isWorking = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var blockedCount = 0
    @Published private(set) var lastError: String?
    @Published private(set) var launchAtLogin = false
    @Published private(set) var isActivating = false
    @Published var activationError: String?

    private let store = ConfigStore()
    private let fetcher = BlocklistFetcher()
    private let helper = PrivilegedHelper()
    private let gumroad = GumroadClient(productID: AppConstants.gumroadProductID)
    private var refreshTimer: Timer?
    private var bootstrapped = false

    // MARK: Startup

    func bootstrap() {
        guard !bootstrapped else { return }
        bootstrapped = true

        if let config = store.loadConfig() {
            sources = Self.mergeBuiltins(into: config.sources)
            protectionEnabled = config.protectionEnabled
            lastUpdated = config.lastUpdated
            blockedCount = config.blockedCount
        }
        license = store.loadLicense()
        helperInstalled = helper.isInstalled
        launchAtLogin = SMAppService.mainApp.status == .enabled

        if license == nil {
            WindowManager.shared.showActivation()
        } else {
            Task { await self.revalidateLicense() }
            refreshIfStale()
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { _ in
            Task { @MainActor in AppState.shared.refreshIfStale() }
        }
    }

    /// Built-ins always exist and track the app's current names/URLs; only the
    /// user's enabled/disabled choice is preserved across launches.
    private static func mergeBuiltins(into saved: [BlocklistSource]) -> [BlocklistSource] {
        var result: [BlocklistSource] = []
        for builtin in BuiltinLists.all {
            var source = builtin
            if let existing = saved.first(where: { $0.id == builtin.id }) {
                source.enabled = existing.enabled
            }
            result.append(source)
        }
        result.append(contentsOf: saved.filter { !$0.isBuiltIn })
        return result
    }

    private func saveConfig() {
        store.saveConfig(AppConfig(
            sources: sources,
            protectionEnabled: protectionEnabled,
            lastUpdated: lastUpdated,
            blockedCount: blockedCount
        ))
    }

    // MARK: License

    func activate(licenseKey: String) {
        let key = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            activationError = "Enter your license key."
            return
        }
        guard !isActivating else { return }
        isActivating = true
        activationError = nil
        Task {
            do {
                let result = try await gumroad.verify(licenseKey: key, incrementUses: true)
                if result.info.tier == .personal, result.uses > 1 {
                    throw GumroadError.deviceLimitReached
                }
                license = result.info
                store.saveLicense(result.info)
                WindowManager.shared.close(.activation)
                await runInitialSetup()
            } catch let error as GumroadError {
                activationError = error.errorDescription
            } catch {
                activationError = "Couldn't reach Gumroad: \(error.localizedDescription)"
            }
            isActivating = false
        }
    }

    /// Silent launch-time re-check: refreshes purchase details and drops the
    /// license if it was refunded or revoked. Network failures are ignored.
    private func revalidateLicense() async {
        guard let current = license else { return }
        do {
            let result = try await gumroad.verify(licenseKey: current.licenseKey, incrementUses: false)
            license = result.info
            store.saveLicense(result.info)
        } catch let error as GumroadError {
            switch error {
            case .invalidKey, .refunded:
                deactivate()
            case .notConfigured, .badResponse, .deviceLimitReached:
                break
            }
        } catch {
            // offline — keep the stored license
        }
    }

    func deactivate() {
        license = nil
        store.deleteLicense()
        WindowManager.shared.showActivation()
    }

    // MARK: Setup

    func finishSetup() {
        Task { await runInitialSetup() }
    }

    private func runInitialSetup() async {
        if !helper.isInstalled {
            do {
                try await helper.install()
            } catch {
                lastError = error.localizedDescription
                return
            }
        }
        helperInstalled = true
        lastError = nil
        await applyBlocklists(forceRefresh: false)
    }

    // MARK: Blocklist actions

    func source(withID id: String) -> BlocklistSource? {
        sources.first { $0.id == id }
    }

    func setSource(id: String, enabled: Bool) {
        guard let index = sources.firstIndex(where: { $0.id == id }) else { return }
        sources[index].enabled = enabled
        saveConfig()
        if protectionEnabled, helperInstalled {
            Task { await applyBlocklists(forceRefresh: false) }
        }
    }

    func setProtection(_ enabled: Bool) {
        guard helperInstalled else {
            lastError = HelperError.notAuthorized.errorDescription
            return
        }
        protectionEnabled = enabled
        saveConfig()
        Task {
            if enabled {
                await applyBlocklists(forceRefresh: false)
            } else {
                isWorking = true
                do {
                    try await helper.removeBlock()
                    lastError = nil
                } catch {
                    lastError = error.localizedDescription
                }
                isWorking = false
            }
        }
    }

    func updateNow() {
        Task { await applyBlocklists(forceRefresh: true) }
    }

    func flushDNS() {
        Task {
            isWorking = true
            do {
                try await helper.flushDNS()
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
            isWorking = false
        }
    }

    @discardableResult
    func addCustomList(name: String, urlString: String) -> String? {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmedURL),
            let scheme = url.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            url.host != nil
        else {
            return "Enter a valid http(s) URL."
        }
        guard !sources.contains(where: { $0.url == trimmedURL }) else {
            return "That list is already added."
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        sources.append(BlocklistSource(
            id: UUID().uuidString,
            name: trimmedName.isEmpty ? (url.host ?? "Custom list") : trimmedName,
            detail: url.host,
            url: trimmedURL,
            isBuiltIn: false,
            enabled: true
        ))
        saveConfig()
        if protectionEnabled, helperInstalled {
            Task { await applyBlocklists(forceRefresh: false) }
        }
        return nil
    }

    func removeCustomList(id: String) {
        guard let index = sources.firstIndex(where: { $0.id == id && !$0.isBuiltIn }) else { return }
        store.deleteCache(sourceID: sources[index].id)
        sources.remove(at: index)
        saveConfig()
        if protectionEnabled, helperInstalled {
            Task { await applyBlocklists(forceRefresh: false) }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            lastError = "Launch at login isn't available: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: Hosts-file pipeline

    private func refreshIfStale() {
        guard license != nil, helperInstalled, protectionEnabled, !isWorking else { return }
        let stale = lastUpdated.map { Date().timeIntervalSince($0) > AppConstants.refreshInterval } ?? true
        if stale {
            Task { await applyBlocklists(forceRefresh: true) }
        }
    }

    private func applyBlocklists(forceRefresh: Bool) async {
        guard license != nil, helperInstalled else { return }
        guard !isWorking else { return }
        isWorking = true
        lastError = nil
        defer { isWorking = false }

        var allDomains = Set<String>()
        var sourceErrors: [String] = []
        for source in sources where source.enabled {
            do {
                allDomains.formUnion(try await loadDomains(for: source, forceRefresh: forceRefresh))
            } catch {
                sourceErrors.append("\(source.name): \(error.localizedDescription)")
            }
        }

        let sorted = allDomains.sorted()
        do {
            try DomainParser.hostsLines(for: sorted)
                .write(to: store.stagingFileURL, atomically: true, encoding: .utf8)
            try await helper.apply(stagingFile: store.stagingFileURL)
            blockedCount = sorted.count
            lastUpdated = Date()
            saveConfig()
        } catch {
            lastError = error.localizedDescription
            return
        }
        if !sourceErrors.isEmpty {
            lastError = sourceErrors.joined(separator: "\n")
        }
    }

    private func loadDomains(for source: BlocklistSource, forceRefresh: Bool) async throws -> [String] {
        if !forceRefresh, let cached = store.readCache(sourceID: source.id) {
            return cached
        }
        do {
            let domains = try await fetcher.download(source)
            store.writeCache(sourceID: source.id, domains: domains)
            return domains
        } catch {
            if let cached = store.readCache(sourceID: source.id) {
                return cached
            }
            throw error
        }
    }
}
