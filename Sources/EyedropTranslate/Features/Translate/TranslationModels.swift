import Foundation

/// 单条中文释义（浮层展示 1–3 条）
struct TranslationSense: Codable, Equatable, Hashable, Identifiable {
    var id: String { "\(pos ?? "")|\(gloss)" }
    let gloss: String
    let pos: String?
    let phonetic: String?

    enum CodingKeys: String, CodingKey {
        case gloss, pos, phonetic, text, meaning
    }

    init(gloss: String, pos: String? = nil, phonetic: String? = nil) {
        self.gloss = gloss
        self.pos = pos
        self.phonetic = phonetic
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let g = try c.decodeIfPresent(String.self, forKey: .gloss) {
            gloss = g
        } else if let g = try c.decodeIfPresent(String.self, forKey: .text) {
            gloss = g
        } else if let g = try c.decodeIfPresent(String.self, forKey: .meaning) {
            gloss = g
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .gloss, in: c, debugDescription: "sense missing gloss/text/meaning"
            )
        }
        pos = try c.decodeIfPresent(String.self, forKey: .pos)
        phonetic = try c.decodeIfPresent(String.self, forKey: .phonetic)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(gloss, forKey: .gloss)
        try c.encodeIfPresent(pos, forKey: .pos)
        try c.encodeIfPresent(phonetic, forKey: .phonetic)
    }
}

/// 实际产出本次结果的引擎（Settings / 浮层示意用）
enum TranslationSourceEngine: String, Equatable {
    case myMemory
    case google
    case lingva
    case mock
    case remote
}

/// 翻译结果（浮层 success 态）
struct TranslationResult: Equatable {
    let sourceText: String
    let senses: [TranslationSense]
    /// 词级音标占位（可空）
    let phonetic: String?
    /// 词性占位（可空）
    let pos: String?
    /// 可选：来源引擎（Mock 回退时浮层脚注「离线示意」）
    let sourceEngine: TranslationSourceEngine?
    /// Mock 回退原因短 tip（网络失败 / 额度用尽…），供浮层脚注
    let fallbackErrorTip: String?

    init(
        sourceText: String,
        senses: [TranslationSense],
        phonetic: String? = nil,
        pos: String? = nil,
        sourceEngine: TranslationSourceEngine? = nil,
        fallbackErrorTip: String? = nil
    ) {
        self.sourceText = sourceText
        self.senses = senses
        self.phonetic = phonetic
        self.pos = pos
        self.sourceEngine = sourceEngine
        self.fallbackErrorTip = fallbackErrorTip
    }

    func withSourceEngine(_ engine: TranslationSourceEngine?) -> TranslationResult {
        TranslationResult(
            sourceText: sourceText,
            senses: senses,
            phonetic: phonetic,
            pos: pos,
            sourceEngine: engine,
            fallbackErrorTip: fallbackErrorTip
        )
    }

    func withFallbackErrorTip(_ tip: String?) -> TranslationResult {
        TranslationResult(
            sourceText: sourceText,
            senses: senses,
            phonetic: phonetic,
            pos: pos,
            sourceEngine: sourceEngine,
            fallbackErrorTip: tip
        )
    }

    /// 是否来自 Mock 回退（成功但仍需「离线示意」脚注）
    var isMockFallback: Bool { sourceEngine == .mock }

    var primaryPhonetic: String? {
        phonetic ?? senses.compactMap(\.phonetic).first
    }

    var primaryPOS: String? {
        pos ?? senses.compactMap(\.pos).first
    }

    /// 是否至少有一条可展示的中文释义（含汉字，且非原文回显）
    var hasDisplayableChineseSenses: Bool {
        let src = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        return senses.contains { sense in
            let g = sense.gloss.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !g.isEmpty else { return false }
            if Self.isEnglishEchoGloss(g, source: src) { return false }
            // 至少含一个汉字，才算「真实中文」成功（避免英译英被当成成功）
            return g.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
        }
    }

    /// 保证浮层 success 一定有 1–3 条可展示的中文 gloss（空/英译英时补本地中文占位）。
    func ensuringChineseGlosses() -> TranslationResult {
        let src = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)

        let cleaned = senses
            .map {
                TranslationSense(
                    gloss: $0.gloss.trimmingCharacters(in: .whitespacesAndNewlines),
                    pos: $0.pos,
                    phonetic: $0.phonetic
                )
            }
            .filter { sense in
                let g = sense.gloss
                guard !g.isEmpty else { return false }
                if Self.isEnglishEchoGloss(g, source: src) { return false }
                return true
            }

        // 优先保留含汉字或中文提示的义项
        let ranked = cleaned.sorted { a, b in
            Self.chineseScore(a.gloss) > Self.chineseScore(b.gloss)
        }

        if !ranked.isEmpty {
            return TranslationResult(
                sourceText: sourceText,
                senses: Array(ranked.prefix(3)),
                phonetic: phonetic,
                pos: pos,
                sourceEngine: sourceEngine,
                fallbackErrorTip: fallbackErrorTip
            )
        }

        // 在线引擎（MyMemory / Lingva / remote）已有或应有真实结果时，
        // 绝不注入 Mock「本地示意」占位覆盖；留给 Fallback 链继续尝试。
        if sourceEngine == .myMemory || sourceEngine == .google || sourceEngine == .lingva || sourceEngine == .remote {
            return TranslationResult(
                sourceText: sourceText,
                senses: cleaned.isEmpty ? senses : Array(cleaned.prefix(3)),
                phonetic: phonetic,
                pos: pos,
                sourceEngine: sourceEngine,
                fallbackErrorTip: fallbackErrorTip
            )
        }

        return TranslationResult(
            sourceText: sourceText,
            senses: [
                TranslationSense(gloss: "「\(src)」可译为：……（本地示意）", pos: pos ?? "n."),
                TranslationSense(gloss: "本地示意：「\(src)」的中文意思", pos: nil)
            ],
            phonetic: phonetic,
            pos: pos,
            sourceEngine: sourceEngine ?? .mock,
            fallbackErrorTip: fallbackErrorTip
        )
    }


    /// 英译英 / Mock 回显 / 无汉字的伪释义
    private static func isEnglishEchoGloss(_ gloss: String, source: String) -> Bool {
        let g = gloss.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = g.lowercased()
        let srcLower = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.isEmpty { return true }
        if lower == srcLower { return true }
        // （Mock）yo / (Mock) yo / Mock: yo
        let compact = lower.replacingOccurrences(of: " ", with: "")
        let srcCompact = srcLower.replacingOccurrences(of: " ", with: "")
        if compact == "(mock)\(srcCompact)" || compact == "（mock）\(srcCompact)" { return true }
        if compact.hasPrefix("(mock)") && compact.contains(srcCompact) { return true }
        if compact.hasPrefix("（mock）") && compact.contains(srcCompact) { return true }
        // 完全没有汉字，且主要是拉丁字母 → 不当作中文释义
        let hasHan = g.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
        if !hasHan {
            let letters = g.unicodeScalars.filter { CharacterSet.letters.contains($0) }
            let latin = letters.filter {
                ($0.value >= 0x41 && $0.value <= 0x5A) || ($0.value >= 0x61 && $0.value <= 0x7A)
            }
            if !letters.isEmpty && latin.count == letters.count { return true }
        }
        return false
    }

    private static func chineseScore(_ text: String) -> Int {
        var score = 0
        if text.unicodeScalars.contains(where: { $0.value >= 0x4E00 && $0.value <= 0x9FFF }) {
            score += 10
        }
        if text.contains("可译为") || text.contains("本地示意") || text.contains("中文") {
            score += 5
        }
        return score
    }
}

/// 通用 JSON 请求体（后端可插拔）
struct TranslateRequestBody: Encodable {
    let text: String
    let from: String
    let to: String
}

/// 通用 JSON 响应体
struct TranslateResponseBody: Decodable {
    let senses: [TranslationSense]?
    let phonetic: String?
    let pos: String?
    /// 部分后端用 translations / meanings
    let translations: [String]?
    let meanings: [String]?

    func toResult(sourceText: String) -> TranslationResult? {
        var list: [TranslationSense] = senses ?? []
        if list.isEmpty, let translations {
            list = translations.map { TranslationSense(gloss: $0) }
        }
        if list.isEmpty, let meanings {
            list = meanings.map { TranslationSense(gloss: $0) }
        }
        let trimmed = list
            .map { TranslationSense(gloss: $0.gloss.trimmingCharacters(in: .whitespacesAndNewlines), pos: $0.pos, phonetic: $0.phonetic) }
            .filter { !$0.gloss.isEmpty }
        guard !trimmed.isEmpty else { return nil }
        return TranslationResult(
            sourceText: sourceText,
            senses: Array(trimmed.prefix(3)),
            phonetic: phonetic,
            pos: pos,
            sourceEngine: .remote
        ).ensuringChineseGlosses()
    }
}

enum TranslateError: Error, Equatable {
    case emptyInput
    case emptyResult
    case timeout
    case network
    case server(status: Int?)
    case decoding
    /// 日配额 / HTTP 429 — 供 Fallback 切到下一引擎 / Mock
    case quota

    var userMessage: String {
        switch self {
        case .emptyInput: return PlaceholderStrings.failNoSelection
        case .emptyResult: return PlaceholderStrings.failEmptyResult
        case .timeout: return PlaceholderStrings.failTimeout
        case .network: return PlaceholderStrings.failNetwork
        case .server, .decoding, .quota: return PlaceholderStrings.failServer
        }
    }
}
