import Foundation

/// 短时内存缓存：归一化原文 → 结果；TTL + 容量上限（简易 LRU）
final class TranslationCache: @unchecked Sendable {
    private struct Entry {
        let result: TranslationResult
        let expiresAt: Date
    }

    private let lock = NSLock()
    private var store: [String: Entry] = [:]
    private var order: [String] = []
    private let ttl: TimeInterval
    private let capacity: Int

    init(ttl: TimeInterval = Constants.Translate.cacheTTL,
         capacity: Int = Constants.Translate.cacheCapacity) {
        self.ttl = ttl
        self.capacity = max(1, capacity)
    }

    static func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    func value(for text: String) -> TranslationResult? {
        let key = Self.normalize(text)
        lock.lock()
        defer { lock.unlock() }
        guard let entry = store[key] else { return nil }
        if entry.expiresAt < Date() {
            store.removeValue(forKey: key)
            order.removeAll { $0 == key }
            return nil
        }
        // LRU bump
        order.removeAll { $0 == key }
        order.append(key)
        return entry.result
    }

    func insert(_ result: TranslationResult) {
        let key = Self.normalize(result.sourceText)
        lock.lock()
        defer { lock.unlock() }
        store[key] = Entry(result: result, expiresAt: Date().addingTimeInterval(ttl))
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > capacity {
            let evict = order.removeFirst()
            store.removeValue(forKey: evict)
        }
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        store.removeAll()
        order.removeAll()
    }
}
