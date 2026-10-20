import Foundation
import Darwin

/// One physical owner per device/inode. Symlinks and mounted filesystems are never followed.
enum FileSizer {
    static func measure(_ url: URL, seen: inout Set<FileIdentity>, excluded: [URL] = [], progress: ((Int) -> Void)? = nil) -> Measurement {
        var result = Measurement()
        var rootStat = stat()
        guard lstat(url.path, &rootStat) == 0 else { result.unreadable = 1; return result }
        result.identity = identity(rootStat)
        let rootDevice = rootStat.st_dev
        let sizeKeys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .totalFileSizeKey]
        func add(_ entry: URL, _ info: stat) {
            let path = entry.path
            result.files += 1
            let date = Date(timeIntervalSince1970: Double(info.st_mtimespec.tv_sec) + Double(info.st_mtimespec.tv_nsec) / 1e9)
            result.newestModification = max(result.newestModification ?? .distantPast, date)
            // Commutative signature: stable across directory enumeration order and detects same-size replacements.
            var hash: UInt64 = 14695981039346656037
            let stamp = "\(path)|\(info.st_dev)|\(info.st_ino)|\(info.st_size)|\(info.st_mtimespec.tv_sec)|\(info.st_mtimespec.tv_nsec)|\(info.st_ctimespec.tv_sec)|\(info.st_ctimespec.tv_nsec)"
            for byte in stamp.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
            result.fingerprint &+= hash
            let key = identity(info)
            if seen.insert(key).inserted {
                // st_blocks omits compressed resource forks on macOS. Foundation's total
                // sizes include those forks. Never request target properties for a link.
                let resources = (info.st_mode & S_IFMT) == S_IFLNK ? nil : try? entry.resourceValues(forKeys: sizeKeys)
                result.allocated += resources?.totalFileAllocatedSize.map(Int64.init) ?? Int64(info.st_blocks) * 512
                result.logical += resources?.totalFileSize.map(Int64.init) ?? Int64(info.st_size)
            } else { result.hardLinks += 1 }
        }
        add(url, rootStat)
        guard (rootStat.st_mode & S_IFMT) == S_IFDIR else { return result }
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: Array(sizeKeys), options: [], errorHandler: { _, _ in result.unreadable += 1; return true }) else {
            result.unreadable += 1; return result
        }
        for case let child as URL in enumerator {
            if Task.isCancelled { result.cancelled = true; break }
            var info = stat()
            guard lstat(child.path, &info) == 0 else { result.unreadable += 1; continue }
            let isDirectory = (info.st_mode & S_IFMT) == S_IFDIR
            if excluded.contains(where: { PathRules.contains($0.path, child.path) }) {
                if isDirectory { enumerator.skipDescendants() }
                continue
            }
            guard info.st_dev == rootDevice else { if isDirectory { enumerator.skipDescendants() }; continue }
            // Foundation never descends symbolic links. Calling skipDescendants on a
            // non-directory can instead suppress traversal of a sibling subtree.
            add(child, info)
            if result.files % 2048 == 0 { progress?(result.files) }
        }
        return result
    }
    static func measure(_ url: URL) -> Measurement { var seen = Set<FileIdentity>(); return measure(url, seen: &seen) }
    static func identity(_ info: stat) -> FileIdentity { FileIdentity(device: UInt64(info.st_dev), inode: UInt64(info.st_ino)) }
    static func isSymlink(_ url: URL) -> Bool { var s = stat(); return lstat(url.path, &s) != 0 || (s.st_mode & S_IFMT) == S_IFLNK }
    static func fileSystemType(_ url: URL) -> String? {
        var info = statfs()
        guard statfs(url.path, &info) == 0 else { return nil }
        return withUnsafeBytes(of: info.f_fstypename) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
    static func isMountPoint(_ url: URL) -> Bool {
        var current = stat(), parent = stat()
        guard lstat(url.path, &current) == 0, lstat(url.deletingLastPathComponent().path, &parent) == 0 else { return false }
        return current.st_dev != parent.st_dev
    }
}

struct DirectoryEntry: Identifiable, Sendable {
    var id: String { url.path }
    var url: URL
    var name: String
    var measurement: Measurement
    var isDirectory: Bool
    var explanation: String
}

enum DirectoryBrowser {
    static func children(of url: URL) throws -> [DirectoryEntry] {
        let fm = FileManager.default
        let urls = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [])
        var seen = Set<FileIdentity>()
        var entries: [DirectoryEntry] = []
        for child in urls {
            if Task.isCancelled { break }
            let mountedView = FileSizer.isMountPoint(child) || FileSizer.fileSystemType(child) == "devicefs"
            let measurement = mountedView ? Measurement() : FileSizer.measure(child, seen: &seen)
            entries.append(DirectoryEntry(url: child, name: child.lastPathComponent, measurement: measurement,
                                          isDirectory: !mountedView && (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true && !FileSizer.isSymlink(child),
                                          explanation: mountedView ? L10n.text("Mounted view, not counted twice. View it in Finder.") : explanation(child.lastPathComponent)))
        }
        return entries.sorted { $0.measurement.allocated > $1.measurement.allocated }
    }
    static func explanation(_ name: String) -> String {
        switch name {
        case "Build": L10n.text("Build products and intermediates")
        case "Products": L10n.text("Apps, extensions, libraries, resources, and debug symbols")
        case "Intermediates.noindex", "Intermediates": L10n.text("Compiler and linker intermediates; build database")
        case "Index.noindex", "Index": L10n.text("Source index, completion, and symbol navigation")
        case "SourcePackages": L10n.text("Swift package dependencies for this project")
        case "checkouts": L10n.text("Source working copies of package dependencies")
        case "repositories": L10n.text("Dependency Git repositories and download caches")
        case "artifacts": L10n.text("Downloaded and extracted binary dependencies")
        case "Logs": L10n.text("Build, test, and tool logs")
        case "Test": L10n.text("Test results, coverage, and attachments")
        case "dSYMs": L10n.text("Debug symbols matching the released binary")
        case "BCSymbolMaps": L10n.text("Legacy bitcode symbol maps")
        case "Contents": L10n.text("App or component contents, included in the installation size")
        case "SDKs", "Platforms": L10n.text("Platform SDKs and development support")
        case "Toolchains": L10n.text("Swift, Clang, and other compiler toolchains")
        case "data": L10n.text("Device app sandboxes, databases, and settings")
        case "XCBuildData": L10n.text("Build database and task state")
        case "DerivedSources": L10n.text("Generated source files and headers")
        case "Objects-normal": L10n.text("Compiled object files by architecture")
        case "PrecompiledHeaders": L10n.text("Precompiled headers")
        default: name.hasSuffix(".app") ? L10n.text("Built or installed app bundle") : name.hasSuffix(".dSYM") ? L10n.text("Debug symbol bundle") : name.hasSuffix(".xcresult") ? L10n.text("Test or build result bundle") : L10n.text("Part of the parent folder. Browse to inspect its contents.")
        }
    }
}
