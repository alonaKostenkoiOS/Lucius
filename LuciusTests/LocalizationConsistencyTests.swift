import Foundation
import XCTest
@testable import Lucius

final class LocalizationConsistencyTests: XCTestCase {
    func testApprovedLanguageSetIsExactlyEleven() {
        XCTAssertEqual(SupportedLanguage.allCases.map(\.rawValue), [
            "en", "es", "fr", "de", "pt-BR", "it", "pl", "uk", "ja", "ko", "zh-Hans"
        ])
        XCTAssertEqual(Set(SupportedLanguage.allCases.map(\.rawValue)).count, 11)
        XCTAssertTrue(SupportedLanguage.allCases.allSatisfy { $0.supportsInterfaceLocalization && $0.supportsLearning })
    }

    func testLocalizationFilesHaveIdenticalCompleteKeySets() {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Lucius/Resources/Localization")
        let report = LocalizationValidator.validate(directoryURL: directory)
        XCTAssertTrue(report.isValid, "Localization validation failed: \(report)")
    }

    func testLanguageSelectionRejectsIdenticalPair() {
        XCTAssertFalse(OnboardingState.canContinueWithLanguages(learning: .english, native: .english))
        XCTAssertTrue(OnboardingState.canContinueWithLanguages(learning: .english, native: .ukrainian))
    }

    func testUnknownStoredLanguageFallsBackToEnglish() {
        let defaults = UserDefaults(suiteName: "LocalizationConsistencyTests")!
        defaults.set("unsupported-locale", forKey: AppSettingsKeys.learningLanguageCode)
        XCTAssertEqual(AppLanguageSettings.learningLanguageCode(defaults: defaults), SupportedLanguage.english.rawValue)
        defaults.removePersistentDomain(forName: "LocalizationConsistencyTests")
    }
}
