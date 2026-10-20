import Foundation

struct CleanupRecord: Identifiable, Codable, Sendable {
    var id = UUID()
    var date = Date()
    var name: String
    var path: String
    var action: String
    var bytes: Int64
    var outcome: Outcome
    var message: String
    var trashPath: String?
    enum Outcome: String, Codable, Sendable { case trashed, removed, skipped, failed }
}
struct CleanupPlan: Identifiable, Sendable {
    var id = UUID()
    var createdAt = Date()
    var tier: CleanupTier
    var items: [StorageItem]
    var bytes: Int64 { items.reduce(0) { $0 + $1.size } }
    var hasPermanentActions: Bool { items.contains { $0.action.isPermanent } }
    var hasIrreplaceableData: Bool { items.contains { $0.requiresDeepCleanup } }
}

enum CleanupError: LocalizedError {
    case rejected(String)
    var errorDescription: String? { switch self { case .rejected(let reason): reason } }
}

struct CleanupEngine: Sendable {
    var inspect: @Sendable () -> ToolEnvironment = { ToolEnvironment.inspect() }
    var command: @Sendable (String, [String]) -> CommandResult = { CommandRunner.run($0, $1, timeout: 120) }
    var trash: @Sendable (URL) throws -> URL? = { url in
        var result: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &result)
        return result as URL?
    }

    /// Revalidates every operation against its scanned identity and the current tool state.
    func execute(_ plan: CleanupPlan, protectedPaths: Set<String>, emit: @Sendable (CleanupRecord) -> Void = { _ in }) -> [CleanupRecord] {
        var records: [CleanupRecord] = []
        var processed: [String] = []
        for item in plan.items {
            var record = CleanupRecord(name: item.name, path: item.id, action: item.action.title, bytes: item.size, outcome: .skipped, message: "")
            if Task.isCancelled { record.message = L10n.text("Canceled. Completed operations are not automatically reversed.") }
            else {
                do {
                    guard !processed.contains(where: { PathRules.contains($0, item.id) || PathRules.contains(item.id, $0) }) else { throw CleanupError.rejected(L10n.text("Overlaps another cleanup item. Skipped.")) }
                    try validatePath(item)
                    let environment = inspect()
                    if let reason = CleanupPolicy.blockReason(item, tier: plan.tier, protectedPaths: protectedPaths, environment: environment) { throw CleanupError.rejected(reason) }
                    let current = FileSizer.measure(item.url)
                    guard !current.cancelled, current.unreadable == 0, current.identity == item.measurement.identity,
                          current.fingerprint == item.measurement.fingerprint, current.files == item.measurement.files else {
                        throw CleanupError.rejected(L10n.text("Files have changed since the scan or cannot be read completely. Rescan before cleaning."))
                    }
                    // Probe again after a potentially expensive size walk.
                    let latest = inspect()
                    if let reason = CleanupPolicy.blockReason(item, tier: plan.tier, protectedPaths: protectedPaths, environment: latest) { throw CleanupError.rejected(reason) }
                    switch item.action {
                    case .trash:
                        record.trashPath = try trash(item.url)?.path
                        record.outcome = .trashed; record.message = L10n.text("Moved to Trash. Space is not freed until Trash is emptied.")
                    case .simulator(let id):
                        guard UUID(uuidString: id) != nil, let device = latest.devices[id], device.state == "Shutdown",
                              PathRules.normalized(URL(fileURLWithPath: device.path)) == item.url else { throw CleanupError.rejected(L10n.text("Simulator registration changed. Skipped.")) }
                        let result = command("/usr/bin/xcrun", ["simctl", "delete", id])
                        guard result.succeeded else { throw NSError(domain: "simctl", code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: result.error.isEmpty ? L10n.text("simctl removal failed. Rescan to confirm the current state.") : result.error]) }
                        record.outcome = .removed; record.message = L10n.text("Simulator removed. App sandboxes and local test data cannot be recovered automatically.")
                    case .runtime(let id):
                        guard UUID(uuidString: id) != nil, let runtime = latest.runtimes.first(where: { $0.id == id }), runtime.deletable,
                              PathRules.normalized(URL(fileURLWithPath: runtime.path)) == item.url else { throw CleanupError.rejected(L10n.text("Runtime registration changed. Skipped.")) }
                        let result = command("/usr/bin/xcrun", ["simctl", "runtime", "delete", id])
                        guard result.succeeded else { throw NSError(domain: "simctl", code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: result.error.isEmpty ? L10n.text("Runtime removal failed. Rescan to confirm the current state.") : result.error]) }
                        record.outcome = .removed; record.message = L10n.text("Runtime removed using Apple tools. Download it again when needed.")
                    case .readOnly: throw CleanupError.rejected(L10n.text("Browsing only"))
                    }
                    processed.append(item.id)
                } catch let error as CleanupError { record.message = error.localizedDescription }
                catch { record.outcome = .failed; record.message = error.localizedDescription }
            }
            records.append(record); emit(record)
        }
        return records
    }

    func validatePath(_ item: StorageItem) throws {
        let path = item.url.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let forbidden = ["/", "/Applications", "/System", "/Library", "/Library/Developer", "/Users", home, home + "/Library", home + "/Library/Developer", home + "/Library/Developer/Xcode", home + "/Library/Developer/CoreSimulator", home + "/Documents", home + "/Desktop", home + "/Downloads"]
        guard !forbidden.contains(path), !path.hasPrefix("/System/") || item.action.isPermanent else { throw CleanupError.rejected(L10n.text("This is a protected system or container directory.")) }
        guard !FileSizer.isSymlink(item.url), PathRules.normalized(item.url).path == path else { throw CleanupError.rejected(L10n.text("The path contains a symbolic link or has changed.")) }
        guard PathRules.contains(PathRules.normalized(item.sourceRoot).path, path), path != item.sourceRoot.path else { throw CleanupError.rejected(L10n.text("The path is outside its scan scope or is the scan root itself.")) }
        guard item.measurement.identity != nil else { throw CleanupError.rejected(L10n.text("File identity information is missing.")) }
        guard item.action != .readOnly else { throw CleanupError.rejected(L10n.text("This folder is read-only.")) }
    }
}
