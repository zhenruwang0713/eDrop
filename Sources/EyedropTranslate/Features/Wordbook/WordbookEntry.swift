import Foundation

/// 划词本条目（本地 MVP · 对齐 wordbook-ia.md）
struct WordbookEntry: Codable, Equatable, Identifiable, Hashable {
    var id: UUID
    var source: String
    var gloss: String
    var createdAt: Date
    /// 来源 App 显示名（可得则记）
    var sourceApp: String?

    init(
        id: UUID = UUID(),
        source: String,
        gloss: String,
        createdAt: Date = Date(),
        sourceApp: String? = nil
    ) {
        self.id = id
        self.source = source
        self.gloss = gloss
        self.createdAt = createdAt
        self.sourceApp = sourceApp
    }
}
