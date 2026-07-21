import AppKit
import Foundation
import HostBlockCore
import os
import ServiceManagement
import SwiftUI

/// Unified-log channel for license operations. View with Console.app (filter
/// subsystem `com.hostblock.app`) or `log stream --predicate 'subsystem == "com.hostblock.app"'`.
private let licenseLog = Logger(subsystem: "com.hostblock.app", category: "license")

/// True when stderr is a terminal — i.e. the binary was launched from a shell
/// rather than via `open`/Finder.
private let stderrIsTerminal = isatty(STDERR_FILENO) != 0

/// Logs a license event to the unified log (`.error` for failures, `.notice`
/// otherwise) and, when run from a terminal, also mirrors it to stderr so the
/// line is visible right there without a separate `log stream`.
func logLicense(_ message: String, isError: Bool = false) {
    if isError {
        licenseLog.error("\(message, privacy: .public)")
    } else {
        licenseLog.notice("\(message, privacy: .public)")
    }
    if stderrIsTerminal {
        FileHandle.standardError.write(Data("[HostBlock/license] \(message)\n".utf8))
    }
}

enum AppConstants {
    static let gumroadProductID = "feMqfzhFkJO4HvlTTOeYcw=="
    /// URL of the license-decrement Cloudflare Worker (see server/license-decrement).
    /// Removing a license POSTs the key here so its uses slot is freed for a later
    /// re-add. Leave the placeholder to disable — removal still works locally.
    static let decrementEndpoint = "https://api.hostblock.app/license/decrement"
    static let purchaseURL = URL(string: "https://smithlabs.gumroad.com/l/host-block")!
    static let upgradeURL = URL(string: "https://smithlabs.gumroad.com/l/host-block")!
    static let freeLicenseURL = URL(string: "https://hostblock.app")!
    static let catalogURL = "https://hostblock.app/catalog.json"
    /// The shipped version, read from the bundle's Info.plist (CFBundleShortVersionString)
    /// so the footer always matches what was actually built. Falls back for `swift run`.
    static let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }()
    static let refreshInterval: TimeInterval = 24 * 60 * 60
}

enum Tab: String, CaseIterable {
    case lists
    case browse
    case license

    var title: String {
        switch self {
        case .lists: return "Lists"
        case .browse: return "Browse"
        case .license: return "License"
        }
    }

    var icon: String {
        switch self {
        case .lists: return "list.bullet"
        case .browse: return "magnifyingglass"
        case .license: return "key"
        }
    }

    /// Lists and Browse require an active license; License is always reachable.
    var requiresLicense: Bool { self != .license }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published private(set) var license: LicenseInfo?
    @Published private(set) var sources: [BlocklistSource] = DefaultLists.seed
    @Published private(set) var catalog: [CatalogEntry] = Catalog.bundled
    @Published private(set) var protectionEnabled = true
    @Published private(set) var helperInstalled = false
    @Published private(set) var isWorking = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var blockedCount = 0
    @Published private(set) var lastError: String?
    @Published private(set) var launchAtLogin = false
    @Published private(set) var isActivating = false
    @Published var activationError: String?
    @Published private(set) var isDeactivating = false
    @Published private(set) var deactivationError: String?
    @Published var selectedTab: Tab = .lists

    private let store: ConfigStore
    private let fetcher = BlocklistFetcher()
    private let helper = PrivilegedHelper()
    private let catalogFetcher = CatalogFetcher(urlString: AppConstants.catalogURL)
    private let gumroad = GumroadClient(
        productID: AppConstants.gumroadProductID,
        decrementEndpoint: AppConstants.decrementEndpoint
    )
    private var refreshTimer: Timer?
    private var bootstrapped = false

    /// Demo mode (HOSTBLOCK_DEMO=1) renders the UI from seeded data without any network
    /// or privileged side effects — used to screenshot the design against the mockups.
    private let demoMode = ProcessInfo.processInfo.environment["HOSTBLOCK_DEMO"] == "1"

    private init() {
        // A support-dir override lets a throwaway data set be used for screenshots and
        // manual testing without disturbing the real ~/Library/Application Support/HostBlock.
        if let override = ProcessInfo.processInfo.environment["HOSTBLOCK_SUPPORT_DIR"] {
            store = ConfigStore(baseDir: URL(fileURLWithPath: override, isDirectory: true))
        } else {
            store = ConfigStore()
        }
    }

    // MARK: Startup

    func bootstrap() {
        guard !bootstrapped else { return }
        bootstrapped = true

        if let config = store.loadConfig() {
            sources = Self.migrateCategories(config.sources)
            protectionEnabled = config.protectionEnabled
            lastUpdated = config.lastUpdated
            blockedCount = config.blockedCount
        }
        license = store.loadLicense()
        helperInstalled = demoMode ? true : helper.isInstalled
        launchAtLogin = SMAppService.mainApp.status == .enabled
        selectedTab = license == nil ? .license : .lists
        catalog = store.loadCatalog() ?? Catalog.bundled

        // Demo mode stops here: no Gumroad checks, list downloads, hosts writes, or timers.
        guard !demoMode else {
            if let tab = ProcessInfo.processInfo.environment["HOSTBLOCK_TAB"].flatMap(Tab.init) {
                selectedTab = tab
            }
            return
        }

        Task { await refreshCatalog() }
        if license != nil {
            Task { await self.revalidateLicense() }
            refreshIfStale()
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { _ in
            Task { @MainActor in AppState.shared.refreshIfStale() }
        }
    }

    /// Configs written before categories existed decode every list as `.custom`.
    /// Recover the real category for any such list whose URL is in the catalog, so
    /// upgraders don't see everything badged CUSTOM.
    private static func migrateCategories(_ sources: [BlocklistSource]) -> [BlocklistSource] {
        let byURL = Dictionary(Catalog.bundled.map { ($0.url, $0.category) }, uniquingKeysWith: { first, _ in first })
        return sources.map { source in
            guard source.category == .custom, let category = byURL[source.url] else { return source }
            var updated = source
            updated.category = category
            return updated
        }
    }

    private func saveConfig() {
        store.saveConfig(AppConfig(
            sources: sources,
            protectionEnabled: protectionEnabled,
            lastUpdated: lastUpdated,
            blockedCount: blockedCount
        ))
    }

    // MARK: Catalog

    private func refreshCatalog() async {
        do {
            let entries = try await catalogFetcher.fetch()
            guard !entries.isEmpty else { return }
            catalog = entries
            store.saveCatalog(entries)
        } catch {
            // Keep the cached/bundled catalog when the remote one is unreachable.
        }
    }

    func isInstalled(catalogID: String) -> Bool {
        sources.contains { $0.id == catalogID }
    }

    func addFromCatalog(_ entry: CatalogEntry) {
        guard !isInstalled(catalogID: entry.id) else { return }
        sources.append(entry.asSource(enabled: true))
        saveConfig()
        applyIfActive()
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
                var info = result.info
                info.deviceCount = result.uses
                license = info
                store.saveLicense(info)
                // Activating (re)enables blocking — removal turns it off, so a fresh
                // activation must turn it back on before setup applies the lists.
                protectionEnabled = true
                selectedTab = .lists
                logLicense("License activated (tier \(info.tier.rawValue), uses \(result.uses))")
                await runInitialSetup()
            } catch let error as GumroadError {
                activationError = error.errorDescription
                logLicense("Activation failed: \(error.localizedDescription)", isError: true)
            } catch {
                activationError = "Couldn't reach Gumroad: \(error.localizedDescription)"
                logLicense("Activation failed (could not reach Gumroad): \(error.localizedDescription)", isError: true)
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
            var info = result.info
            info.deviceCount = result.uses
            license = info
            store.saveLicense(info)
        } catch let error as GumroadError {
            switch error {
            case .invalidKey, .refunded:
                clearLicenseLocally()
            case .notConfigured, .badResponse, .deviceLimitReached:
                break
            }
        } catch {
            // offline — keep the stored license
        }
    }

    /// User-initiated removal. Frees the device's uses slot on the license server
    /// FIRST, and only removes the license locally if that succeeds — so a failed
    /// decrement can't strand the count (leaving the app removed but the device still
    /// counted). On failure the license is kept and an error is surfaced to retry.
    func deactivate() {
        guard let key = license?.licenseKey else {
            clearLicenseLocally()
            return
        }
        // Nothing to free server-side (demo mode, or endpoint not configured): the
        // slot concept doesn't apply, so just remove locally.
        guard !demoMode, gumroad.isDecrementConfigured else {
            clearLicenseLocally()
            return
        }
        guard !isDeactivating else { return }
        isDeactivating = true
        deactivationError = nil
        Task {
            do {
                try await gumroad.decrementUses(licenseKey: key)
                logLicense("Freed license uses slot on removal")
                clearLicenseLocally()
            } catch {
                logLicense("Failed to free license uses slot on removal: \(error.localizedDescription)", isError: true)
                deactivationError = "Couldn't reach the license server to release this device. Your license was kept — check your connection and try again."
                isDeactivating = false
            }
        }
    }

    /// Drops the license locally without touching the server. Used on successful
    /// deactivation, when there's no server slot to free, and when a revalidation
    /// finds the license invalid/refunded.
    private func clearLicenseLocally() {
        license = nil
        store.deleteLicense()
        selectedTab = .license
        deactivationError = nil
        isDeactivating = false
        // Removing the license unlicenses the app, so also stop blocking: turn
        // protection off and strip the HostBlock section from /etc/hosts, exactly
        // like toggling blocking off from the header.
        if protectionEnabled {
            protectionEnabled = false
            saveConfig()
            if helperInstalled, !demoMode {
                Task {
                    isWorking = true
                    do {
                        try await helper.removeBlock()
                    } catch {
                        lastError = error.localizedDescription
                    }
                    isWorking = false
                }
            }
        }
    }

    var deviceUsage: String {
        guard let license else { return "—" }
        switch license.tier {
        case .personal: return "\(license.deviceCount) / 1"
        case .pro: return "\(license.deviceCount) · unlimited"
        }
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
        applyIfActive()
    }

    func setProtection(_ enabled: Bool) {
        guard license != nil else { return }
        if demoMode { protectionEnabled = enabled; return }
        // Turning protection on for the first time installs the privileged helper
        // (the single admin prompt), then enables and applies.
        if enabled, !helperInstalled {
            protectionEnabled = true
            saveConfig()
            Task { await runInitialSetup() }
            return
        }
        guard helperInstalled else { return }
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
        guard !demoMode else { return }
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
        sources.append(BlocklistSource.custom(
            name: trimmedName.isEmpty ? (url.host ?? "Custom list") : trimmedName,
            url: trimmedURL,
            host: url.host
        ))
        saveConfig()
        applyIfActive()
        return nil
    }

    func removeSource(id: String) {
        guard let index = sources.firstIndex(where: { $0.id == id }) else { return }
        store.deleteCache(sourceID: id)
        sources.remove(at: index)
        saveConfig()
        applyIfActive()
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

    private func applyIfActive() {
        if protectionEnabled, helperInstalled {
            Task { await applyBlocklists(forceRefresh: false) }
        }
    }

    private func refreshIfStale() {
        guard license != nil, helperInstalled, protectionEnabled, !isWorking else { return }
        let stale = lastUpdated.map { Date().timeIntervalSince($0) > AppConstants.refreshInterval } ?? true
        if stale {
            Task { await applyBlocklists(forceRefresh: true) }
        }
    }

    private func applyBlocklists(forceRefresh: Bool) async {
        guard !demoMode else { return }
        guard license != nil, helperInstalled else { return }
        guard !isWorking else { return }
        isWorking = true
        lastError = nil
        defer { isWorking = false }

        var allDomains = Set<String>()
        var sourceErrors: [String] = []
        var counts: [String: Int] = [:]
        for source in sources where source.enabled {
            do {
                let domains = try await loadDomains(for: source, forceRefresh: forceRefresh)
                allDomains.formUnion(domains)
                counts[source.id] = domains.count
            } catch {
                sourceErrors.append("\(source.name): \(error.localizedDescription)")
            }
        }

        let now = Date()
        for (id, count) in counts {
            if let index = sources.firstIndex(where: { $0.id == id }) {
                sources[index].domainCount = count
                sources[index].lastFetched = now
            }
        }

        let sorted = allDomains.sorted()
        do {
            try DomainParser.hostsLines(for: sorted)
                .write(to: store.stagingFileURL, atomically: true, encoding: .utf8)
            try await helper.apply(stagingFile: store.stagingFileURL)
            blockedCount = sorted.count
            lastUpdated = now
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
