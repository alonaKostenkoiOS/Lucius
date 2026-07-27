import Foundation

enum OnboardingStep: String, CaseIterable, Codable, Identifiable {
    case welcome
    case languages
    case discovery
    case firstReview
    case goals
    case content
    case level
    case reviewModes
    case notifications
    case completion

    var id: String { rawValue }

    var next: OnboardingStep? {
        guard let index = Self.allCases.firstIndex(of: self),
              index + 1 < Self.allCases.count else { return nil }
        return Self.allCases[index + 1]
    }

    var previous: OnboardingStep? {
        guard let index = Self.allCases.firstIndex(of: self), index > 0 else { return nil }
        return Self.allCases[index - 1]
    }
}

enum OnboardingGoal: String, CaseIterable, Codable, Identifiable {
    case books
    case movies
    case travel
    case work
    case school
    case movingAbroad
    case people
    case curious

    var id: String { rawValue }

    var title: String {
        switch self {
        case .books: String(localized: "onboarding.goal.books")
        case .movies: String(localized: "onboarding.goal.movies")
        case .travel: String(localized: "onboarding.goal.travel")
        case .work: String(localized: "onboarding.goal.work")
        case .school: String(localized: "onboarding.goal.school")
        case .movingAbroad: String(localized: "onboarding.goal.moving_abroad")
        case .people: String(localized: "onboarding.goal.people")
        case .curious: String(localized: "onboarding.goal.curious")
        }
    }

    var systemImage: String {
        switch self {
        case .books: "book.closed"
        case .movies: "film"
        case .travel: "airplane"
        case .work: "briefcase"
        case .school: "graduationcap"
        case .movingAbroad: "house.and.flag"
        case .people: "person.2"
        case .curious: "sparkles"
        }
    }
}

enum OnboardingContentSource: String, CaseIterable, Codable, Identifiable {
    case books
    case articles
    case websites
    case pdfs
    case news
    case movies
    case socialMedia
    case workMaterials

    var id: String { rawValue }

    var title: String {
        switch self {
        case .books: String(localized: "onboarding.content.books")
        case .articles: String(localized: "onboarding.content.articles")
        case .websites: String(localized: "onboarding.content.websites")
        case .pdfs: String(localized: "onboarding.content.pdfs")
        case .news: String(localized: "onboarding.content.news")
        case .movies: String(localized: "onboarding.content.movies")
        case .socialMedia: String(localized: "onboarding.content.social_media")
        case .workMaterials: String(localized: "onboarding.content.work_materials")
        }
    }

    var systemImage: String {
        switch self {
        case .books: "book.closed"
        case .articles: "doc.text"
        case .websites: "safari"
        case .pdfs: "doc.richtext"
        case .news: "newspaper"
        case .movies: "play.rectangle"
        case .socialMedia: "bubble.left.and.bubble.right"
        case .workMaterials: "folder"
        }
    }
}

enum OnboardingLevel: String, CaseIterable, Codable, Identifiable {
    case starting
    case beginner
    case intermediate
    case advanced
    case unsure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .starting: String(localized: "onboarding.level.starting")
        case .beginner: String(localized: "onboarding.level.beginner")
        case .intermediate: String(localized: "onboarding.level.intermediate")
        case .advanced: String(localized: "onboarding.level.advanced")
        case .unsure: String(localized: "onboarding.level.unsure")
        }
    }

    var approximateCEFR: String? {
        switch self {
        case .starting: "A0–A1"
        case .beginner: "A1–A2"
        case .intermediate: "B1–B2"
        case .advanced: "C1–C2"
        case .unsure: nil
        }
    }

}

enum OnboardingState {
    static func canContinueWithLanguages(learning: SupportedLanguage, native: SupportedLanguage) -> Bool {
        learning != native
    }
}

enum OnboardingStore {
    static let completionKey = "luciusOnboardingCompleted"
    private static let stepKey = "luciusOnboardingStep"
    private static let goalsKey = "luciusOnboardingGoals"
    private static let contentKey = "luciusOnboardingContent"
    private static let levelKey = "luciusOnboardingLevel"
    private static let demoSavedKey = "luciusOnboardingDemoSaved"
    private static let demoLanguageKey = "luciusOnboardingDemoLanguage"

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: completionKey)
    }

    static var step: OnboardingStep {
        guard let value = UserDefaults.standard.string(forKey: stepKey),
              let step = OnboardingStep(rawValue: value) else { return .welcome }
        return step
    }

    static var goals: Set<OnboardingGoal> {
        Set(loadArray(forKey: goalsKey).compactMap(OnboardingGoal.init(rawValue:)))
    }

    static var contentSources: Set<OnboardingContentSource> {
        Set(loadArray(forKey: contentKey).compactMap(OnboardingContentSource.init(rawValue:)))
    }

    static var level: OnboardingLevel? {
        guard let value = UserDefaults.standard.string(forKey: levelKey) else { return nil }
        return OnboardingLevel(rawValue: value)
    }

    static var demoSaved: Bool {
        UserDefaults.standard.bool(forKey: demoSavedKey)
    }

    static var demoLanguageCode: String? {
        UserDefaults.standard.string(forKey: demoLanguageKey)
    }

    static func save(step: OnboardingStep) {
        UserDefaults.standard.set(step.rawValue, forKey: stepKey)
    }

    static func save(goals: Set<OnboardingGoal>) {
        UserDefaults.standard.set(goals.map(\.rawValue).sorted(), forKey: goalsKey)
    }

    static func save(contentSources: Set<OnboardingContentSource>) {
        UserDefaults.standard.set(contentSources.map(\.rawValue).sorted(), forKey: contentKey)
    }

    static func save(level: OnboardingLevel) {
        UserDefaults.standard.set(level.rawValue, forKey: levelKey)
    }

    static func markDemoSaved(languageCode: String) {
        UserDefaults.standard.set(true, forKey: demoSavedKey)
        UserDefaults.standard.set(languageCode, forKey: demoLanguageKey)
    }

    static func complete() {
        UserDefaults.standard.set(true, forKey: completionKey)
        UserDefaults.standard.set(OnboardingStep.completion.rawValue, forKey: stepKey)
        UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
    }

    #if DEBUG
    /// Development-only reset. It intentionally keeps the demo vocabulary row so
    /// restarting onboarding never creates a duplicate word.
    static func resetForDevelopment() {
        UserDefaults.standard.set(false, forKey: completionKey)
        UserDefaults.standard.set(OnboardingStep.welcome.rawValue, forKey: stepKey)
        UserDefaults.standard.set(false, forKey: "hasSeenWelcome")
    }
    #endif

    private static func loadArray(forKey key: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }
}

struct OnboardingDemoContent: Equatable {
    let learningLanguageCode: String
    let nativeLanguageCode: String
    let word: String
    let translation: String?
    let sentence: String
    let distractors: [String]
    let transcription: String?
    let partOfSpeech: String?
    let definition: String?
    let memoryTip: String?

    var clozeSentence: String {
        ContextReviewText.cloze(sentence: sentence, word: word) ?? sentence
    }

    static func make(learningLanguageCode: String, nativeLanguageCode: String) -> Self {
        let learning = SupportedLanguage(rawValue: learningLanguageCode)?.rawValue ?? SupportedLanguage.english.rawValue
        let native = SupportedLanguage(rawValue: nativeLanguageCode)?.rawValue ?? SupportedLanguage.english.rawValue
        let content = sourceContent[learning] ?? sourceContent["en"]!
        let translation = translations["\(learning)|\(native)"]
        return OnboardingDemoContent(
            learningLanguageCode: learningLanguageCode,
            nativeLanguageCode: nativeLanguageCode,
            word: content.word,
            translation: translation,
            sentence: content.sentence,
            distractors: content.distractors,
            transcription: content.transcription,
            partOfSpeech: content.partOfSpeech,
            definition: content.definition,
            memoryTip: content.memoryTip
        )
    }

    private struct SourceContent {
        let word: String
        let sentence: String
        let distractors: [String]
        let transcription: String?
        let partOfSpeech: String?
        let definition: String?
        let memoryTip: String?
    }

    private static let sourceContent: [String: SourceContent] = [
        "en": SourceContent(
            word: "abandon",
            sentence: "I decided to abandon my old job.",
            distractors: ["collect", "improve", "discover"],
            transcription: "/əˈbændən/",
            partOfSpeech: "Verb",
            definition: "To leave something behind or give it up.",
            memoryTip: "Picture putting down an old suitcase and walking forward."
        ),
        "es": SourceContent(
            word: "abandonar",
            sentence: "Decidí abandonar mi antiguo trabajo.",
            distractors: ["recoger", "mejorar", "descubrir"],
            transcription: "/aβandoˈnaɾ/",
            partOfSpeech: "Verbo",
            definition: "Dejar algo atrás o renunciar a ello.",
            memoryTip: "Imagina dejar una maleta vieja y seguir adelante."
        ),
        "fr": SourceContent(
            word: "abandonner",
            sentence: "J’ai décidé d’abandonner mon ancien travail.",
            distractors: ["collecter", "améliorer", "découvrir"],
            transcription: "/a.bɑ̃.dɔ.ne/",
            partOfSpeech: "Verbe",
            definition: "Quitter quelque chose ou y renoncer.",
            memoryTip: "Imagine poser une vieille valise et avancer."
        ),
        "de": SourceContent(
            word: "aufgeben",
            sentence: "Ich beschloss, meinen alten Job aufzugeben.",
            distractors: ["sammeln", "verbessern", "entdecken"],
            transcription: "/ˈaʊ̯fˌɡeːbn̩/",
            partOfSpeech: "Verb",
            definition: "Etwas verlassen oder nicht weiterführen.",
            memoryTip: "Stell dir vor, du lässt einen alten Koffer zurück."
        ),
        "uk": SourceContent(
            word: "покинути",
            sentence: "Я вирішив покинути свою стару роботу.",
            distractors: ["зібрати", "покращити", "відкрити"],
            transcription: nil,
            partOfSpeech: "Дієслово",
            definition: "Залишити щось або відмовитися від цього.",
            memoryTip: "Уяви, що залишаєш стару валізу й ідеш далі."
        ),
        "pl": SourceContent(
            word: "porzucić",
            sentence: "Postanowiłem porzucić swoją starą pracę.",
            distractors: ["zbierać", "poprawić", "odkryć"],
            transcription: nil,
            partOfSpeech: "Czasownik",
            definition: "Opuścić coś lub z czegoś zrezygnować.",
            memoryTip: "Wyobraź sobie, że zostawiasz starą walizkę."
        ),
        "pt-BR": SourceContent(
            word: "abandonar",
            sentence: "Decidi abandonar meu antigo emprego.",
            distractors: ["coletar", "melhorar", "descobrir"],
            transcription: nil,
            partOfSpeech: "Verbo",
            definition: "Deixar algo para trás ou desistir dele.",
            memoryTip: "Imagine deixar uma mala velha e seguir em frente."
        ),
        "it": SourceContent(
            word: "abbandonare",
            sentence: "Ho deciso di abbandonare il mio vecchio lavoro.",
            distractors: ["raccogliere", "migliorare", "scoprire"],
            transcription: nil,
            partOfSpeech: "Verbo",
            definition: "Lasciare qualcosa o rinunciarvi.",
            memoryTip: "Immagina di lasciare una vecchia valigia e andare avanti."
        ),
        "ja": SourceContent(
            word: "諦める",
            sentence: "私は古い仕事を諦めることにした。",
            distractors: ["集める", "改善する", "発見する"],
            transcription: nil,
            partOfSpeech: "動詞",
            definition: "何かを手放したり、やめたりすること。",
            memoryTip: "古いスーツケースを置いて前に進む姿を想像しましょう。"
        ),
        "ko": SourceContent(
            word: "포기하다",
            sentence: "나는 예전 직장을 포기하기로 했다.",
            distractors: ["모으다", "개선하다", "발견하다"],
            transcription: nil,
            partOfSpeech: "동사",
            definition: "무언가를 내려놓거나 그만두다.",
            memoryTip: "낡은 가방을 내려놓고 앞으로 걸어가는 모습을 떠올려 보세요."
        ),
        "zh-Hans": SourceContent(
            word: "放弃",
            sentence: "我决定放弃原来的工作。",
            distractors: ["收集", "改善", "发现"],
            transcription: nil,
            partOfSpeech: "动词",
            definition: "离开某件事或不再继续做它。",
            memoryTip: "想象放下旧行李，继续向前走。"
        )
    ]

    private static let translations: [String: String] = [
        "en|uk": "покинути", "en|es": "abandonar",
        "en|fr": "abandonner", "en|de": "aufgeben", "en|pl": "porzucić",
        "es|en": "to abandon", "es|uk": "покинути", "es|fr": "abandonner",
        "fr|en": "to abandon", "fr|uk": "покинути", "fr|de": "aufgeben",
        "de|en": "to give up", "de|uk": "покинути", "de|pl": "porzucić",
        "uk|en": "to leave", "uk|de": "verlassen", "uk|pl": "opuścić",
        "pl|en": "to abandon", "pl|uk": "покинути", "pl|de": "aufgeben",
        "pt-BR|en": "abandonar", "it|en": "abbandonare", "ja|en": "give up", "ko|en": "포기하다", "zh-Hans|en": "放弃"
    ]
}
