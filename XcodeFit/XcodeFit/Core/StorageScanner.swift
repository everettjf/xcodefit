import Foundation

struct ScanCandidate: Sendable {
    var url: URL
    var category: StorageCategory
    var action: CleanupAction = .readOnly
    var tier: CleanupTier = .deep
    var manual = false
    var name: String?
    var owner: String = L10n.text("Shared Development Environment")
    var evidence: String = L10n.text("Standard developer directory")
    var blocked: String?
    var sourceRoot: URL
    var subtitle: String = ""
    var date: Date?
    var dateLabel: String = L10n.text("Last Modified")
    var retainedDeviceSupport: Bool = false
    var projectDataRoot: URL?
}

final class StorageScanner {
    private let fm = FileManager.default
    private var candidates: [ScanCandidate] = []
    private var notices: [ScanNotice] = []
    private var roots: [String] = []
    private var config: ScanConfiguration
    private var environment = ToolEnvironment()
    private var projectRoots = Set<URL>()

    init(configuration: ScanConfiguration) { config = configuration }

    func scan(emit: @escaping @Sendable (ScanEvent) -> Void = { _ in }) -> ScanSnapshot {
        emit(.progress(L10n.text("Identifying Xcode, development tools, and simulators…"), 0))
        environment = config.discoverEnvironment ? ToolEnvironment.inspect() : ToolEnvironment(processStateKnown: true, simulatorStateKnown: true)
        for notice in environment.notices { notices.append(ScanNotice(path: "simctl", message: notice, isError: true)) }
        discover()
        candidates = deduplicate(candidates)
        var seen = Set<FileIdentity>()
        var items: [StorageItem] = []
        let allPaths = candidates.map(\.url)
        for candidate in candidates {
            if Task.isCancelled { break }
            emit(.progress(candidate.name ?? candidate.url.lastPathComponent, items.count))
            if FileSizer.fileSystemType(candidate.url) == "devicefs" {
                notices.append(ScanNotice(path: candidate.url.path, message: L10n.text("The DeviceFS mounted view is excluded. It is not independent storage on this Mac.")))
                continue
            }
            let exclusions = allPaths.filter { $0 != candidate.url && PathRules.contains(candidate.url.path, $0.path) }
            let measurement = FileSizer.measure(candidate.url, seen: &seen, excluded: exclusions) { count in
                emit(.progress(L10n.text("%@ · File system entries checked: %@", String(describing: (candidate.name ?? candidate.url.lastPathComponent)), String(describing: (count.formatted()))), items.count))
            }
            var blocked = candidate.blocked
            if FileSizer.isSymlink(candidate.url) { blocked = L10n.text("Only the symbolic link itself is counted. Its target is not followed or cleaned.") }
            if !exclusions.isEmpty && candidate.action != .readOnly { blocked = L10n.text("This folder contains separately managed data. Browsing only.") }
            var item = StorageItem(url: candidate.url, name: candidate.name ?? candidate.url.lastPathComponent,
                                   category: candidate.category, purpose: candidate.category.purpose,
                                   owner: candidate.owner, evidence: candidate.evidence, measurement: measurement,
                                   action: candidate.action, minimumTier: candidate.tier, manualOnly: candidate.manual,
                                   blockedReason: blocked, date: candidate.date ?? measurement.newestModification,
                                   dateLabel: candidate.dateLabel, sourceRoot: candidate.sourceRoot, subtitle: candidate.subtitle,
                                   retainedDeviceSupport: candidate.retainedDeviceSupport, projectDataRoot: candidate.projectDataRoot)
            if candidate.url.pathExtension == "xcarchive", !FileSizer.isSymlink(candidate.url) { item.archive = ArchiveMetadata.read(candidate.url) }
            if measurement.containsReleaseSymbols || measurement.containsWorkingCopies { item.minimumTier = .deep; item.manualOnly = true }
            items.append(item); emit(.item(item))
            if measurement.unreadable > 0 { notices.append(ScanNotice(path: item.id, message: L10n.text("Unreadable entries: %@. Size includes only readable content; cleanup is disabled.", String(describing: (measurement.unreadable))), isError: true)) }
        }
        let uniqueNotices = Dictionary(grouping: notices, by: \.id).values.compactMap(\.first).sorted { $0.path < $1.path }
        return ScanSnapshot(items: items, notices: uniqueNotices, scannedRoots: Array(Set(roots)).sorted(), cancelled: Task.isCancelled, environment: environment)
    }

    private func children(_ url: URL) -> [URL] {
        do { return try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []).filter { $0.lastPathComponent != ".DS_Store" }.sorted { $0.path < $1.path } }
        catch { notices.append(ScanNotice(path: url.path, message: L10n.text("Cannot read: %@", String(describing: (error.localizedDescription))), isError: true)); return [] }
    }
    private func exists(_ url: URL) -> Bool { fm.fileExists(atPath: url.path) }
    private func add(_ url: URL, _ category: StorageCategory, action: CleanupAction = .readOnly, tier: CleanupTier = .deep, manual: Bool = false, name: String? = nil, owner: String = L10n.text("Shared Development Environment"), evidence: String = L10n.text("Standard developer directory"), blocked: String? = nil, root: URL? = nil, subtitle: String = "", date: Date? = nil, dateLabel: String = L10n.text("Last Modified"), retainedDeviceSupport: Bool = false, projectDataRoot: URL? = nil) {
        guard exists(url) else { return }
        candidates.append(ScanCandidate(url: url.standardizedFileURL, category: category, action: action, tier: tier, manual: manual, name: name, owner: owner, evidence: evidence, blocked: blocked, sourceRoot: root ?? url.deletingLastPathComponent(), subtitle: subtitle, date: date, dateLabel: dateLabel, retainedDeviceSupport: retainedDeviceSupport, projectDataRoot: projectDataRoot))
    }
    private func recordRoot(_ url: URL) -> Bool {
        if exists(url) { roots.append(url.path); return true }
        notices.append(ScanNotice(path: url.path, message: L10n.text("Directory does not exist. No data found."))); return false
    }
    private func split(_ url: URL, category: StorageCategory, action: CleanupAction = .readOnly, tier: CleanupTier = .deep, manual: Bool = false) {
        if FileSizer.isSymlink(url) { add(url, category); return }
        let values = children(url)
        if values.isEmpty { add(url, category, action: action, tier: tier, manual: manual) }
        else { for child in values { add(child, category, action: action, tier: tier, manual: manual, root: url) } }
    }
    private func discover() {
        let userDev = config.home.appendingPathComponent("Library/Developer")
        for root in [userDev, config.systemDeveloper] where recordRoot(root) {
            for child in children(root) {
                switch child.lastPathComponent {
                case "Xcode": discoverXcodeData(child)
                case "CoreSimulator": discoverCoreSimulator(child)
                case "XCTestDevices", "XCPGDevices": split(child, category: .previews, action: .trash, tier: .deep, manual: true)
                case "CommandLineTools": add(child, .installations, name: "Command Line Tools", blocked: L10n.text("System-managed development tools. Browsing only."))
                case "Toolchains": split(child, category: .installations)
                case "Shared":
                    for shared in children(child) {
                        if shared.lastPathComponent == "Documentation" { split(shared, category: .logs, action: .trash, tier: .regular) }
                        else { add(shared, .other) }
                    }
                case "DVTDownloads": split(child, category: .components)
                case "CoreDevice", "DeveloperDiskImages", "DeviceKit": split(child, category: .components)
                default: add(child, .other)
                }
            }
        }
        for base in config.applicationRoots where exists(base) {
            roots.append(base.path + L10n.text(" (Xcode installations only)"))
            discoverApps(in: base, depth: 0)
        }
        if let selected = environment.activeDeveloperPath, let range = selected.range(of: ".app/") {
            let app = URL(fileURLWithPath: String(selected[..<range.lowerBound]) + ".app")
            addXcode(app)
        }
        let cacheRoot = config.home.appendingPathComponent("Library/Caches")
        if exists(cacheRoot) {
            roots.append(cacheRoot.path + L10n.text(" (Xcode / SwiftPM only)"))
            for cache in children(cacheRoot) {
                let name = cache.lastPathComponent
                if name == "org.swift.swiftpm" { split(cache, category: .packages, action: .trash, tier: .regular) }
                else if name.hasPrefix("com.apple.dt.Xcode") || name == "com.apple.DeveloperTools" { split(cache, category: .caches, action: .trash, tier: .regular) }
            }
        }
        for relative in [".cache/swift-package-manager", ".cache/org.swift.swiftpm"] {
            let url = config.home.appendingPathComponent(relative)
            if exists(url) { roots.append(url.path); split(url, category: .packages, action: .trash, tier: .regular) }
        }
        for relative in ["Library/org.swift.swiftpm", ".swiftpm", "Library/MobileDevice/Provisioning Profiles"] {
            let url = config.home.appendingPathComponent(relative)
            if exists(url) { roots.append(url.path); add(url, .other, blocked: L10n.text("Configuration, credential references, or signing data. Browsing only.")) }
        }
        for relative in ["Library/Logs/CoreSimulator", "Library/Logs/Xcode", "Library/Application Support/com.apple.dt.Xcode"] {
            let url = config.home.appendingPathComponent(relative)
            if exists(url) { roots.append(url.path); split(url, category: relative.contains("Logs") ? .logs : .other, action: relative.contains("Logs") ? .trash : .readOnly, tier: .regular) }
        }
        // Only attributable developer-tool caches; never scan or clean all of /var/folders.
        if config.discoverEnvironment {
            let cache = CommandRunner.run("/usr/bin/getconf", ["DARWIN_USER_CACHE_DIR"], timeout: 5)
            if cache.succeeded {
                let path = cache.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if path.hasPrefix("/var/folders/") || path.hasPrefix("/private/var/folders/") {
                    let url = URL(fileURLWithPath: path).appendingPathComponent("com.apple.DeveloperTools")
                    if exists(url) { roots.append(url.path); split(url, category: .caches, action: .trash, tier: .regular) }
                }
            }
            discoverXcodePreferences()
            discoverAssets()
        }
        for runtime in environment.runtimes {
            let url = PathRules.normalized(URL(fileURLWithPath: runtime.path))
            if exists(url) {
                add(url, .components, action: runtime.deletable ? .runtime(runtime.id) : .readOnly, tier: .deep, manual: true,
                    name: runtime.name, evidence: L10n.text("Backing storage from simctl runtime list; mounted views are not counted twice"), root: url.deletingLastPathComponent(),
                    subtitle: L10n.text("Runtime · %@", String(describing: (runtime.reportedSize > 0 ? StorageFormatting.bytes(runtime.reportedSize) + L10n.text(" reported by tool") : L10n.text("System Managed")))), date: runtime.lastUsed, dateLabel: runtime.lastUsed == nil ? L10n.text("Last Modified") : L10n.text("Last Used (simctl)"))
            } else { notices.append(ScanNotice(path: runtime.path, message: L10n.text("simctl reports runtime %@, but its backing storage is unreadable. Reported size: %@; excluded from the file-scan total.", String(describing: (runtime.name)), String(describing: (StorageFormatting.bytes(runtime.reportedSize)))), isError: true)) }
        }
        for custom in config.customRoots {
            let url = custom.url.standardizedFileURL
            guard recordRoot(url) else { continue }
            switch custom.kind {
            case .derivedData: discoverDerivedData(url)
            case .archives: discoverArchives(url)
            case .swiftBuild: add(url, .builds, action: .trash, tier: .regular, owner: url.deletingLastPathComponent().lastPathComponent, evidence: L10n.text("User-selected Swift build directory"))
            case .exports: split(url, category: .archives, action: .trash, tier: .deep, manual: true)
            case .browse: add(url, .other, evidence: L10n.text("User-selected read-only directory"))
            }
        }
        discoverProjectOutputs()
        notices.append(ScanNotice(path: L10n.text("Scan Coverage"), message: L10n.text("Only attributable standard and custom locations are counted. Script outputs and relative build folders may be missing; add their actual locations.")))
        notices.append(ScanNotice(path: L10n.text("Measurement"), message: L10n.text("Allocated size is deduplicated by device/inode. Links and cross-filesystem descendants are not followed. APFS shared blocks and snapshots may reduce reclaimed space. Container directory metadata is not added separately.")))
    }
    private func discoverApps(in root: URL, depth: Int) {
        for url in children(root) {
            if Task.isCancelled { return }
            if url.pathExtension == "app" { addXcode(url) }
            else if depth < 1 && !FileSizer.isSymlink(url) && (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { discoverApps(in: url, depth: depth + 1) }
        }
    }
    private func addXcode(_ url: URL) {
        let info = plist(url.appendingPathComponent("Contents/Info.plist"))
        guard info["CFBundleIdentifier"] as? String == "com.apple.dt.Xcode" else { return }
        let active = environment.activeDeveloperPath.map { PathRules.contains(PathRules.normalized(url).path, PathRules.normalized(URL(fileURLWithPath: $0)).path) } == true
        let version = info["CFBundleShortVersionString"] as? String ?? ""
        add(url, .installations, action: .trash, tier: .deep, manual: true, name: url.deletingPathExtension().lastPathComponent + " " + version,
            owner: "Xcode " + version, evidence: L10n.text("App bundle identifier: com.apple.dt.Xcode"), blocked: active ? L10n.text("The Xcode installation currently selected by xcode-select") : nil, subtitle: active ? L10n.text("Active Development Tools") : L10n.text("Complete installation, including SDKs and toolchains"))
    }
    private func discoverXcodeData(_ root: URL) {
        for child in children(root) {
            let name = child.lastPathComponent
            if name == "DerivedData" { discoverDerivedData(child) }
            else if name == "Archives" { discoverArchives(child) }
            else if name.hasSuffix("DeviceSupport") { discoverDeviceSupport(child) }
            else if name == "UserData" {
                for data in children(child) {
                    if data.lastPathComponent == "Previews" { split(data, category: .previews, action: .trash, tier: .deep, manual: true) }
                    else if data.lastPathComponent == "IB Support" { split(data, category: .caches, action: .trash, tier: .regular) }
                    else { add(data, .other, blocked: L10n.text("User settings, code snippets, or personal data. Browsing only.")) }
                }
            } else if ["DocumentationCache", "iOS Device Logs", "Documentation"].contains(name) { split(child, category: .logs, action: .trash, tier: .regular) }
            else if name == "Products" { split(child, category: .builds, action: .trash, tier: .deep, manual: true) }
            else if name.contains("Cache") { add(child, .caches, action: .trash, tier: .regular) }
            else { add(child, .other) }
        }
    }
    private func discoverDerivedData(_ root: URL) {
        // -derivedDataPath points directly at one project's data; Xcode's default is a collection.
        if exists(root.appendingPathComponent("Build")) && (exists(root.appendingPathComponent("Logs")) || exists(root.appendingPathComponent("info.plist"))) {
            discoverProject(root)
            return
        }
        for child in children(root) {
            let name = child.lastPathComponent
            if ["ModuleCache", "ModuleCache.noindex", "CompilationCache.noindex", "SDKStatCaches.noindex", "SDKExplicitPrecompiledModules", "SymbolCache.noindex"].contains(name) {
                add(child, .caches, action: .trash, tier: .regular, root: root)
            } else { discoverProject(child) }
        }
    }
    private func discoverProject(_ projectData: URL) {
        let name = projectData.lastPathComponent
        let info = plist(projectData.appendingPathComponent("info.plist"))
        let workspace = info["WorkspacePath"] as? String
        let project = workspace.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
        if let workspace, workspace.hasPrefix("/") {
            var directory = URL(fileURLWithPath: workspace).deletingLastPathComponent()
            if directory.pathExtension == "xcodeproj" { directory = directory.deletingLastPathComponent() }
            projectRoots.insert(directory)
        }
        let identified = workspace != nil || exists(projectData.appendingPathComponent("Build")) || exists(projectData.appendingPathComponent("Index.noindex"))
        guard identified && !FileSizer.isSymlink(projectData) else {
            add(projectData, .other, owner: workspace ?? L10n.text("Unidentified Project"), evidence: L10n.text("Unidentified item in DerivedData"))
            return
        }
        for part in children(projectData) {
            let partName = part.lastPathComponent
            let category: StorageCategory
            let action: CleanupAction
            let tier: CleanupTier
            switch partName {
            case "Build", "Index", "Index.noindex", "PrecompiledHeaders": category = .builds; action = .trash; tier = .regular
            case "SourcePackages": category = .packages; action = .trash; tier = .deep
            case "Logs": category = .logs; action = .trash; tier = .regular
            case "ModuleCache", "ModuleCache.noindex", "CompilationCache.noindex", "SDKStatCaches.noindex", "SDKExplicitPrecompiledModules": category = .caches; action = .trash; tier = .regular
            default: category = .other; action = .readOnly; tier = .deep
            }
            add(part, category, action: action, tier: tier, manual: partName == "SourcePackages", name: (project ?? name) + " · " + DirectoryBrowser.explanation(partName),
                owner: workspace ?? name, evidence: "DerivedData/" + (workspace == nil ? L10n.text("build structure") : "info.plist → WorkspacePath") + " → " + partName,
                root: projectData, subtitle: partName, projectDataRoot: projectData)
        }
    }
    private func discoverProjectOutputs() {
        // Bounded probes of known projects; never recursively search source trees or arbitrary user folders.
        for directory in projectRoots.sorted(by: { $0.path < $1.path }) {
            let swift = directory.appendingPathComponent(".build")
            if exists(directory.appendingPathComponent("Package.swift")) && exists(swift) {
                roots.append(swift.path)
                add(swift, .builds, action: .trash, tier: .regular, owner: directory.path, evidence: L10n.text("Package.swift + .build in an identified project folder"))
            }
            for name in ["DerivedData", "build", "Build"] {
                let path = directory.appendingPathComponent(name)
                if exists(path.appendingPathComponent("Build")) && exists(path.appendingPathComponent("info.plist")) {
                    roots.append(path.path)
                    discoverProject(path)
                }
            }
        }
    }
    private func discoverArchives(_ root: URL, depth: Int = 0) {
        for child in children(root) {
            if child.pathExtension == "xcarchive" {
                let info = plist(child.appendingPathComponent("Info.plist"))
                let properties = info["ApplicationProperties"] as? [String: Any] ?? [:]
                let name = info["Name"] as? String ?? child.deletingPathExtension().lastPathComponent
                let version = properties["CFBundleShortVersionString"] as? String ?? ""
                let build = properties["CFBundleVersion"] as? String ?? ""
                add(child, .archives, action: .trash, tier: .deep, manual: true, name: name,
                    owner: properties["CFBundleIdentifier"] as? String ?? name, evidence: ".xcarchive/Info.plist", root: root,
                    subtitle: [version, build.isEmpty ? "" : "Build " + build].filter { !$0.isEmpty }.joined(separator: " · "),
                    date: info["CreationDate"] as? Date, dateLabel: info["CreationDate"] is Date ? L10n.text("Archive Date") : L10n.text("Last Modified"))
            } else if depth < 1 && !FileSizer.isSymlink(child) && (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                discoverArchives(child, depth: depth + 1)
            } else { add(child, .archives, tier: .deep, manual: true, root: root) }
        }
    }
    private func discoverDeviceSupport(_ root: URL) {
        let values = children(root).sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }
        for (index, child) in values.enumerated() {
            add(child, .deviceSupport, action: .trash, tier: .deep, manual: true, owner: root.lastPathComponent, root: root, subtitle: index < config.keepDeviceSupportVersions ? L10n.text("Retained · Most recently modified versions: %@", String(describing: (config.keepDeviceSupportVersions))) : root.lastPathComponent, retainedDeviceSupport: index < config.keepDeviceSupportVersions)
        }
    }
    private func discoverCoreSimulator(_ root: URL) {
        for child in children(root) {
            switch child.lastPathComponent {
            case "Volumes": notices.append(ScanNotice(path: child.path, message: L10n.text("Runtime mounted views are excluded. Backing images or AssetData are counted instead.")))
            case "Devices":
                for device in children(child) {
                    let id = device.lastPathComponent
                    if let metadata = environment.devices[id] {
                        add(device, .simulators, action: .simulator(id), tier: .deep, manual: true, name: metadata.name, owner: metadata.runtime,
                            evidence: L10n.text("simctl list devices + device UUID"), root: child, subtitle: "\(metadata.state) · \(metadata.available ? L10n.text("Available") : L10n.text("Runtime Unavailable"))",
                            date: metadata.lastUsed, dateLabel: metadata.lastUsed == nil ? L10n.text("Last Modified") : L10n.text("Last Used (simctl)"))
                    } else if UUID(uuidString: id) != nil { add(device, .simulators, root: child, subtitle: L10n.text("Unregistered Device · Read Only")) }
                    else { add(device, .other, root: child) }
                }
            case "Caches": split(child, category: .caches, action: .trash, tier: .regular)
            case "Profiles":
                for profile in children(child) { split(profile, category: .components) }
            default: add(child, .components)
            }
        }
    }
    private func discoverXcodePreferences() {
        let preferences = plist(config.home.appendingPathComponent("Library/Preferences/com.apple.dt.Xcode.plist"))
        for (key, archive) in [("IDECustomDerivedDataLocation", false), ("IDEArchivePathOverride", true), ("IDECustomArchivesLocation", true)] {
            guard let path = preferences[key] as? String, !path.isEmpty else { continue }
            let expanded = (path as NSString).expandingTildeInPath
            if expanded.hasPrefix("/") {
                let url = URL(fileURLWithPath: expanded)
                if exists(url) { roots.append(url.path); archive ? discoverArchives(url) : discoverDerivedData(url) }
            } else { notices.append(ScanNotice(path: path, message: L10n.text("Xcode uses a relative location. Add the project's actual folder."))) }
        }
    }
    private func discoverAssets() {
        let root = URL(fileURLWithPath: "/System/Library/AssetsV2")
        guard exists(root) else { return }
        let names = ["Xcode", "Swift", "MetalToolchain", "SimulatorRuntime"]
        for asset in children(root) where names.contains(where: asset.lastPathComponent.contains) {
            roots.append(asset.path)
            split(asset, category: .components)
        }
    }
    private func deduplicate(_ input: [ScanCandidate]) -> [ScanCandidate] {
        var unique: [String: ScanCandidate] = [:]
        for var candidate in input {
            if !FileSizer.isSymlink(candidate.url) { candidate.url = PathRules.normalized(candidate.url); candidate.sourceRoot = PathRules.normalized(candidate.sourceRoot) }
            if let projectRoot = candidate.projectDataRoot { candidate.projectDataRoot = PathRules.normalized(projectRoot) }
            if let existing = unique[candidate.url.path] {
                if case .runtime = candidate.action { unique[candidate.url.path] = candidate }
                else if existing.category == .other && candidate.category != .other { unique[candidate.url.path] = candidate }
            } else { unique[candidate.url.path] = candidate }
        }
        return unique.values.sorted { a, b in a.url.path.count == b.url.path.count ? a.url.path < b.url.path : a.url.path.count > b.url.path.count }
    }
    private func plist(_ url: URL) -> [String: Any] {
        guard let data = try? Data(contentsOf: url), let value = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return [:] }
        return value
    }
}
