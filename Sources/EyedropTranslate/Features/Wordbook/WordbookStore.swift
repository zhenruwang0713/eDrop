import Foundation

/// 本地划词本：JSON 文件持久化，最多 200 条；同 source 去重并更新 gloss。
@MainActor
final class WordbookStore: ObservableObject {
    static let shared = WordbookStore()

    @Published private(set) var entries: [WordbookEntry] = []

    private let maxEntries = Constants.Wordbook.maxEntries
    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = dir.appendingPathComponent("eDrop", isDirectory: true)
        let legacy = dir.appendingPathComponent("EyedropTranslate", isDirectory: true)
        let fm = FileManager.default
        if !fm.fileExists(atPath: folder.path), fm.fileExists(atPath: legacy.path) {
            try? fm.moveItem(at: legacy, to: folder)
        }
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        // 若新目录无词本而旧目录仍有文件，复制过来（部分迁移失败时的兜底）
        let legacyFile = legacy.appendingPathComponent("wordbook.json")
        let newFile = folder.appendingPathComponent("wordbook.json")
        if !fm.fileExists(atPath: newFile.path), fm.fileExists(atPath: legacyFile.path) {
            try? fm.copyItem(at: legacyFile, to: newFile)
        }
        fileURL = newFile
        load()
    }

    /// 时间倒序
    var entriesNewestFirst: [WordbookEntry] {
        entries.sorted { $0.createdAt > $1.createdAt }
    }

    func filtered(query: String) -> [WordbookEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = entriesNewestFirst
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.source.lowercased().contains(q) || $0.gloss.lowercased().contains(q)
        }
    }

    /// 成功译后收录：同 source（忽略大小写/空白）更新 gloss 与时间；含 mock。
    @discardableResult
    func upsert(source: String, gloss: String, sourceApp: String? = nil) -> WordbookEntry {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGloss = gloss.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = Self.normalizeKey(trimmedSource)

        if let idx = entries.firstIndex(where: { Self.normalizeKey($0.source) == key }) {
            entries[idx].gloss = trimmedGloss.isEmpty ? entries[idx].gloss : trimmedGloss
            entries[idx].createdAt = Date()
            if let sourceApp, !sourceApp.isEmpty {
                entries[idx].sourceApp = sourceApp
            }
            let updated = entries[idx]
            persist()
            return updated
        }

        let entry = WordbookEntry(
            source: trimmedSource,
            gloss: trimmedGloss,
            sourceApp: sourceApp
        )
        entries.insert(entry, at: 0)
        trimIfNeeded()
        persist()
        return entry
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func delete(_ entry: WordbookEntry) {
        delete(id: entry.id)
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            entries = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            entries = try decoder.decode([WordbookEntry].self, from: data)
            trimIfNeeded()
        } catch {
            entries = []
        }
    }

    private func persist() {
        do {
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // 本地 MVP：写失败静默（后续可加日志）
        }
    }

    private func trimIfNeeded() {
        if entries.count > maxEntries {
            entries = Array(entries.sorted { $0.createdAt > $1.createdAt }.prefix(maxEntries))
        }
    }

    static func normalizeKey(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }
}
