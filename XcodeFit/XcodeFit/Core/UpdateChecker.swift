import Foundation
import Observation

struct AppVersion: Comparable, Sendable {
    let components: [Int]
    init?(_ value: String) {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              parts.allSatisfy({ $0.count == 1 || $0.first != "0" }) else { return nil }
        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == 3 else { return nil }
        components = numbers
    }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.components.lexicographicallyPrecedes(rhs.components) }
}

struct AppRelease: Codable, Equatable, Sendable {
    let version: String
    var pageURL: URL { URL(string: "https://github.com/everettjf/homebrew-tap/releases/tag/xcodefit-v\(version)")! }
    var isValid: Bool { AppVersion(version) != nil }
}

enum UpdateFailure: Error, Equatable {
    case network, rateLimited, invalidResponse, noRelease, invalidCurrentVersion
    var message: String {
        switch self {
        case .network: L10n.text("Could not reach GitHub. Check your connection and try again.")
        case .rateLimited: L10n.text("GitHub is limiting requests. Please try again later.")
        case .invalidResponse: L10n.text("GitHub returned an unexpected response. Please try again later.")
        case .noRelease: L10n.text("No downloadable XcodeFit release was found. Please try again later.")
        case .invalidCurrentVersion: L10n.text("This build has no valid version number. Visit the release page to check for updates.")
        }
    }
}

struct ReleaseFeed: Sendable {
    struct Entry: Decodable, Sendable {
        struct Asset: Decodable, Sendable {
            let name: String
            let state: String
            let size: Int64
        }
        let tag_name: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
        var release: AppRelease? {
            let prefix = "xcodefit-v"
            guard !draft, !prerelease, tag_name.hasPrefix(prefix) else { return nil }
            let version = String(tag_name.dropFirst(prefix.count))
            guard AppVersion(version) != nil,
                  assets.contains(where: { $0.name == "XcodeFit-\(version).zip" && $0.state == "uploaded" && $0.size > 0 }) else { return nil }
            return AppRelease(version: version)
        }
    }
    static func latest(in entries: [Entry]) -> AppRelease? {
        entries.compactMap(\.release).max { AppVersion($0.version)! < AppVersion($1.version)! }
    }
    static func validate(statusCode: Int) throws {
        if statusCode == 403 || statusCode == 429 { throw UpdateFailure.rateLimited }
        guard statusCode == 200 else { throw UpdateFailure.invalidResponse }
    }
    static func fetch() async throws -> AppRelease {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 45
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        return try await fetch { request in try await session.data(for: request) }
    }
    // Read all pages in the bounded feed, so another product's latest release cannot mask XcodeFit.
    static func fetch(load: @Sendable (URLRequest) async throws -> (Data, URLResponse)) async throws -> AppRelease {
        var entries: [Entry] = []
        for page in 1...10 {
            try Task.checkCancellation()
            let url = URL(string: "https://api.github.com/repos/everettjf/homebrew-tap/releases?per_page=100&page=\(page)")!
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            request.setValue("XcodeFit-Update-Check", forHTTPHeaderField: "User-Agent")
            let (data, response): (Data, URLResponse)
            do { (data, response) = try await load(request) }
            catch is CancellationError { throw CancellationError() }
            catch {
                if Task.isCancelled { throw CancellationError() }
                throw UpdateFailure.network
            }
            guard let http = response as? HTTPURLResponse, data.count <= 8_000_000 else { throw UpdateFailure.invalidResponse }
            try validate(statusCode: http.statusCode)
            guard let values = try? JSONDecoder().decode([Entry].self, from: data) else { throw UpdateFailure.invalidResponse }
            entries.append(contentsOf: values)
            if values.count < 100 {
                guard let release = latest(in: entries) else { throw UpdateFailure.noRelease }
                return release
            }
        }
        // An incomplete feed must not be reported as "up to date".
        throw UpdateFailure.invalidResponse
    }
}

@MainActor @Observable
final class UpdateChecker {
    enum State: Equatable {
        case idle, checking, current(AppRelease), available(AppRelease), failed(UpdateFailure)
    }
    static let automaticKey = "XcodeFit.automaticallyCheckUpdates"
    private static let attemptKey = "XcodeFit.lastUpdateAttempt"
    private static let checkedKey = "XcodeFit.lastUpdateCheck"
    private static let releaseKey = "XcodeFit.cachedRelease"
    let currentVersion: String
    var state: State = .idle
    var lastChecked: Date?
    var automaticallyChecks: Bool {
        didSet { defaults.set(automaticallyChecks, forKey: Self.automaticKey) }
    }
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let fetch: @Sendable () async throws -> AppRelease
    var isChecking: Bool { state == .checking }
    var availableRelease: AppRelease? { if case .available(let release) = state { release } else { nil } }

    init(currentVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
         defaults: UserDefaults = .standard,
         fetch: @escaping @Sendable () async throws -> AppRelease = { try await ReleaseFeed.fetch() }) {
        self.currentVersion = currentVersion
        self.defaults = defaults
        self.fetch = fetch
        automaticallyChecks = defaults.object(forKey: Self.automaticKey) as? Bool ?? true
        lastChecked = defaults.object(forKey: Self.checkedKey) as? Date
        if let data = defaults.data(forKey: Self.releaseKey), let cached = try? JSONDecoder().decode(AppRelease.self, from: data),
           cached.isValid, let current = AppVersion(currentVersion), let latest = AppVersion(cached.version) {
            state = latest > current ? .available(cached) : .current(cached)
        }
    }
    func check(automatically: Bool = false, now: Date = Date()) async {
        guard !isChecking else { return }
        if automatically {
            guard automaticallyChecks else { return }
            if let last = defaults.object(forKey: Self.attemptKey) as? Date,
               now >= last, now.timeIntervalSince(last) < 86_400 { return }
        }
        guard let current = AppVersion(currentVersion) else { state = .failed(.invalidCurrentVersion); return }
        let previous = state
        state = .checking
        defaults.set(now, forKey: Self.attemptKey)
        do {
            let release = try await fetch()
            try Task.checkCancellation()
            guard let latest = AppVersion(release.version) else { throw UpdateFailure.invalidResponse }
            state = latest > current ? .available(release) : .current(release)
            lastChecked = now
            defaults.set(now, forKey: Self.checkedKey)
            defaults.set(try JSONEncoder().encode(release), forKey: Self.releaseKey)
        } catch is CancellationError {
            state = previous
            // A cancelled view task should not suppress a later launch check.
            defaults.removeObject(forKey: Self.attemptKey)
        } catch {
            // Keep a known update visible if a background refresh fails.
            if automatically, case .available = previous { state = previous }
            else { state = .failed(error as? UpdateFailure ?? .network) }
        }
    }
}
