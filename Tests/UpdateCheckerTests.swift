import XCTest
@testable import XcodeFitCore

final class UpdateCheckerTests: XCTestCase {
    private func entry(_ tag: String, draft: Bool = false, prerelease: Bool = false, asset: Bool = true) -> [String: Any] {
        let version = tag.replacingOccurrences(of: "xcodefit-v", with: "")
        return ["tag_name": tag, "draft": draft, "prerelease": prerelease,
                "assets": asset ? [["name": "XcodeFit-\(version).zip", "state": "uploaded", "size": 123]] : []]
    }
    private func entries(_ values: [[String: Any]]) throws -> [ReleaseFeed.Entry] {
        try JSONDecoder().decode([ReleaseFeed.Entry].self, from: JSONSerialization.data(withJSONObject: values))
    }
    func testVersionOrderingUsesNumbersNotLexicalOrder() throws {
        XCTAssertGreaterThan(try XCTUnwrap(AppVersion("1.0.10")), try XCTUnwrap(AppVersion("1.0.9")))
        XCTAssertGreaterThan(try XCTUnwrap(AppVersion("2.0.0")), try XCTUnwrap(AppVersion("1.99.99")))
        XCTAssertEqual(AppVersion("1.0.1"), AppVersion("1.0.1"))
        for invalid in ["", "1.0", "1.0.1-beta", "v1.0.1", "1.0.01", "-1.0.0", "１.0.0", "9999999999999999999999.0.0"] {
            XCTAssertNil(AppVersion(invalid), invalid)
        }
    }
    func testSharedTapFiltersOtherProductsDraftsPrereleasesAndMissingAssets() throws {
        let values = try entries([entry("hexlora-v99.0.0"), entry("xcodefit-v9.0.0", draft: true),
                                  entry("xcodefit-v8.0.0", prerelease: true), entry("xcodefit-v7.0.0", asset: false),
                                  entry("xcodefit-v1.0.9"), entry("xcodefit-v1.0.10"), entry("xcodefit-v1.1.0-beta")])
        let release = try XCTUnwrap(ReleaseFeed.latest(in: values))
        XCTAssertEqual(release.version, "1.0.10")
        XCTAssertEqual(release.pageURL.absoluteString, "https://github.com/everettjf/homebrew-tap/releases/tag/xcodefit-v1.0.10")
    }
    func testPaginationFindsOlderPublishedXcodeFitAmongOtherProducts() async throws {
        let first = try JSONSerialization.data(withJSONObject: Array(repeating: entry("hexlora-v1.0.0"), count: 100))
        let second = try JSONSerialization.data(withJSONObject: [entry("xcodefit-v1.0.2")])
        let result = try await ReleaseFeed.fetch { request in
            XCTAssertEqual(request.url?.host, "api.github.com")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertNil(request.httpBody)
            let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "page" }?.value
            let data = page == "1" ? first : second
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        XCTAssertEqual(result.version, "1.0.2")
    }
    func testRateLimitIsNotTreatedAsUpToDate() async {
        do {
            _ = try await ReleaseFeed.fetch { request in
                (Data(), HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!)
            }
            XCTFail("Expected failure")
        } catch { XCTAssertEqual(error as? UpdateFailure, .rateLimited) }
    }
    func testMalformedResponseAndMissingReleaseAreDistinctFailures() async {
        for (data, expected) in [(Data("not JSON".utf8), UpdateFailure.invalidResponse), (Data("[]".utf8), .noRelease)] {
            do {
                _ = try await ReleaseFeed.fetch { request in
                    (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
                }
                XCTFail("Expected failure")
            } catch { XCTAssertEqual(error as? UpdateFailure, expected) }
        }
    }
    func testOfflineFailureIsExplicit() async {
        do {
            _ = try await ReleaseFeed.fetch { _ in throw URLError(.notConnectedToInternet) }
            XCTFail("Expected failure")
        } catch { XCTAssertEqual(error as? UpdateFailure, .network) }
    }
    @MainActor func testNewerSameAndOlderReleases() async {
        let suite = "XcodeFit.UpdateTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        // Isolated suite is removed below; no real preferences or network are used.
        defer { defaults.removePersistentDomain(forName: suite) }
        for version in ["1.0.0", "1.0.1", "1.0.2"] {
            let checker = UpdateChecker(currentVersion: "1.0.1", defaults: defaults, fetch: { AppRelease(version: version) })
            await checker.check()
            XCTAssertEqual(checker.availableRelease?.version, version == "1.0.2" ? version : nil)
            XCTAssertNotNil(checker.lastChecked)
        }
    }
    @MainActor func testDailyThrottleManualOverrideAndCachedUpdateSurviveRestart() async {
        let suite = "XcodeFit.UpdateTests.\(UUID())", now = Date()
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let checker = UpdateChecker(currentVersion: "1.0.0", defaults: defaults, fetch: { AppRelease(version: "1.0.2") })
        await checker.check(automatically: true, now: now)
        XCTAssertEqual(checker.availableRelease?.version, "1.0.2")
        let restored = UpdateChecker(currentVersion: "1.0.0", defaults: defaults, fetch: { throw UpdateFailure.network })
        XCTAssertEqual(restored.availableRelease?.version, "1.0.2")
        await restored.check(automatically: true, now: now.addingTimeInterval(60))
        XCTAssertEqual(restored.availableRelease?.version, "1.0.2")
        await restored.check(now: now.addingTimeInterval(60))
        XCTAssertEqual(restored.state, .failed(.network))
        XCTAssertEqual(restored.lastChecked, now)
        // A newer installed version must not offer the cached older release as an upgrade.
        let upgraded = UpdateChecker(currentVersion: "1.0.3", defaults: defaults)
        XCTAssertNil(upgraded.availableRelease)
    }
    @MainActor func testAutomaticOptOutStillAllowsManualCheck() async {
        let suite = "XcodeFit.UpdateTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let checker = UpdateChecker(currentVersion: "1.0.1", defaults: defaults, fetch: { AppRelease(version: "1.0.2") })
        checker.automaticallyChecks = false
        await checker.check(automatically: true)
        XCTAssertEqual(checker.state, .idle)
        await checker.check()
        XCTAssertEqual(checker.availableRelease?.version, "1.0.2")
        XCTAssertFalse(UpdateChecker(currentVersion: "1.0.1", defaults: defaults).automaticallyChecks)
    }
    func testIncompleteFeedFailsInsteadOfClaimingUpToDate() async throws {
        let data = try JSONSerialization.data(withJSONObject: Array(repeating: entry("hexlora-v1.0.0"), count: 100))
        do {
            _ = try await ReleaseFeed.fetch { request in
                (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            XCTFail("Expected failure at the page limit")
        } catch { XCTAssertEqual(error as? UpdateFailure, .invalidResponse) }
    }
    @MainActor func testConcurrentChecksShareOneInFlightRequest() async throws {
        let suite = "XcodeFit.UpdateTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let probe = UpdateFetchProbe()
        let checker = UpdateChecker(currentVersion: "1.0.1", defaults: defaults, fetch: { try await probe.fetch() })
        let first = Task { await checker.check() }
        while !checker.isChecking { await Task.yield() }
        await checker.check()
        await first.value
        let calls = await probe.calls
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(checker.availableRelease?.version, "1.0.2")
    }
    @MainActor func testCancellationAllowsAnotherAutomaticAttempt() async {
        let suite = "XcodeFit.UpdateTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let probe = UpdateFetchProbe()
        let checker = UpdateChecker(currentVersion: "1.0.1", defaults: defaults, fetch: { try await probe.fetch() })
        let task = Task { await checker.check(automatically: true) }
        while !checker.isChecking { await Task.yield() }
        task.cancel()
        await task.value
        XCTAssertEqual(checker.state, .idle)
        await checker.check(automatically: true)
        XCTAssertEqual(checker.availableRelease?.version, "1.0.2")
    }
    @MainActor func testInvalidCacheAndInvalidLocalVersionDoNotClaimUpToDate() async {
        let suite = "XcodeFit.UpdateTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("{\"version\":\"bad\"}".utf8), forKey: "XcodeFit.cachedRelease")
        let checker = UpdateChecker(currentVersion: "", defaults: defaults, fetch: { AppRelease(version: "1.0.2") })
        XCTAssertEqual(checker.state, .idle)
        await checker.check()
        XCTAssertEqual(checker.state, .failed(.invalidCurrentVersion))
    }
}

private actor UpdateFetchProbe {
    var calls = 0
    func fetch() async throws -> AppRelease {
        calls += 1
        try await Task.sleep(for: .milliseconds(30))
        return AppRelease(version: "1.0.2")
    }
}
