import Foundation

struct ArchiveMetadata: Codable, Sendable {
    var bundleID: String
    var version: String
    var build: String
    var platform: String
    var team: String
    // Missing identity or non-numeric versions are never guessed by a retention rule.
    var groupKey: String? {
        guard !bundleID.isEmpty, !platform.isEmpty, !team.isEmpty else { return nil }
        return [bundleID, platform, team].joined(separator: "\u{0}")
    }
    var numericVersion: [Int]? {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }) else { return nil }
        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == parts.count else { return nil }
        var result = numbers
        while result.count > 1 && result.last == 0 { result.removeLast() }
        return result
    }
    static func read(_ archive: URL) -> ArchiveMetadata {
        let info = readPlist(archive.appendingPathComponent("Info.plist"), within: archive)
        let properties = info["ApplicationProperties"] as? [String: Any] ?? [:]
        var app: [String: Any] = [:]
        if let relative = properties["ApplicationPath"] as? String {
            let product = archive.appendingPathComponent("Products").appendingPathComponent(relative)
            app = readPlist(product.appendingPathComponent("Info.plist"), within: archive)
            if app.isEmpty { app = readPlist(product.appendingPathComponent("Contents/Info.plist"), within: archive) }
        }
        return ArchiveMetadata(bundleID: properties["CFBundleIdentifier"] as? String ?? app["CFBundleIdentifier"] as? String ?? "",
                               version: properties["CFBundleShortVersionString"] as? String ?? app["CFBundleShortVersionString"] as? String ?? "",
                               build: properties["CFBundleVersion"] as? String ?? app["CFBundleVersion"] as? String ?? "",
                               platform: app["DTPlatformName"] as? String ?? properties["DTPlatformName"] as? String ?? "",
                               team: properties["Team"] as? String ?? "")
    }
    private static func readPlist(_ url: URL, within root: URL) -> [String: Any] {
        guard PathRules.contains(root.path, PathRules.normalized(url).path),
              let data = try? Data(contentsOf: url),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return [:] }
        return info
    }
}

enum ArchiveRetention {
    /// Zero explicitly selects all unprotected archives, including unidentified archives.
    /// Other rules keep every build of each retained marketing version, per app/platform/team.
    static func candidates(_ items: [StorageItem], keeping count: Int, protectedPaths: Set<String>) -> Set<String> {
        guard count >= 0 else { return [] }
        let archives = items.filter { item in
            item.url.pathExtension == "xcarchive" && item.category == .archives && item.complete && item.action == .trash
        }
        func protected(_ item: StorageItem) -> Bool {
            protectedPaths.contains { PathRules.contains($0, item.id) || PathRules.contains(item.id, $0) }
        }
        if count == 0 { return Set(archives.filter { !protected($0) }.map(\.id)) }
        let groups = Dictionary(grouping: archives.filter { $0.archive?.groupKey != nil && $0.archive?.numericVersion != nil }, by: { $0.archive!.groupKey! })
        var result = Set<String>()
        for group in groups.values {
            let versions = Set(group.compactMap { $0.archive?.numericVersion }).sorted { lhs, rhs in
                for index in 0..<max(lhs.count, rhs.count) {
                    let a = index < lhs.count ? lhs[index] : 0, b = index < rhs.count ? rhs[index] : 0
                    if a != b { return a > b }
                }
                return false
            }
            let retained = Set(versions.prefix(count))
            for item in group where !protected(item) {
                if let version = item.archive?.numericVersion, !retained.contains(version) { result.insert(item.id) }
            }
        }
        return result
    }
}

struct ArchiveSymbolReport: Sendable {
    var binaries = Set<String>()
    var symbols = Set<String>()
    var failures = 0
    var missing: Set<String> { binaries.subtracting(symbols) }
    var summary: String {
        if failures > 0 || binaries.isEmpty { return L10n.text("Symbol check incomplete. No backup or upload status is verified.") }
        if !missing.isEmpty { return L10n.text("Missing matching dSYMs: %@. Older releases may need these exact symbols.", String(missing.count)) }
        return L10n.text("All discovered binary UUIDs have matching symbols in this archive. This does not verify a backup or upload.")
    }
    static func parseUUIDs(_ output: String) -> Set<String> {
        var result = Set<String>()
        for line in output.split(separator: "\n") {
            let parts = line.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 3, parts[0] == "UUID:", let id = UUID(uuidString: String(parts[1])), parts[2].hasPrefix("(") else { continue }
            result.insert(id.uuidString + " " + parts[2])
        }
        return result
    }
    static func inspect(_ archive: URL) -> ArchiveSymbolReport {
        var report = ArchiveSymbolReport()
        let fm = FileManager.default
        guard !FileSizer.isSymlink(archive) else { report.failures = 1; return report }
        let device = FileSizer.measureIdentity(archive)?.device
        for (folder, isSymbol) in [("Products", false), ("dSYMs", true)] {
            let root = archive.appendingPathComponent(folder)
            guard !FileSizer.isSymlink(root), FileSizer.measureIdentity(root)?.device == device, let entries = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey], errorHandler: { _, _ in report.failures += 1; return true }) else { report.failures += 1; continue }
            for case let file as URL in entries {
                if Task.isCancelled { report.failures += 1; return report }
                guard !FileSizer.isSymlink(file), FileSizer.measureIdentity(file)?.device == device else {
                    if !FileSizer.isSymlink(file), (try? file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { entries.skipDescendants() }
                    continue
                }
                guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
                guard let handle = try? FileHandle(forReadingFrom: file) else { report.failures += 1; continue }
                let magic: [UInt8]
                do {
                    magic = Array(try handle.read(upToCount: 4) ?? Data())
                    try handle.close()
                } catch {
                    try? handle.close(); report.failures += 1; continue
                }
                guard [[0xcf,0xfa,0xed,0xfe], [0xce,0xfa,0xed,0xfe], [0xfe,0xed,0xfa,0xcf], [0xfe,0xed,0xfa,0xce], [0xca,0xfe,0xba,0xbe], [0xbe,0xba,0xfe,0xca], [0xca,0xfe,0xba,0xbf], [0xbf,0xba,0xfe,0xca]].contains(magic) else { continue }
                let command = CommandRunner.run("/usr/bin/xcrun", ["dwarfdump", "--uuid", file.path], timeout: 10)
                let ids = parseUUIDs(command.output)
                if !command.succeeded || ids.isEmpty { report.failures += 1 }
                if isSymbol { report.symbols.formUnion(ids) } else { report.binaries.formUnion(ids) }
            }
        }
        return report
    }
}
