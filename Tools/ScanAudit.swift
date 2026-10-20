import Foundation

/// Read-only companion for inspecting scan coverage without launching the app.
@main struct ScanAudit {
    static func main() throws {
        let started = Date()
        let snapshot = StorageScanner(configuration: ScanConfiguration()).scan()
        let categories = StorageCategory.allCases.map { category in
            let items = snapshot.items.filter { $0.category == category }
            return ["category": category.rawValue, "title": category.title, "items": items.count, "allocatedBytes": items.reduce(Int64(0)) { $0 + $1.size }] as [String: Any]
        }
        let report: [String: Any] = [
            "readOnly": true,
            "elapsedSeconds": Date().timeIntervalSince(started),
            "totalAllocatedBytes": snapshot.total,
            "items": snapshot.items.map { item in ["path": item.id, "name": item.name, "category": item.category.rawValue, "allocatedBytes": item.size, "logicalBytes": item.measurement.logical, "entries": item.measurement.files, "unreadable": item.measurement.unreadable, "action": item.action.title, "manualOnly": item.manualOnly, "purpose": item.purpose] as [String: Any] },
            "categories": categories,
            "roots": snapshot.scannedRoots,
            "notices": snapshot.notices.map { ["path": $0.path, "message": $0.message, "error": $0.isError] as [String: Any] },
            "runningTools": snapshot.environment.runningTools
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        if CommandLine.arguments.count == 2 { try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1])) }
        else { FileHandle.standardOutput.write(data) }
    }
}
