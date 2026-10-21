import Foundation

/// Imports legacy settings once, without changing the original preference domain.
/// Protection and history remain available when the bundle identifier changes.
enum BrandMigration {
    static let marker = "XcodeFit.migratedFromXcodeSize"
    static func migrate(into target: UserDefaults, legacy: [String: Any]) {
        guard !target.bool(forKey: marker), !legacy.isEmpty else { return }
        for (key, value) in legacy where key.hasPrefix("XcodeSize.") {
            let renamed = "XcodeFit." + key.dropFirst("XcodeSize.".count)
            if target.object(forKey: renamed) == nil { target.set(value, forKey: renamed) }
        }
        if target.object(forKey: "protectedPaths") == nil, let paths = legacy["protectedPaths"] {
            target.set(paths, forKey: "protectedPaths")
        }
        target.set(true, forKey: marker)
    }
    static func prepareStandardPreferences() {
        migrate(into: .standard, legacy: UserDefaults.standard.persistentDomain(forName: "com.xcodesize.app") ?? [:])
    }
}
