import SwiftUI
import AppKit
import Observation

@MainActor @Observable
final class AppModel {
    enum Destination: Hashable {
        case overview, projects, category(StorageCategory), cleanup, protected, history, coverage
        var title: String {
            switch self {
            case .overview: L10n.text("Developer Storage")
            case .projects: L10n.text("Projects")
            case .category(let category): category.title
            case .cleanup: L10n.text("Clean Up Storage")
            case .protected: L10n.text("Protected Locations")
            case .history: L10n.text("Cleanup History")
            case .coverage: L10n.text("Scan Coverage")
            }
        }
    }
    var destination: Destination = .overview
    var language = AppLanguage.current
    var snapshot: ScanSnapshot?
    var items: [StorageItem] = []
    var isScanning = false
    var isCleaning = false
    var refreshingTools = false
    var progress = L10n.text("Preparing to scan")
    var scannedCount = 0
    var search = ""
    var sort: Sort = .size
    var focusedID: String?
    var selected: Set<String> = []
    var tier: CleanupTier = .regular
    var inspectorVisible = true
    var plan: CleanupPlan?
    var results: [CleanupRecord]?
    var errorMessage: String?
    var browseURL: URL?
    let updates = UpdateChecker(defaults: L10n.preferences)
    var updatesPresented = false
    var settingsPresented = false
    var addFolderPresented = false
    var archiveRetentionPresented = false
    var customRoots: [CustomRoot] = []
    var protectedPaths: Set<String> = []
    var history: [CleanupRecord] = []
    var settings = CleanupSettings()
    var availableBytes: Int64 = 0
    var diskBytes: Int64 = 0
    var capacityBeforeCleanup: Int64?
    var capacityChange: Int64?
    var scanTask: Task<ScanSnapshot, Never>?
    var cleanupTask: Task<[CleanupRecord], Never>?
    var scanID = UUID()
    enum Sort: String, CaseIterable, Identifiable {
        case size, name, date
        var id: String { rawValue }
        var title: String { switch self { case .size: L10n.text("Size: Largest First"); case .name: L10n.text("Name"); case .date: L10n.text("Last Modified") } }
    }
    private var defaults: UserDefaults
    private var fixtureRoot: URL?
    var isFixture: Bool { fixtureRoot != nil }

    init() {
        BrandMigration.prepareStandardPreferences()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-fixture") {
            fixtureRoot = try? DebugFixture.make()
            defaults = UserDefaults(suiteName: "XcodeFit.UIFixture") ?? .standard
        } else { defaults = .standard }
        #else
        defaults = .standard
        #endif
        customRoots = decode([CustomRoot].self, key: "customRoots") ?? []
        protectedPaths = Set(defaults.stringArray(forKey: "protectedPaths") ?? [])
        settings = decode(CleanupSettings.self, key: "cleanupSettings") ?? CleanupSettings()
        history = decode([CleanupRecord].self, key: "history") ?? []
        updateCapacity()
    }
    #if DEBUG
    func useTestFolders() {
        guard !isCleaning, !isScanning else { return }
        do {
            fixtureRoot = try DebugFixture.make()
            defaults = UserDefaults(suiteName: "XcodeFit.UIFixture") ?? .standard
            customRoots = []; protectedPaths = []; history = []; selected = []; settings = CleanupSettings()
            startScan()
        } catch { errorMessage = error.localizedDescription }
    }
    #endif
    var total: Int64 { items.reduce(0) { $0 + $1.size } }
    var focused: StorageItem? { items.first { $0.id == focusedID } }
    var environment: ToolEnvironment { snapshot?.environment ?? ToolEnvironment() }
    var hasIncompleteScan: Bool { snapshot?.cancelled == true || snapshot?.notices.contains(where: \.isError) == true }
    var canClean: Bool { !isScanning && !isCleaning && snapshot != nil && snapshot?.cancelled == false }
    var selectedItems: [StorageItem] { items.filter { selected.contains($0.id) } }
    var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.size } }
    var visibleItems: [StorageItem] {
        let values = items.filter { item in
            let matchesDestination: Bool
            switch destination {
            case .category(let category): matchesDestination = item.category == category
            case .projects: matchesDestination = item.category == .builds || item.category == .archives || (item.projectDataRoot != nil && item.category != .other)
            case .protected: matchesDestination = isProtected(item)
            case .cleanup: matchesDestination = item.action != .readOnly && item.minimumTier.rawValue <= tier.rawValue && (tier == .deep || !item.requiresDeepCleanup)
            default: matchesDestination = true
            }
            return matchesDestination && (search.isEmpty || [item.name, item.url.path, item.owner, item.category.title].contains { $0.localizedCaseInsensitiveContains(search) })
        }
        return values.sorted { a, b in
            switch sort {
            case .size: return a.size == b.size ? a.id < b.id : a.size > b.size
            case .name: return a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .date: return (a.date ?? .distantPast) > (b.date ?? .distantPast)
            }
        }
    }
    var categoryTotals: [(StorageCategory, Int64)] {
        StorageCategory.allCases.map { category in (category, items.filter { $0.category == category }.reduce(Int64(0)) { $0 + $1.size }) }.sorted { $0.1 > $1.1 }
    }
    func count(_ category: StorageCategory) -> Int { items.filter { $0.category == category }.count }
    func size(_ category: StorageCategory) -> Int64 { items.filter { $0.category == category }.reduce(0) { $0 + $1.size } }
    func navigate(_ destination: Destination) { self.destination = destination; focusedID = nil; search = "" }
    func startScan() {
        guard !isScanning && !isCleaning else { return }
        isScanning = true; progress = L10n.text("Inspecting development environment…"); scannedCount = 0; selected = []; items = []; focusedID = nil
        let identifier = UUID(); scanID = identifier
        var configuration = ScanConfiguration(); configuration.customRoots = customRoots; configuration.keepDeviceSupportVersions = settings.keepDeviceSupportVersions
        if let fixtureRoot {
            configuration = ScanConfiguration(home: fixtureRoot, systemDeveloper: fixtureRoot.appendingPathComponent("system"), applicationRoots: [], discoverEnvironment: false)
        }
        let task = Task.detached(priority: .utility) { [configuration, model = self] in
            StorageScanner(configuration: configuration).scan { event in
                Task { @MainActor in
                    guard model.scanID == identifier, model.isScanning else { return }
                    switch event {
                    case .progress(let label, let count): model.progress = label; model.scannedCount = count
                    case .item(let item): model.items.append(item)
                    }
                }
            }
        }
        scanTask = task
        Task { [weak self] in
            let result = await task.value
            guard let self, self.scanID == identifier else { return }
            self.snapshot = result; self.items = result.items; self.isScanning = false; self.scanTask = nil
            self.progress = result.cancelled ? L10n.text("Scan canceled. Results are incomplete.") : L10n.text("Scan complete")
            self.updateCapacity()
        }
    }
    func cancelScan() { scanTask?.cancel(); progress = L10n.text("Canceling…") }
    func refreshToolState() {
        guard !isScanning, !isCleaning, !refreshingTools, snapshot != nil else { return }
        refreshingTools = true
        Task {
            let environment = await Task.detached(priority: .utility) { ToolEnvironment.inspect() }.value
            snapshot?.environment = environment
            selected = []; refreshingTools = false
        }
    }
    func isProtected(_ item: StorageItem) -> Bool { protectedPaths.contains { PathRules.contains($0, item.id) || PathRules.contains(item.id, $0) } }
    func toggleProtection(_ item: StorageItem) {
        guard !isCleaning else { return }
        let matches = protectedPaths.filter { PathRules.contains($0, item.id) || PathRules.contains(item.id, $0) }
        if matches.isEmpty { protectedPaths.insert(item.protectionPath) } else { protectedPaths.subtract(matches) }
        selected = selected.filter { id in items.first(where: { $0.id == id }).map { !isProtected($0) } == true }
        defaults.set(Array(protectedPaths), forKey: "protectedPaths")
    }
    func blockReason(_ item: StorageItem) -> String? {
        if !canClean { return isScanning ? L10n.text("Waiting for the scan to finish") : L10n.text("Finish a complete scan before cleaning") }
        return CleanupPolicy.blockReason(item, tier: tier, protectedPaths: protectedPaths, environment: environment)
    }
    func recommended(_ item: StorageItem) -> Bool {
        canClean && CleanupPolicy.recommended(item, tier: tier, settings: settings, protectedPaths: protectedPaths, environment: environment)
    }
    func applyRecommendations() { selected = Set(items.filter { recommended($0) }.map(\.id)) }
    func changeTier(_ value: CleanupTier) { tier = value; selected = [] }
    func toggleSelection(_ item: StorageItem) {
        if selected.contains(item.id) { selected.remove(item.id) }
        else if blockReason(item) == nil { selected.insert(item.id) }
    }
    func review() {
        let valid = selectedItems.filter { blockReason($0) == nil }
        if !valid.isEmpty { plan = CleanupPlan(tier: tier, items: valid.sorted { $0.id < $1.id }) }
    }
    func executePlan(_ plan: CleanupPlan) {
        guard canClean else { return }
        self.plan = nil; isCleaning = true; progress = L10n.text("Rechecking files and development tools…"); capacityBeforeCleanup = availableBytes; capacityChange = nil
        let protected = protectedPaths
        let task = Task.detached(priority: .utility) { [model = self] in
            CleanupEngine().execute(plan, protectedPaths: protected) { record in
                Task { @MainActor in
                    model.progress = record.name
                    if !model.history.contains(where: { $0.id == record.id }) { model.history.insert(record, at: 0) }
                    model.history = Array(model.history.prefix(1000))
                    model.save(model.history, key: "history")
                }
            }
        }
        cleanupTask = task
        Task { [weak self] in
            let records = await task.value
            guard let self else { return }
            let existing = Set(self.history.map(\.id))
            self.history.insert(contentsOf: records.filter { !existing.contains($0.id) }, at: 0)
            self.history = Array(self.history.prefix(1000)); self.save(self.history, key: "history")
            self.results = records; self.selected = []; self.isCleaning = false; self.cleanupTask = nil
            self.updateCapacity()
            if let before = self.capacityBeforeCleanup { self.capacityChange = self.availableBytes - before }
            self.startScan()
        }
    }
    func cancelCleanup() { cleanupTask?.cancel(); progress = L10n.text("Stopping after the current item…") }
    func addFolder(kind: CustomRootKind) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.prompt = L10n.text("Add Scan Location"); panel.message = L10n.text("Choose %@. Read-only locations are never cleaned.", String(describing: (kind.title)))
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let normalized = PathRules.normalized(url)
        if kind == .swiftBuild && normalized.lastPathComponent != ".build" { errorMessage = L10n.text("Choose the .build folder inside a Swift package. Add other locations as read-only folders."); return }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if ["/", "/System", "/Library", "/Users", home].contains(normalized.path) { errorMessage = L10n.text("Choose a specific developer-data folder, not a system or home directory."); return }
        if !customRoots.contains(where: { $0.url == normalized }) { customRoots.append(CustomRoot(url: normalized, kind: kind)); save(customRoots, key: "customRoots") }
        addFolderPresented = false; startScan()
    }
    func removeRoot(_ root: CustomRoot) { customRoots.removeAll { $0.id == root.id }; save(customRoots, key: "customRoots"); startScan() }
    func saveSettings(language: AppLanguage? = nil) {
        guard !isCleaning else { return }
        save(settings, key: "cleanupSettings")
        if let language {
            L10n.preferences.set(language.rawValue, forKey: AppLanguage.preferenceKey)
            self.language = language
        }
        // Stored scan descriptions use the selected language. Invalidate any old worker
        // before starting a new scan so mixed-language snapshots cannot be published.
        scanID = UUID(); scanTask?.cancel(); scanTask = nil; isScanning = false
        startScan()
    }
    func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    func copyPath(_ url: URL) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(url.path, forType: .string) }
    func updateCapacity() {
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: FileManager.default.homeDirectoryForCurrentUser.path) {
            availableBytes = (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            diskBytes = (attributes[.systemSize] as? NSNumber)?.int64Value ?? 0
        }
    }
    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? { defaults.data(forKey: "XcodeFit." + key).flatMap { try? JSONDecoder().decode(type, from: $0) } }
    private func save<T: Encodable>(_ value: T, key: String) { if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: "XcodeFit." + key) } }
}
