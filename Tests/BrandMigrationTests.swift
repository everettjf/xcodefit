import XCTest
@testable import XcodeFitCore

final class BrandMigrationTests: XCTestCase {
    func testImportsLanguageProtectionAndHistoryWithoutOverwritingCurrentSettings() throws {
        let suite = "XcodeFit.MigrationTest." + UUID().uuidString
        let target = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { target.removePersistentDomain(forName: suite) }
        let history = Data("old-history".utf8)
        target.set(45, forKey: "XcodeFit.logDays")
        BrandMigration.migrate(into: target, legacy: ["XcodeSize.interfaceLanguage": "ja", "XcodeSize.history": history,
                                                   "XcodeSize.logDays": 30, "protectedPaths": ["/Projects/Keep"], "unrelated": true])
        XCTAssertEqual(target.string(forKey: "XcodeFit.interfaceLanguage"), "ja")
        XCTAssertEqual(target.data(forKey: "XcodeFit.history"), history)
        XCTAssertEqual(target.integer(forKey: "XcodeFit.logDays"), 45)
        XCTAssertEqual(target.stringArray(forKey: "protectedPaths"), ["/Projects/Keep"])
        XCTAssertNil(target.object(forKey: "unrelated"))
        target.removeObject(forKey: "protectedPaths")
        BrandMigration.migrate(into: target, legacy: ["protectedPaths": ["/Projects/Keep"]])
        XCTAssertNil(target.object(forKey: "protectedPaths"), "Removed protections must not return after migration")
    }
    func testNoLegacyDomainDoesNotPreventFutureMigration() throws {
        let suite = "XcodeFit.MigrationTest." + UUID().uuidString
        let target = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { target.removePersistentDomain(forName: suite) }
        BrandMigration.migrate(into: target, legacy: [:])
        XCTAssertFalse(target.bool(forKey: BrandMigration.marker))
        BrandMigration.migrate(into: target, legacy: ["XcodeSize.interfaceLanguage": "ko"])
        XCTAssertEqual(target.string(forKey: "XcodeFit.interfaceLanguage"), "ko")
    }
}
