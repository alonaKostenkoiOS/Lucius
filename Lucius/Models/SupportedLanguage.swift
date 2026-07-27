import Foundation

/// The only languages Lucius exposes for both its interface and vocabulary.
enum SupportedLanguage: String, CaseIterable, Codable, Identifiable, Hashable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portugueseBrazil = "pt-BR"
    case italian = "it"
    case polish = "pl"
    case ukrainian = "uk"
    case japanese = "ja"
    case korean = "ko"
    case chineseSimplified = "zh-Hans"

    var id: String { rawValue }
    var code: String { rawValue }
    var localeIdentifier: String { rawValue }
    var supportsInterfaceLocalization: Bool { true }
    var supportsLearning: Bool { true }

    /// Native display names are stable even when the interface language changes.
    var nativeName: String {
        switch self {
        case .english: "English"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .portugueseBrazil: "Português (Brasil)"
        case .italian: "Italiano"
        case .polish: "Polski"
        case .ukrainian: "Українська"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .chineseSimplified: "简体中文"
        }
    }

    /// The system-localized name, useful for interface-language pickers.
    /// Selectors that teach a language use `nativeName` so every option remains recognizable.
    var localizedName: String {
        Locale.current.localizedString(forIdentifier: localeIdentifier) ?? nativeName
    }

    var name: String { nativeName }

    static var systemLanguage: SupportedLanguage {
        let locale = Locale.current
        let normalizedIdentifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        if let exact = allCases.first(where: { normalizedIdentifier.caseInsensitiveCompare($0.localeIdentifier) == .orderedSame }) {
            return exact
        }
        let languageCode = locale.language.languageCode?.identifier
        // Portuguese has an approved Brazilian locale only; do not silently select it for pt-PT.
        let brazilianLanguageCode = Locale(identifier: SupportedLanguage.portugueseBrazil.rawValue).language.languageCode?.identifier
        if languageCode == brazilianLanguageCode { return .english }
        if let match = allCases.first(where: { Locale(identifier: $0.localeIdentifier).language.languageCode?.identifier == languageCode }) {
            return match
        }
        return .english
    }
}
