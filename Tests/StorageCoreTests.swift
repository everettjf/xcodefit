import XCTest
import Darwin
@testable import XcodeSizeCore

final class StorageCoreTests: XCTestCase {
    var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("XcodeSizeTests-" + UUID().uuidString).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    @discardableResult func file(_ relative: String, bytes: Int = 4096) throws -> URL {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 65, count: bytes).write(to: url)
        return url
    }
    func item(_ url: URL, category: StorageCategory = .caches, action: CleanupAction = .trash) -> StorageItem {
        StorageItem(url: url, name: url.lastPathComponent, category: category, purpose: category.purpose, owner: "Fixture", evidence: "Fixture", measurement: FileSizer.measure(url), action: action, minimumTier: .simple, date: Date(timeIntervalSinceNow: -100 * 86400), sourceRoot: root)
    }
    var idle: ToolEnvironment { ToolEnvironment(processStateKnown: true, simulatorStateKnown: true) }

    func testHardlinksCountOnceAndSymlinksNeverTraverse() throws {
        let original = try file("tree/a")
        try FileManager.default.linkItem(at: original, to: root.appendingPathComponent("tree/b"))
        _ = try file("outside/large", bytes: 500000)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("tree/link"), withDestinationURL: root.appendingPathComponent("outside"))
        let m = FileSizer.measure(root.appendingPathComponent("tree"))
        XCTAssertEqual(m.hardLinks, 1)
        XCTAssertLessThan(m.logical, 100000)
        XCTAssertEqual(m.files, 4) // root, original, hardlink, symlink
    }
    func testFingerprintDetectsSameSizeRewrite() throws {
        let url = try file("payload")
        let before = FileSizer.measure(url)
        try Data(repeating: 66, count: 4096).write(to: url, options: .atomic)
        let after = FileSizer.measure(url)
        XCTAssertNotEqual(before.fingerprint, after.fingerprint)
    }
    func testSymlinkDoesNotHideFollowingSiblingDirectory() throws {
        _ = try file("sdk/SDKs/z-real/usr/lib/one")
        _ = try file("sdk/SDKs/z-real/usr/lib/two")
        let link = root.appendingPathComponent("sdk/SDKs/a-link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root.appendingPathComponent("sdk/SDKs/z-real"))
        let measurement = FileSizer.measure(root.appendingPathComponent("sdk"))
        XCTAssertEqual(measurement.files, 8) // root, SDKs, link, real, usr, lib, one, two
        XCTAssertGreaterThanOrEqual(measurement.allocated, 8192)
    }
    func testScannerCoversUnknownDataArchivesAndCustomPathsWithoutDoubleCounting() throws {
        _ = try file("home/Library/Developer/Xcode/DerivedData/Demo-hash/Build/Products/Demo.app/app")
        _ = try file("home/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/cache")
        _ = try file("home/Library/Developer/Xcode/Archives/2026-01-01/Demo.xcarchive/dSYMs/Demo")
        _ = try file("home/Library/Developer/Xcode/UserData/CodeSnippets/snippet")
        _ = try file("home/Library/Developer/Unexpected/file")
        let dd = root.appendingPathComponent("home/Library/Developer/Xcode/DerivedData")
        let config = ScanConfiguration(home: root.appendingPathComponent("home"), systemDeveloper: root.appendingPathComponent("system"), applicationRoots: [], customRoots: [CustomRoot(url: dd, kind: .derivedData)], discoverEnvironment: false)
        let snapshot = StorageScanner(configuration: config).scan()
        XCTAssertEqual(Set(snapshot.items.map(\.id)).count, snapshot.items.count)
        XCTAssertTrue(snapshot.items.contains { $0.category == .builds })
        XCTAssertTrue(snapshot.items.contains { $0.category == .archives && $0.manualOnly })
        XCTAssertTrue(snapshot.items.contains { $0.name == "CodeSnippets" && $0.action == .readOnly })
        XCTAssertTrue(snapshot.items.contains { $0.name == "Unexpected" && $0.category == .other })
        let totalFileBytes = snapshot.total
        XCTAssertGreaterThan(totalFileBytes, 0)
        XCTAssertLessThan(totalFileBytes, 100000)
    }
    func testTiersAreAdditiveAndDeepNeverAutoSelectsArchives() throws {
        var build = item(try file("build"), category: .builds)
        build.minimumTier = .regular
        let settings = CleanupSettings()
        XCTAssertFalse(CleanupPolicy.recommended(build, tier: .simple, settings: settings, protectedPaths: [], environment: idle))
        XCTAssertTrue(CleanupPolicy.recommended(build, tier: .regular, settings: settings, protectedPaths: [], environment: idle))
        build.date = Date()
        XCTAssertFalse(CleanupPolicy.recommended(build, tier: .regular, settings: settings, protectedPaths: [], environment: idle))
        XCTAssertTrue(CleanupPolicy.recommended(build, tier: .deep, settings: settings, protectedPaths: [], environment: idle))
        var archive = item(try file("archive"), category: .archives)
        archive.minimumTier = .deep; archive.manualOnly = true
        XCTAssertFalse(CleanupPolicy.recommended(archive, tier: .deep, settings: settings, protectedPaths: [], environment: idle))
    }
    func testProtectedAncestorAndDescendantBothBlock() throws {
        let value = item(try file("project/cache"))
        XCTAssertNotNil(CleanupPolicy.blockReason(value, tier: .simple, protectedPaths: [root.appendingPathComponent("project").path], environment: idle))
        XCTAssertNotNil(CleanupPolicy.blockReason(value, tier: .simple, protectedPaths: [value.id + "/keep"], environment: idle))
    }
    func testCleanupMovesOnlyUnchangedFixtureAndReportsTrashHonestly() throws {
        let value = item(try file("cache"))
        let idle = idle, destination = root.appendingPathComponent("fixture-trash")
        let engine = CleanupEngine(inspect: { idle }, trash: { url in try FileManager.default.moveItem(at: url, to: destination); return destination })
        let records = engine.execute(CleanupPlan(tier: .simple, items: [value]), protectedPaths: [])
        XCTAssertEqual(records.first?.outcome, .trashed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertTrue(records.first?.message.contains("until Trash is emptied") == true)
    }
    func testCleanupRefusesChangesBusyToolsAndUnknownState() throws {
        let value = item(try file("cache"))
        try Data(repeating: 66, count: 4096).write(to: value.url, options: .atomic)
        let idle = idle
        let engine = CleanupEngine(inspect: { idle }, trash: { _ in XCTFail("Changed file must not be trashed"); return nil })
        XCTAssertEqual(engine.execute(CleanupPlan(tier: .simple, items: [value]), protectedPaths: []).first?.outcome, .skipped)
        var busy = idle; busy.runningTools = ["xcodebuild"]
        XCTAssertNotNil(CleanupPolicy.blockReason(value, tier: .simple, protectedPaths: [], environment: busy))
        XCTAssertNotNil(CleanupPolicy.blockReason(value, tier: .simple, protectedPaths: [], environment: ToolEnvironment()))
    }
    func testCleanupRejectsSymlinkSwapAndContainerRoots() throws {
        let value = item(try file("cache"))
        try FileManager.default.removeItem(at: value.url)
        let other = try file("other")
        try FileManager.default.createSymbolicLink(at: value.url, withDestinationURL: other)
        XCTAssertThrowsError(try CleanupEngine().validatePath(value))
        var container = value; container.url = URL(fileURLWithPath: "/Applications")
        XCTAssertThrowsError(try CleanupEngine().validatePath(container))
    }
    func testIncompleteScanCannotClean() throws {
        var value = item(try file("cache")); value.measurement.unreadable = 1
        XCTAssertNotNil(CleanupPolicy.blockReason(value, tier: .deep, protectedPaths: [], environment: idle))
    }
    func testRuntimeParserUsesBackingStoreInsteadOfMountPath() {
        let id = UUID().uuidString
        let values: [String: [String: Any]] = [id: ["identifier": id, "path": "/System/Library/AssetsV2/runtime/AssetData", "mountPath": "/Library/Developer/CoreSimulator/Volumes/iOS_1", "runtimeIdentifier": "com.apple.CoreSimulator.SimRuntime.iOS-18-0", "deletable": true, "version": "18.0", "sizeBytes": 8000000000]]
        let runtime = ToolEnvironment.parseRuntimes(values).first
        XCTAssertEqual(runtime?.path, "/System/Library/AssetsV2/runtime/AssetData")
        XCTAssertEqual(runtime?.reportedSize, 8000000000)
    }
    func testSimulatorRemovalUsesExactRegisteredUUID() throws {
        let uuid = UUID().uuidString
        let url = try file("device")
        var environment = idle
        environment.devices[uuid] = SimulatorDevice(id: uuid, name: "Fixture", runtime: "FixtureOS", path: url.path, state: "Shutdown", available: true)
        let state = environment
        let value = item(url, category: .simulators, action: .simulator(uuid))
        let engine = CleanupEngine(inspect: { state }, command: { executable, arguments in
            XCTAssertEqual(executable, "/usr/bin/xcrun")
            XCTAssertEqual(arguments, ["simctl", "delete", uuid])
            return CommandResult(status: 0, output: "", error: "")
        }, trash: { _ in XCTFail("Devices must use simctl"); return nil })
        XCTAssertEqual(engine.execute(CleanupPlan(tier: .deep, items: [value]), protectedPaths: []).first?.outcome, .removed)
    }

    func testProjectPackagesAndIndexesHaveSeparateCategoriesAndSharedProtectionRoot() throws {
        let prefix = "home/Library/Developer/Xcode/DerivedData/App-hash"
        _ = try file(prefix + "/Build/Products/App")
        _ = try file(prefix + "/SourcePackages/checkouts/dependency/file")
        _ = try file(prefix + "/Index.noindex/DataStore/index")
        let data = try PropertyListSerialization.data(fromPropertyList: ["WorkspacePath": "/Projects/App.xcodeproj"], format: .xml, options: 0)
        try data.write(to: root.appendingPathComponent(prefix + "/info.plist"))
        let configuration = ScanConfiguration(home: root.appendingPathComponent("home"), systemDeveloper: root.appendingPathComponent("system"), applicationRoots: [], discoverEnvironment: false)
        let snapshot = StorageScanner(configuration: configuration).scan()
        let packages = try XCTUnwrap(snapshot.items.first { $0.category == .packages })
        let build = try XCTUnwrap(snapshot.items.first { $0.category == .builds })
        XCTAssertEqual(packages.protectionPath, build.protectionPath)
        XCTAssertEqual(packages.owner, "/Projects/App.xcodeproj")
        XCTAssertNil(CleanupPolicy.blockReason(build, tier: .regular, protectedPaths: [], environment: idle))
        XCTAssertNotNil(CleanupPolicy.blockReason(packages, tier: .regular, protectedPaths: [build.protectionPath], environment: idle))
        XCTAssertFalse(snapshot.items.contains { $0.url == root.appendingPathComponent(prefix) })
    }

    func testNativeTrashAPIOnDisposableFixtureAndRestore() throws {
        let url = try file("native-trash-fixture")
        let value = item(url), state = idle
        let records = CleanupEngine(inspect: { state }).execute(CleanupPlan(tier: .simple, items: [value]), protectedPaths: [])
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.outcome, .trashed)
        let trashPath = try XCTUnwrap(record.trashPath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        try FileManager.default.moveItem(at: URL(fileURLWithPath: trashPath), to: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testCommandFailureIsReportedAsFailureAndDoesNotFallBackToTrash() throws {
        let uuid = UUID().uuidString, url = try file("device-failure")
        var state = idle
        state.devices[uuid] = SimulatorDevice(id: uuid, name: "Fixture", runtime: "FixtureOS", path: url.path, state: "Shutdown", available: true)
        let environment = state
        let engine = CleanupEngine(inspect: { environment }, command: { _, _ in CommandResult(status: 1, output: "", error: "Fixture command failed") }, trash: { _ in XCTFail("Must not fall back to file deletion"); return nil })
        let records = engine.execute(CleanupPlan(tier: .deep, items: [item(url, category: .simulators, action: .simulator(uuid))]), protectedPaths: [])
        XCTAssertEqual(records.first?.outcome, .failed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testRetainedDeviceSupportIsNeverRecommended() throws {
        var support = item(try file("support"), category: .deviceSupport)
        support.minimumTier = .regular; support.subtitle = "An arbitrary translated label"; support.retainedDeviceSupport = true
        XCTAssertFalse(CleanupPolicy.recommended(support, tier: .deep, settings: CleanupSettings(), protectedPaths: [], environment: idle))
        support.retainedDeviceSupport = false
        XCTAssertTrue(CleanupPolicy.recommended(support, tier: .regular, settings: CleanupSettings(), protectedPaths: [], environment: idle))
    }

    func testCancelledScanCannotYieldCompleteMeasurements() async throws {
        _ = try file("many/a")
        let url = root.appendingPathComponent("many")
        let worker = Task.detached {
            while !Task.isCancelled { await Task.yield() }
            return FileSizer.measure(url)
        }
        worker.cancel()
        let result = await worker.value
        XCTAssertTrue(result.cancelled)
    }

    func testResourceForkStorageIsIncludedAndAgreesWithDu() throws {
        let url = try file("resource-fork", bytes: 1024)
        let fork = Data(repeating: 42, count: 131072)
        let result = fork.withUnsafeBytes { bytes in
            setxattr(url.path, "com.apple.ResourceFork", bytes.baseAddress, bytes.count, 0, 0)
        }
        guard result == 0 else { throw XCTSkip("This filesystem does not support a fixture resource fork") }
        let measurement = FileSizer.measure(url)
        XCTAssertGreaterThanOrEqual(measurement.allocated, 131072)
        XCTAssertGreaterThanOrEqual(measurement.logical, 132096)
        let du = CommandRunner.run("/usr/bin/du", ["-sk", url.path])
        let kilobytes = try XCTUnwrap(Int64(du.output.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""))
        XCTAssertLessThan(abs(measurement.allocated - kilobytes * 1024), 1024)
    }

    func testCustomSingleProjectDerivedDataAndKnownSwiftOutputsAreDiscovered() throws {
        _ = try file("custom/Build/Products/App")
        _ = try file("custom/Logs/Build/activity")
        _ = try file("custom/SourcePackages/checkouts/Dependency/file")
        _ = try file("Projects/App/Package.swift")
        _ = try file("Projects/App/.build/debug/App")
        let workspace = root.appendingPathComponent("Projects/App/App.xcodeproj").path
        let data = try PropertyListSerialization.data(fromPropertyList: ["WorkspacePath": workspace], format: .xml, options: 0)
        try data.write(to: root.appendingPathComponent("custom/info.plist"))
        let configuration = ScanConfiguration(home: root.appendingPathComponent("empty-home"), systemDeveloper: root.appendingPathComponent("empty-system"), applicationRoots: [], customRoots: [CustomRoot(url: root.appendingPathComponent("custom"), kind: .derivedData)], discoverEnvironment: false)
        let snapshot = StorageScanner(configuration: configuration).scan()
        XCTAssertTrue(snapshot.items.contains { $0.url == root.appendingPathComponent("custom/Build") && $0.category == .builds })
        XCTAssertTrue(snapshot.items.contains { $0.url == root.appendingPathComponent("custom/SourcePackages") && $0.category == .packages })
        XCTAssertTrue(snapshot.items.contains { $0.url == root.appendingPathComponent("Projects/App/.build") && $0.category == .builds })
    }

    func testRuntimeRemovalUsesRegisteredImageUUIDAndRejectsBootedDevices() throws {
        let id = UUID().uuidString, url = try file("runtime/AssetData/image")
        var state = idle
        state.runtimes = [SimulatorRuntime(id: id, runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.Fixture", name: "Fixture", path: url.path, deletable: true, reportedSize: 4096)]
        let environment = state
        let value = item(url, category: .components, action: .runtime(id))
        let engine = CleanupEngine(inspect: { environment }, command: { path, arguments in
            XCTAssertEqual(path, "/usr/bin/xcrun")
            XCTAssertEqual(arguments, ["simctl", "runtime", "delete", id])
            return CommandResult(status: 0, output: "", error: "")
        }, trash: { _ in XCTFail("Runtime images must use simctl"); return nil })
        XCTAssertEqual(engine.execute(CleanupPlan(tier: .deep, items: [value]), protectedPaths: []).first?.outcome, .removed)
        state.bootedDevices = [UUID().uuidString]
        XCTAssertNotNil(CleanupPolicy.blockReason(value, tier: .deep, protectedPaths: [], environment: state))
    }
}
