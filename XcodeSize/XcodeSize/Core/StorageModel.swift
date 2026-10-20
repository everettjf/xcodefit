import Foundation

enum StorageCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case installations, components, builds, caches, packages, archives, simulators, previews, deviceSupport, logs, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .installations: L10n.text("Xcode & Tools")
        case .components: L10n.text("Platforms & Runtimes")
        case .builds: L10n.text("Project Builds")
        case .caches: L10n.text("Compiler Caches")
        case .packages: L10n.text("Swift Packages")
        case .archives: L10n.text("Archives")
        case .simulators: L10n.text("Simulator Devices")
        case .previews: L10n.text("Previews & Tests")
        case .deviceSupport: L10n.text("Device Support")
        case .logs: L10n.text("Logs & Docs")
        case .other: L10n.text("Other Developer Data")
        }
    }
    var symbol: String {
        switch self {
        case .installations: "app.badge"
        case .components: "shippingbox"
        case .builds: "hammer"
        case .caches: "square.stack.3d.up"
        case .packages: "shippingbox.fill"
        case .archives: "archivebox"
        case .simulators: "iphone"
        case .previews: "viewfinder"
        case .deviceSupport: "cable.connector"
        case .logs: "doc.text"
        case .other: "folder"
        }
    }
    var purpose: String {
        switch self {
        case .installations: L10n.text("Xcode apps, bundled SDKs, and compiler toolchains. Internal folders are included in the installation size and are not counted or cleaned separately.")
        case .components: L10n.text("Simulator operating systems and development components for different platforms. Runtimes are managed using Apple's simctl; mounted views are not counted twice.")
        case .builds: L10n.text("Build products, intermediate files, and source indexes. Cleaning requires rebuilding and reindexing; some package dependencies may need to be downloaded again.")
        case .caches: L10n.text("Reusable compiler results, modules, and SDK file-state caches speed up builds. They can be regenerated, but the next build may take longer.")
        case .packages: L10n.text("Swift Package Manager repositories, source working copies, manifests, and binary dependencies. Cleaning may require an internet connection; local changes in working copies are not automatically restored.")
        case .archives: L10n.text("Released apps, version metadata, and dSYMs. Symbols must match the released binary's UUID; rebuilding cannot guarantee recovery.")
        case .simulators: L10n.text("Apps, sandboxes, databases, and settings for individual simulator devices. Removing a device permanently discards its local test data.")
        case .previews: L10n.text("Devices and build data used by SwiftUI previews and XCTest. They may contain local test state. Modern previews can also share regular build products.")
        case .deviceSupport: L10n.text("System debug symbols and support data for connected devices. Debugging those OS versions again may require preparing or downloading this data again.")
        case .logs: L10n.text("Build, test, device diagnostic logs, and developer documentation. Deleted diagnostic evidence cannot be recreated; documentation caches can be downloaded again.")
        case .other: L10n.text("Other discovered developer data or user-selected folders. Unidentified content is shown read-only and is never automatically selected for cleanup.")
        }
    }
}

enum CleanupTier: Int, CaseIterable, Codable, Sendable, Identifiable {
    case simple = 0, regular, deep
    var id: Int { rawValue }
    var title: String { switch self { case .simple: L10n.text("Quick Clean"); case .regular: L10n.text("Standard Clean"); case .deep: L10n.text("Deep Clean") } }
    var symbol: String { switch self { case .simple: "sparkles"; case .regular: "slider.horizontal.3"; case .deep: "square.stack.3d.down.right" } }
    var subtitle: String {
        switch self {
        case .simple: L10n.text("Rebuild caches. Retire old logs.")
        case .regular: L10n.text("Also clean idle builds and dependencies.")
        case .deep: L10n.text("Also choose archives, devices, and old tools.")
        }
    }
}

enum CleanupAction: Codable, Equatable, Sendable {
    case trash
    case simulator(String)
    case runtime(String)
    case readOnly
    var title: String {
        switch self { case .trash: L10n.text("Move to Trash"); case .simulator: L10n.text("Remove Device Using simctl"); case .runtime: L10n.text("Remove Runtime Using simctl"); case .readOnly: L10n.text("Read Only") }
    }
    var isPermanent: Bool { switch self { case .simulator, .runtime: true; default: false } }
}

struct FileIdentity: Codable, Hashable, Sendable {
    var device: UInt64
    var inode: UInt64
}

struct Measurement: Codable, Sendable {
    var allocated: Int64 = 0
    var logical: Int64 = 0
    var files: Int = 0
    var newestModification: Date?
    var fingerprint: UInt64 = 0
    var unreadable: Int = 0
    var hardLinks: Int = 0
    var identity: FileIdentity?
    var cancelled: Bool = false
}

struct StorageItem: Identifiable, Codable, Sendable {
    var id: String { url.path }
    var url: URL
    var name: String
    var category: StorageCategory
    var purpose: String
    var owner: String
    var evidence: String
    var measurement: Measurement
    var action: CleanupAction
    var minimumTier: CleanupTier
    var manualOnly: Bool = false
    var blockedReason: String?
    var date: Date?
    var dateLabel: String = L10n.text("Last Modified")
    var sourceRoot: URL
    var subtitle: String = ""
    var retainedDeviceSupport: Bool = false
    var projectDataRoot: URL?
    var size: Int64 { measurement.allocated }
    var protectionPath: String { projectDataRoot?.path ?? id }
    var complete: Bool { measurement.unreadable == 0 && !measurement.cancelled }
}

struct ScanNotice: Identifiable, Codable, Sendable {
    var id: String { path + message }
    var path: String
    var message: String
    var isError: Bool = false
}

enum CustomRootKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case derivedData, archives, swiftBuild, exports, browse
    var id: String { rawValue }
    var title: String {
        switch self { case .derivedData: L10n.text("DerivedData Root"); case .archives: L10n.text("Archives Root"); case .swiftBuild: L10n.text("Swift .build Folder"); case .exports: L10n.text("Exported Products Folder"); case .browse: L10n.text("Other Folder (Read Only)") }
    }
}
struct CustomRoot: Identifiable, Codable, Sendable {
    var id: String { url.path }
    var url: URL
    var kind: CustomRootKind
}
struct ScanConfiguration: Sendable {
    var home = FileManager.default.homeDirectoryForCurrentUser
    var systemDeveloper = URL(fileURLWithPath: "/Library/Developer")
    var applicationRoots = [URL(fileURLWithPath: "/Applications"), FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
    var customRoots: [CustomRoot] = []
    var discoverEnvironment = true
    var keepDeviceSupportVersions = 2
}
struct ScanSnapshot: Sendable {
    var items: [StorageItem] = []
    var notices: [ScanNotice] = []
    var scannedRoots: [String] = []
    var date = Date()
    var cancelled = false
    var environment = ToolEnvironment()
    var total: Int64 { items.reduce(0) { $0 + $1.size } }
}
enum ScanEvent: Sendable {
    case progress(String, Int)
    case item(StorageItem)
}

struct CleanupSettings: Codable, Sendable {
    var logDays = 30
    var idleDays = 90
    var keepDeviceSupportVersions = 2
}

enum CleanupPolicy {
    static func blockReason(_ item: StorageItem, tier: CleanupTier, protectedPaths: Set<String>, environment: ToolEnvironment) -> String? {
        if let reason = item.blockedReason { return reason }
        if !item.complete { return L10n.text("The scan is incomplete; not all files can be verified.") }
        if item.action == .readOnly { return L10n.text("This item is read-only.") }
        if tier.rawValue < item.minimumTier.rawValue { return L10n.text("Switch to %@", String(describing: (item.minimumTier.title))) }
        if protectedPaths.contains(where: { PathRules.contains($0, item.url.path) || PathRules.contains(item.url.path, $0) }) { return L10n.text("This location is protected.") }
        if environment.toolsBusy { return L10n.text("Xcode or development tools are running.") }
        if !environment.processStateKnown { return L10n.text("Development-tool status cannot be verified.") }
        if case .simulator(let id) = item.action {
            guard environment.simulatorStateKnown else { return L10n.text("Simulator state cannot be verified.") }
            if environment.bootedDevices.contains(id) { return L10n.text("The simulator is running.") }
        }
        if case .runtime = item.action {
            guard environment.simulatorStateKnown else { return L10n.text("Simulator state cannot be verified.") }
            if !environment.bootedDevices.isEmpty { return L10n.text("A simulator is running.") }
        }
        return nil
    }
    static func recommended(_ item: StorageItem, tier: CleanupTier, settings: CleanupSettings, protectedPaths: Set<String>, environment: ToolEnvironment, now: Date = Date()) -> Bool {
        guard blockReason(item, tier: tier, protectedPaths: protectedPaths, environment: environment) == nil, !item.manualOnly else { return false }
        let age = now.timeIntervalSince(item.date ?? now) / 86400
        switch item.category {
        case .caches: return true
        case .logs: return age >= Double(settings.logDays)
        case .builds, .packages, .previews: return tier == .deep || age >= Double(settings.idleDays)
        case .deviceSupport: return age >= Double(settings.idleDays) && !item.retainedDeviceSupport
        default: return false
        }
    }
}

enum PathRules {
    static func contains(_ root: String, _ path: String) -> Bool { path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/") }
    static func normalized(_ url: URL) -> URL { url.standardizedFileURL.resolvingSymlinksInPath() }
    static func compact(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return contains(home, url.path) ? "~" + url.path.dropFirst(home.count) : url.path
    }
}

enum StorageFormatting {
    static func bytes(_ value: Int64) -> String {
        let f = ByteCountFormatter(); f.countStyle = .decimal; f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]; f.includesUnit = true
        return value == 0 ? "0 KB" : f.string(fromByteCount: value)
    }
}
