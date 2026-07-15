import Foundation

/// Translates words in the user's selected language pair via MyMemory.
/// Used as a fallback on devices without the system Translation framework (iOS 18+).
///
/// Results are cached so re-translating the same word is instant and
/// doesn't spend the free API's daily quota. The cache is an actor so it's
/// safe to share across concurrent translation requests.
private actor TranslationCache {
    private var entries: [String: String] = [:]

    func value(for key: String) -> String? { entries[key] }
    func store(_ value: String, for key: String) { entries[key] = value }
}

struct TranslationService {
    static let shared = TranslationService()

    private static let cache = TranslationCache()

    enum TranslationError: Error {
        case invalidQuery
        case badResponse
    }

    static var sourceLanguageCode: String {
        AppLanguageSettings.learningLanguageCode
    }

    static var targetLanguageCode: String {
        AppLanguageSettings.translationLanguageCode
    }

    private struct MyMemoryResponse: Decodable {
        struct ResponseData: Decodable {
            let translatedText: String
        }

        let responseData: ResponseData
    }

    private init() {}

    func translate(_ text: String) async throws -> String {
        guard Self.sourceLanguageCode != Self.targetLanguageCode else {
            throw TranslationError.invalidQuery
        }

        let cacheKey = "\(Self.sourceLanguageCode)|\(Self.targetLanguageCode)|\(text.lowercased())"
        if let cached = await Self.cache.value(for: cacheKey) {
            return cached
        }

        var components = URLComponents(string: "https://api.mymemory.translated.net/get")
        components?.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(
                name: "langpair",
                value: "\(Self.sourceLanguageCode)|\(Self.targetLanguageCode)"
            ),
        ]

        guard let url = components?.url else {
            throw TranslationError.invalidQuery
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TranslationError.badResponse
        }

        let decoded = try JSONDecoder().decode(MyMemoryResponse.self, from: data)
        let translated = decoded.responseData.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !translated.isEmpty else {
            throw TranslationError.badResponse
        }

        await Self.cache.store(translated, for: cacheKey)
        return translated
    }
}
