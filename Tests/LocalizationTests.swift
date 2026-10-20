import XCTest
@testable import XcodeSizeCore

final class LocalizationTests: XCTestCase {
    func testEnglishIsDefaultAndInvalidPreferencesFallBackToEnglish() {
        XCTAssertEqual(AppLanguage.fromPreference(nil), .english)
        XCTAssertEqual(AppLanguage.fromPreference("unknown-language"), .english)
        XCTAssertEqual(AppLanguage.fromPreference("zh-Hans"), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.fromPreference("system"), .system)
    }

    func testCompiledResourcesLoadAllFiveLanguages() {
        XCTAssertEqual(L10n.format("Overview", language: .english), "Overview")
        XCTAssertEqual(L10n.format("Overview", language: .simplifiedChinese), "空间概览")
        XCTAssertEqual(L10n.format("Deep Clean", language: .simplifiedChinese), "深度清理")
        XCTAssertEqual(L10n.format("Language", language: .simplifiedChinese), "语言")
        XCTAssertEqual(L10n.format("File identity information is missing.", language: .simplifiedChinese), "缺少文件身份信息")
        XCTAssertEqual(L10n.format("Overview", language: .traditionalChinese), "空間概覽")
        XCTAssertEqual(L10n.format("Overview", language: .japanese), "概要")
        XCTAssertEqual(L10n.format("Overview", language: .korean), "개요")
        for language in AppLanguage.allCases where language != .system {
            XCTAssertNotEqual(L10n.format("File identity information is missing.", language: language), "", language.rawValue)
            if language != .english {
                XCTAssertNotEqual(L10n.format("This location is protected.", language: language), "This location is protected.", language.rawValue)
            }
        }
    }

    func testNamesPathsAndPercentSignsRemainLiteralDuringInterpolation() {
        let name = "Release 100% %@ / 项目.xcarchive"
        XCTAssertEqual(L10n.format("Select %@", language: .english, arguments: [name]), "Select " + name)
        XCTAssertEqual(L10n.format("Select %@", language: .simplifiedChinese, arguments: [name]), "选择 " + name)
        XCTAssertEqual(L10n.format("Selected: %@ · %@", language: .english, arguments: ["1", "42 MB"]), "Selected: 1 · 42 MB")
        XCTAssertEqual(L10n.format("Selected: %@ · %@", language: .simplifiedChinese, arguments: ["1", "42 MB"]), "已选 1 项 · 42 MB")
        for language in AppLanguage.allCases where language != .system {
            let result = L10n.format("Select %@", language: language, arguments: [name])
            XCTAssertTrue(result.contains(name), language.rawValue)
        }
    }

    func testUnknownKeysFallBackToEnglishSource() {
        XCTAssertEqual(L10n.format("An untranslated future message", language: .simplifiedChinese), "An untranslated future message")
    }

    func testFollowSystemChoosesSupportedLanguages() {
        XCTAssertEqual(AppLanguage.system.resolvedIdentifier(preferredLanguages: ["en-GB"]), "en")
        XCTAssertEqual(AppLanguage.system.resolvedIdentifier(preferredLanguages: ["zh-Hans-CN"]), "zh-Hans")
        XCTAssertEqual(AppLanguage.system.resolvedIdentifier(preferredLanguages: ["zh-TW"]), "zh-Hant")
        XCTAssertEqual(AppLanguage.system.resolvedIdentifier(preferredLanguages: ["zh-HK"]), "zh-Hant")
        XCTAssertEqual(AppLanguage.system.resolvedIdentifier(preferredLanguages: ["ja-JP"]), "ja")
        XCTAssertEqual(AppLanguage.system.resolvedIdentifier(preferredLanguages: ["ko-KR"]), "ko")
        XCTAssertEqual(AppLanguage.system.resolvedIdentifier(preferredLanguages: ["de-DE", "ja-JP"]), "ja")
        XCTAssertEqual(AppLanguage.system.resolvedIdentifier(preferredLanguages: ["de-DE"]), "en")
    }

    func testProtectionDoesNotDependOnTranslatedEvidence() {
        let project = URL(fileURLWithPath: "/fixture/DerivedData/Project")
        let value = StorageItem(url: project.appendingPathComponent("Build"), name: "Project", category: .builds,
                                purpose: "", owner: "", evidence: "A completely different translation", measurement: Measurement(),
                                action: .trash, minimumTier: .regular, sourceRoot: project, projectDataRoot: project)
        XCTAssertEqual(value.protectionPath, project.path)
    }

    func testCatalogIsCompleteAndFormatArgumentsMatchInAllFiveLanguages() throws {
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let catalog = repository.appendingPathComponent("XcodeSize/XcodeSize/Core/Resources/Localizable.xcstrings")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: catalog)) as? [String: Any])
        XCTAssertEqual(json["sourceLanguage"] as? String, "en")
        let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])
        XCTAssertGreaterThan(strings.count, 280)
        for (key, entry) in strings {
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]])
            for language in AppLanguage.supportedIdentifiers {
                let unit = try XCTUnwrap(localizations[language]?["stringUnit"] as? [String: String])
                let value = try XCTUnwrap(unit["value"])
                XCTAssertFalse(value.isEmpty, key)
                XCTAssertEqual(unit["state"], "translated", key)
                XCTAssertEqual(value.components(separatedBy: "%@").count, key.components(separatedBy: "%@").count, key)
                let preference = try XCTUnwrap(AppLanguage(rawValue: language))
                XCTAssertEqual(L10n.format(key, language: preference), value, "Compiled resource mismatch: \(language), \(key)")
            }
        }
    }
}
