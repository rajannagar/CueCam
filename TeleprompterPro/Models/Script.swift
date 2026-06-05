import Foundation

struct Script: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var body: String
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "", body: String = "", updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.body = body
        self.updatedAt = updatedAt
    }

    /// Rough reading time estimate at ~130 words per minute (a calm speaking pace).
    var estimatedReadSeconds: Int {
        let words = body.split { $0 == " " || $0 == "\n" }.count
        return max(1, Int((Double(words) / 130.0) * 60.0))
    }

    var wordCount: Int {
        body.split { $0 == " " || $0 == "\n" }.count
    }

    var preview: String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Empty script" : trimmed
    }
}
