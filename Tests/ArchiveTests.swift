import XCTest
@testable import XcodeFitCore

final class ArchiveTests: XCTestCase {
    var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("XcodeFitArchiveTests-" + UUID().uuidString).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func write(_ path: String, _ data: Data = Data(repeating: 65, count: 8192)) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }
    func archive(_ name: String, version: String, build: String = "1", bundle: String = "com.test.app", platform: String = "iphoneos", team: String = "TEAM") throws -> StorageItem {
        let path = "Archives/" + name + ".xcarchive"
        let properties: [String: Any] = ["CFBundleIdentifier": bundle, "CFBundleShortVersionString": version, "CFBundleVersion": build, "ApplicationPath": "Applications/App.app", "Team": team]
        try write(path + "/Info.plist", PropertyListSerialization.data(fromPropertyList: ["ApplicationProperties": properties], format: .xml, options: 0))
        try write(path + "/Products/Applications/App.app/Info.plist", PropertyListSerialization.data(fromPropertyList: ["DTPlatformName": platform], format: .xml, options: 0))
        try write(path + "/Products/Applications/App.app/App")
        try write(path + "/dSYMs/App.app.dSYM/Contents/Resources/DWARF/App")
        let url = root.appendingPathComponent(path)
        return StorageItem(url: url, name: name, category: .archives, purpose: "", owner: bundle, evidence: "", measurement: FileSizer.measure(url), action: .trash, minimumTier: .deep, manualOnly: true, sourceRoot: root.appendingPathComponent("Archives"), archive: ArchiveMetadata.read(url))
    }
    var idle: ToolEnvironment { ToolEnvironment(processStateKnown: true, simulatorStateKnown: true) }

    func testRetentionUsesNumericVersionsAndKeepsEveryBuildOfLatestVersion() throws {
        let old = try archive("old", version: "1.9")
        let a = try archive("new-a", version: "1.10", build: "100")
        let b = try archive("new-b", version: "1.10.0", build: "101")
        let unknown = try archive("unknown", version: "beta")
        let result = ArchiveRetention.candidates([old, a, b, unknown], keeping: 1, protectedPaths: [])
        XCTAssertEqual(result, [old.id])
    }
    func testRetentionSeparatesAppsPlatformsAndTeamsAndPreservesUnknownIdentity() throws {
        let old = try archive("old", version: "1")
        let new = try archive("new", version: "2")
        let otherApp = try archive("other-app", version: "1", bundle: "com.test.other")
        let otherOS = try archive("other-platform", version: "1", platform: "macosx")
        let otherTeam = try archive("other-team", version: "1", team: "OTHER")
        let unknownTeam = try archive("unknown-team", version: "1", team: "")
        XCTAssertEqual(ArchiveRetention.candidates([old, new, otherApp, otherOS, otherTeam, unknownTeam], keeping: 1, protectedPaths: []), [old.id])
    }
    func testAllArchivesIncludesUnknownVersionsButAlwaysExcludesProtectionAndIncompleteScans() throws {
        let unknown = try archive("unknown", version: "beta")
        let protected = try archive("protected", version: "1")
        var incomplete = try archive("incomplete", version: "2"); incomplete.measurement.unreadable = 1
        XCTAssertEqual(ArchiveRetention.candidates([unknown, protected, incomplete], keeping: 0, protectedPaths: [protected.id + "/dSYMs"]), [unknown.id])
        XCTAssertTrue(ArchiveRetention.candidates([unknown], keeping: -1, protectedPaths: []).isEmpty)
    }
    func testStandardRejectsArchivesEvenWithIncorrectTierAndDeepStillNeverRecommendsThem() throws {
        var value = try archive("release", version: "1")
        value.minimumTier = .regular; value.manualOnly = false
        XCTAssertNotNil(CleanupPolicy.blockReason(value, tier: .regular, protectedPaths: [], environment: idle))
        XCTAssertFalse(CleanupPolicy.recommended(value, tier: .deep, settings: CleanupSettings(), protectedPaths: [], environment: idle))
        let environment = idle
        let engine = CleanupEngine(inspect: { environment }, trash: { _ in XCTFail("Standard must preserve archives"); return nil })
        XCTAssertEqual(engine.execute(CleanupPlan(tier: .regular, items: [value]), protectedPaths: []).first?.outcome, .skipped)
    }
    func testScannerProtectsBuildSymbolsAndMutablePackageWorkingCopies() throws {
        try write("DerivedData/App/Build/Products/App.app.dSYM/Contents/Resources/DWARF/App")
        try write("DerivedData/App/SourcePackages/checkouts/Dependency/local-edits.swift")
        let configuration = ScanConfiguration(home: root.appendingPathComponent("empty"), systemDeveloper: root.appendingPathComponent("system"), applicationRoots: [], customRoots: [CustomRoot(url: root.appendingPathComponent("DerivedData"), kind: .derivedData)], discoverEnvironment: false)
        let snapshot = StorageScanner(configuration: configuration).scan()
        for value in snapshot.items where value.category == .builds || value.category == .packages {
            XCTAssertTrue(value.requiresDeepCleanup)
            XCTAssertEqual(value.minimumTier, .deep)
            XCTAssertNotNil(CleanupPolicy.blockReason(value, tier: .regular, protectedPaths: [], environment: idle))
            XCTAssertFalse(CleanupPolicy.recommended(value, tier: .deep, settings: CleanupSettings(), protectedPaths: [], environment: idle))
        }
        XCTAssertEqual(snapshot.items.filter { $0.requiresDeepCleanup }.count, 2)
    }
    func testArchiveBreakdownIsPartOfTotalAndNestedSymbolFilesAreNeverIndependentCandidates() throws {
        let fixture = try archive("release", version: "1")
        let configuration = ScanConfiguration(home: root.appendingPathComponent("empty"), systemDeveloper: root.appendingPathComponent("system"), applicationRoots: [], customRoots: [CustomRoot(url: root.appendingPathComponent("Archives"), kind: .archives)], discoverEnvironment: false)
        let snapshot = StorageScanner(configuration: configuration).scan()
        let value = try XCTUnwrap(snapshot.items.first)
        XCTAssertEqual(snapshot.items.count, 1)
        XCTAssertEqual(value.archive?.version, "1")
        XCTAssertEqual(snapshot.total, fixture.size)
        XCTAssertGreaterThan(value.measurement.productBytes, 0)
        XCTAssertGreaterThan(value.measurement.symbolBytes, 0)
        XCTAssertLessThanOrEqual(value.measurement.productBytes + value.measurement.symbolBytes, snapshot.total)
    }
    func testUUIDMatchingIncludesArchitectureAndCannotBeReplacedByNewestSymbols() {
        let old = UUID().uuidString, new = UUID().uuidString
        var report = ArchiveSymbolReport()
        report.binaries = ArchiveSymbolReport.parseUUIDs("UUID: \(old) (arm64) /App\nUUID: \(old) (x86_64) /App")
        report.symbols = ArchiveSymbolReport.parseUUIDs("UUID: \(old) (arm64) /App.dSYM\nUUID: \(new) (x86_64) /New.dSYM")
        XCTAssertEqual(report.missing, [old + " (x86_64)"])
        XCTAssertTrue(ArchiveSymbolReport.parseUUIDs("not a UUID output").isEmpty)
    }
    func testSymbolInspectionFindsRealMachOUUIDsAndReportsMissingSymbols() throws {
        let value = try archive("macho", version: "1")
        let binary = value.url.appendingPathComponent("Products/Applications/App.app/App")
        let symbol = value.url.appendingPathComponent("dSYMs/App.app.dSYM/Contents/Resources/DWARF/App")
        try FileManager.default.removeItem(at: binary)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: binary)
        try FileManager.default.removeItem(at: symbol)
        try FileManager.default.copyItem(at: binary, to: symbol)
        let matched = ArchiveSymbolReport.inspect(value.url)
        guard !matched.binaries.isEmpty else { throw XCTSkip("dwarfdump unavailable in this environment") }
        XCTAssertEqual(matched.failures, 0)
        XCTAssertTrue(matched.missing.isEmpty)
        try FileManager.default.removeItem(at: symbol)
        let missing = ArchiveSymbolReport.inspect(value.url)
        XCTAssertEqual(missing.missing, matched.binaries)
    }
}
