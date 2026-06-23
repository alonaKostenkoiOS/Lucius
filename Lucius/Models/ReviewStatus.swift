import Foundation

/// Learning progress of a word, advanced by review answers.
enum ReviewStatus: String, Codable, CaseIterable, Identifiable {
    case new
    case learning
    case familiar
    case mastered

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .new: "New"
        case .learning: "Learning"
        case .familiar: "Familiar"
        case .mastered: "Mastered"
        }
    }
}
