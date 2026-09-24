import Foundation

/// One recommendation returned by the model, resolved against the local disk.
struct AISuggestion: Identifiable, Hashable, Codable {
    enum Confidence: String, Codable, CaseIterable {
        case high, medium, low

        var label: String { rawValue.capitalized }
    }

    enum Action: String, Codable {
        case trash, review, keep
    }

    var id: String { path }
    let path: String
    let action: Action
    let reason: String
    let confidence: Confidence
    let category: String?
    /// Filled in locally; the model never sees or invents sizes we did not send.
    var size: Int64
    var exists: Bool
    var isDirectory: Bool
}

struct AIAnalysis: Codable, Hashable {
    let summary: String
    let suggestions: [AISuggestion]
    let model: String
    let promptTokens: Int
    let completionTokens: Int
    let cost: Double?
    let createdAt: Date

    var reclaimable: Int64 {
        suggestions.filter { $0.action == .trash && $0.exists }.reduce(0) { $0 + $1.size }
    }
}
