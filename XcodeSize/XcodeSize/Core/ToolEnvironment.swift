import Foundation
import Darwin

struct CommandResult: Sendable {
    var status: Int32
    var output: String
    var error: String
    var succeeded: Bool { status == 0 }
}

enum CommandRunner {
    /// File-backed output avoids pipe deadlocks for large simctl JSON responses.
    static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 20) -> CommandResult {
        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appendingPathComponent("XcodeSize-command-" + UUID().uuidString)
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: directory) }
            let output = directory.appendingPathComponent("stdout"), error = directory.appendingPathComponent("stderr")
            fm.createFile(atPath: output.path, contents: nil); fm.createFile(atPath: error.path, contents: nil)
            let outHandle = try FileHandle(forWritingTo: output), errHandle = try FileHandle(forWritingTo: error)
            defer { try? outHandle.close(); try? errHandle.close() }
            let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
            process.standardOutput = outHandle; process.standardError = errHandle; process.standardInput = FileHandle.nullDevice
            let semaphore = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in semaphore.signal() }
            try process.run()
            guard semaphore.wait(timeout: .now() + timeout) == .success else {
                process.terminate()
                if semaphore.wait(timeout: .now() + 2) != .success { kill(process.processIdentifier, SIGKILL); _ = semaphore.wait(timeout: .now() + 2) }
                return CommandResult(status: -1, output: "", error: L10n.text("The command timed out. Its outcome is uncertain; rescan to confirm."))
            }
            return CommandResult(status: process.terminationStatus, output: (try? String(contentsOf: output, encoding: .utf8)) ?? "", error: (try? String(contentsOf: error, encoding: .utf8)) ?? "")
        } catch { return CommandResult(status: -1, output: "", error: error.localizedDescription) }
    }
}

struct SimulatorDevice: Sendable {
    var id: String
    var name: String
    var runtime: String
    var path: String
    var state: String
    var available: Bool
    var lastUsed: Date?
}
struct SimulatorRuntime: Sendable {
    var id: String
    var runtimeIdentifier: String
    var name: String
    var path: String
    var deletable: Bool
    var reportedSize: Int64
    var lastUsed: Date?
}
struct ToolEnvironment: Sendable {
    var activeDeveloperPath: String?
    var runningTools: [String] = []
    var processStateKnown = false
    var simulatorStateKnown = false
    var bootedDevices: Set<String> = []
    var devices: [String: SimulatorDevice] = [:]
    var runtimes: [SimulatorRuntime] = []
    var notices: [String] = []
    var toolsBusy: Bool { !runningTools.isEmpty }

    static func inspect(includeSimulators: Bool = true) -> ToolEnvironment {
        var environment = ToolEnvironment()
        let developer = CommandRunner.run("/usr/bin/xcode-select", ["-p"], timeout: 5)
        if developer.succeeded { environment.activeDeveloperPath = developer.output.trimmingCharacters(in: .whitespacesAndNewlines) }
        let processes = CommandRunner.run("/bin/ps", ["-axo", "comm="], timeout: 5)
        environment.processStateKnown = processes.succeeded
        let watched: Set<String> = ["Xcode", "Simulator", "xcodebuild", "xctest", "XCTRunner", "swift-frontend", "swiftc", "clang", "clang++", "ibtool", "actool", "XCBBuildService", "SWBBuildService"]
        environment.runningTools = Array(Set(processes.output.split(separator: "\n").compactMap { line in
            let name = URL(fileURLWithPath: String(line).trimmingCharacters(in: .whitespaces)).lastPathComponent
            return watched.contains(name) || name.hasSuffix("-Runner") ? name : nil
        })).sorted()
        guard includeSimulators else { return environment }
        let devices = CommandRunner.run("/usr/bin/xcrun", ["simctl", "list", "devices", "-j"])
        if devices.succeeded, let data = devices.output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let groups = json["devices"] as? [String: [[String: Any]]] {
            environment.simulatorStateKnown = true
            for (runtime, values) in groups {
                for value in values {
                    guard let id = value["udid"] as? String, let state = value["state"] as? String else { continue }
                    let dataPath = value["dataPath"] as? String
                    let path = dataPath.map { URL(fileURLWithPath: $0).deletingLastPathComponent().path } ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/CoreSimulator/Devices/" + id).path
                    environment.devices[id] = SimulatorDevice(id: id, name: value["name"] as? String ?? id, runtime: runtime, path: path, state: state, available: value["isAvailable"] as? Bool ?? false, lastUsed: parseDate(value["lastUsedAt"] as? String))
                    if state != "Shutdown" { environment.bootedDevices.insert(id) }
                }
            }
        } else { environment.notices.append(L10n.text("The simulator list could not be read. Folders are still scanned, but device and runtime cleanup is disabled.")) }
        let runtimes = CommandRunner.run("/usr/bin/xcrun", ["simctl", "runtime", "list", "-j"])
        if runtimes.succeeded, let data = runtimes.output.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
            environment.runtimes = parseRuntimes(json)
        } else { environment.notices.append(L10n.text("The runtime list is unavailable. Only accessible runtime storage folders are identified.")) }
        return environment
    }
    static func parseRuntimes(_ json: [String: [String: Any]]) -> [SimulatorRuntime] {
        json.compactMap { key, value in
            guard let path = value["path"] as? String, path.hasPrefix("/"), let id = value["identifier"] as? String ?? Optional(key), UUID(uuidString: id) != nil else { return nil }
            return SimulatorRuntime(id: id, runtimeIdentifier: value["runtimeIdentifier"] as? String ?? "", name: "Simulator " + (value["version"] as? String ?? "") + " (" + (value["build"] as? String ?? id) + ")", path: path, deletable: value["deletable"] as? Bool == true, reportedSize: (value["sizeBytes"] as? NSNumber)?.int64Value ?? 0, lastUsed: parseDate(value["lastUsedAt"] as? String))
        }
    }
    static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds); return formatter.date(from: string)
    }
}
