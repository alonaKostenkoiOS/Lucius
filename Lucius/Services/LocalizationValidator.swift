import Foundation

/// Development-time checks for the app's bundled localization resources.
/// The English file is the canonical key set; every approved locale must match it exactly.
struct LocalizationValidationReport: Equatable {
    var missingLocales: [String] = []
    var unexpectedLocales: [String] = []
    var missingKeys: [String: [String]] = [:]
    var extraKeys: [String: [String]] = [:]
    var emptyValues: [String: [String]] = [:]

    var isValid: Bool {
        missingLocales.isEmpty && unexpectedLocales.isEmpty && missingKeys.isEmpty &&
            extraKeys.isEmpty && emptyValues.isEmpty
    }
}

enum LocalizationValidator {
    static let approvedLocales = SupportedLanguage.allCases.map(\.rawValue)

    static func validate(directoryURL: URL) -> LocalizationValidationReport {
        var report = LocalizationValidationReport()
        let approved = Set(approvedLocales)
        let directories = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let localeDirectories = directories.filter { $0.pathExtension == "lproj" }
        let discovered = Set(localeDirectories.map { $0.deletingPathExtension().lastPathComponent })
        report.missingLocales = approved.subtracting(discovered).sorted()
        report.unexpectedLocales = discovered.subtracting(approved).sorted()

        guard let english = parseFile(directoryURL.appendingPathComponent("en.lproj/Localizable.strings")) else {
            report.missingLocales.append("en")
            return report
        }
        let canonicalKeys = Set(english.keys)
        for locale in approvedLocales {
            let fileURL = directoryURL.appendingPathComponent("\(locale).lproj/Localizable.strings")
            guard let values = parseFile(fileURL) else {
                report.missingLocales.append(locale)
                continue
            }
            let keys = Set(values.keys)
            let missing = canonicalKeys.subtracting(keys).sorted()
            let extra = keys.subtracting(canonicalKeys).sorted()
            let empty = values.compactMap { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? $0.key : nil }.sorted()
            if !missing.isEmpty { report.missingKeys[locale] = missing }
            if !extra.isEmpty { report.extraKeys[locale] = extra }
            if !empty.isEmpty { report.emptyValues[locale] = empty }
        }
        return report
    }

    private static func parseFile(_ url: URL) -> [String: String]? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var values: [String: String] = [:]
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.first == "\"", let separator = trimmed.range(of: "\" = \"") else { continue }
            let keyStart = trimmed.index(after: trimmed.startIndex)
            let key = String(trimmed[keyStart..<separator.lowerBound])
            let value = String(trimmed[separator.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "\";"))
            values[key] = value
        }
        return values
    }
}
