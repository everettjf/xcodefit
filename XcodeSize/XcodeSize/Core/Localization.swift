import Foundation

/// Interface preference, independent of file paths and cleanup policy.
enum AppLanguage: String, CaseIterable, Sendable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case system
    static var supportedIdentifiers: [String] { allCases.filter { $0 != .system }.map(\.rawValue) }
    var id: String { rawValue }
    static let preferenceKey = "XcodeSize.interfaceLanguage"
    static var current: AppLanguage {
        fromPreference(L10n.preferences.string(forKey: preferenceKey))
    }
    static func fromPreference(_ value: String?) -> AppLanguage { value.flatMap(AppLanguage.init(rawValue:)) ?? .english }
    var title: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .system: L10n.text("Follow System")
        }
    }
    func resolvedIdentifier(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        switch self {
        case .english, .simplifiedChinese, .traditionalChinese, .japanese, .korean: rawValue
        case .system: Bundle.preferredLocalizations(from: Self.supportedIdentifiers, forPreferences: preferredLanguages).first ?? "en"
        }
    }
    var locale: Locale { self == .system ? .autoupdatingCurrent : Locale(identifier: rawValue) }
}

enum L10n {
    static var preferences: UserDefaults {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-fixture"), let preferences = UserDefaults(suiteName: "XcodeSize.UIFixture") { return preferences }
        #endif
        return .standard
    }
    #if SWIFT_PACKAGE
    static let resourceBundle = Bundle.module
    #else
    static let resourceBundle = Bundle.main
    #endif

    static func text(_ key: String, _ arguments: String...) -> String {
        format(key, language: .current, arguments: arguments)
    }

    static func format(_ key: String, language: AppLanguage, arguments: [String] = []) -> String {
        let identifier = language.resolvedIdentifier()
        let bundle = resourceBundle.path(forResource: identifier, ofType: "lproj").flatMap(Bundle.init(path:))
        let template = bundle?.localizedString(forKey: key, value: key, table: "Localizable") ?? key
        guard !arguments.isEmpty else { return template }
        // All localized placeholders are object placeholders. Paths and tool output are arguments,
        // never localization keys or format strings, so '%' in a file name remains literal.
        return String(format: template, locale: language.locale, arguments: arguments)
    }
}
