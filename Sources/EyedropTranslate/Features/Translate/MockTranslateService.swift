import Foundation

/// 本地 Mock：MyMemory 失败/无网时 dogfood，**始终返回中文释义字符串**（禁止空 gloss / 英译英）。
final class MockTranslateService: TranslateService {
    var engineDisplayName: String { PlaceholderStrings.settingsEngineMock }

    /// 常见词/短语 → 1–3 条中文释义（hello → 你好 等）
    private let glossary: [String: TranslationResult] = {
        func entry(
            _ src: String,
            phonetic: String? = nil,
            pos: String? = nil,
            glosses: [(String, String?)]
        ) -> TranslationResult {
            TranslationResult(
                sourceText: src,
                senses: glosses.map { TranslationSense(gloss: $0.0, pos: $0.1 ?? pos, phonetic: nil) },
                phonetic: phonetic,
                pos: pos
            )
        }

        let entries: [TranslationResult] = [
            entry("hello", phonetic: "/həˈləʊ/", pos: "int.", glosses: [("你好", "int."), ("喂；问候", "int.")]),
            entry("yo", phonetic: "/joʊ/", pos: "int.", glosses: [("喂；嗨（口语招呼）", "int."), ("哟（感叹）", "int.")]),
            entry("hi", phonetic: "/haɪ/", pos: "int.", glosses: [("嗨；你好", "int.")]),
            entry("hey", phonetic: "/heɪ/", pos: "int.", glosses: [("嘿；喂", "int.")]),
            entry("ok", phonetic: nil, pos: "int.", glosses: [("好的；行", "int."), ("可以", "adj.")]),
            entry("okay", phonetic: nil, pos: "int.", glosses: [("好的；行", "int.")]),
            entry("yes", phonetic: "/jes/", pos: "int.", glosses: [("是；是的", "int."), ("同意", "int.")]),
            entry("no", phonetic: "/nəʊ/", pos: "int.", glosses: [("不；没有", "int."), ("否", "int.")]),
            entry("good", phonetic: "/ɡʊd/", pos: "adj.", glosses: [("好的；优良的", "adj."), ("令人愉快的", "adj.")]),
            entry("bad", phonetic: "/bæd/", pos: "adj.", glosses: [("坏的；糟糕的", "adj."), ("有害的", "adj.")]),
            entry("time", phonetic: "/taɪm/", pos: "n.", glosses: [("时间", "n."), ("时刻；时代", "n.")]),
            entry("book", phonetic: "/bʊk/", pos: "n.", glosses: [("书；书籍", "n."), ("预订", "v.")]),
            entry("computer", phonetic: "/kəmˈpjuːtə/", pos: "n.", glosses: [("计算机；电脑", "n.")]),
            entry("dog", phonetic: "/dɒɡ/", pos: "n.", glosses: [("狗", "n.")]),
            entry("cat", phonetic: "/kæt/", pos: "n.", glosses: [("猫", "n.")]),
            entry("world", phonetic: "/wɜːld/", pos: "n.", glosses: [("世界", "n."), ("领域；界", "n.")]),
            entry("translate", phonetic: "/trænsˈleɪt/", pos: "v.", glosses: [("翻译", "v."), ("转化", "v.")]),
            entry("selection", phonetic: "/sɪˈlekʃn/", pos: "n.", glosses: [("选区；选择", "n."), ("精选", "n.")]),
            entry("accessibility", phonetic: "/əkˌsesəˈbɪləti/", pos: "n.", glosses: [("辅助功能；无障碍", "n."), ("可访问性", "n.")]),
            entry("overlay", phonetic: "/ˈəʊvəleɪ/", pos: "n.", glosses: [("浮层；覆盖层", "n."), ("叠层", "n.")]),
            entry("eyedropper", phonetic: "/ˈaɪˌdrɒpə/", pos: "n.", glosses: [("吸管（取色/取词）", "n.")]),
            entry("dogfood", pos: "v.", glosses: [("自用测试（吃自己的狗粮）", "v.")]),
            entry("permission", phonetic: "/pəˈmɪʃn/", pos: "n.", glosses: [("权限；许可", "n.")]),
            entry("network", phonetic: "/ˈnetwɜːk/", pos: "n.", glosses: [("网络", "n."), ("人脉", "n.")]),
            entry("timeout", pos: "n.", glosses: [("超时", "n.")]),
            entry("retry", phonetic: "/ˈriːtraɪ/", pos: "v.", glosses: [("重试", "v.")]),
            entry("loading", pos: "n.", glosses: [("加载中", "n.")]),
            entry("failure", phonetic: "/ˈfeɪljə/", pos: "n.", glosses: [("失败", "n.")]),
            entry("success", phonetic: "/səkˈses/", pos: "n.", glosses: [("成功", "n.")]),
            entry("apple", phonetic: "/ˈæpl/", pos: "n.", glosses: [("苹果", "n."), ("苹果公司", "n.")]),
            entry("swift", phonetic: "/swɪft/", pos: "n.", glosses: [("Swift 语言", "n."), ("迅速的", "adj.")]),
            entry("menu", phonetic: "/ˈmenjuː/", pos: "n.", glosses: [("菜单", "n.")]),
            entry("hotkey", pos: "n.", glosses: [("快捷键", "n.")]),
            entry("cache", phonetic: "/kæʃ/", pos: "n.", glosses: [("缓存", "n.")]),
            entry("please select text", glosses: [("请先选中文本", nil)]),
            entry("good morning", pos: "phrase", glosses: [("早上好", "phrase")]),
            entry("thank you", pos: "phrase", glosses: [("谢谢你", "phrase")]),
            entry("machine learning", pos: "n.", glosses: [("机器学习", "n.")]),
            entry("and their families.", pos: "phrase", glosses: [("以及他们的家人。", "phrase")]),
        ]

        var dict: [String: TranslationResult] = [:]
        for e in entries {
            dict[TranslationCache.normalize(e.sourceText)] = e
        }
        return dict
    }()

    func translate(text: String, from: String, to: String) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslateError.emptyInput }

        // 模拟网络延迟，便于看到 loading → success
        try await Task.sleep(nanoseconds: 280_000_000)

        if let hit = lookup(trimmed) {
            return TranslationResult(
                sourceText: trimmed,
                senses: hit.senses,
                phonetic: hit.phonetic,
                pos: hit.pos,
                sourceEngine: .mock
            ).ensuringChineseGlosses()
        }

        // 未知词/短语：必须产出中文义项，禁止空 gloss / 把英文原文当作释义
        return Self.chinesePlaceholder(for: trimmed)
            .withSourceEngine(.mock)
            .ensuringChineseGlosses()
    }

    private func lookup(_ text: String) -> TranslationResult? {
        let key = TranslationCache.normalize(text)
        if let hit = glossary[key] { return hit }
        // 去首尾标点再试（网页划选常带逗号/句号/引号）
        let stripped = key.trimmingCharacters(in: .punctuationCharacters.union(.symbols))
        if stripped != key, let hit = glossary[stripped] { return hit }
        return nil
    }


    /// 无 sleep、不抛错：供 Fallback / Coordinator 兜底（CancellationError 后仍出中文）
    static func guaranteedChinese(for text: String, tip: String? = nil) -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let service = MockTranslateService()
        let base: TranslationResult
        if let hit = service.lookup(trimmed) {
            base = TranslationResult(
                sourceText: trimmed,
                senses: hit.senses,
                phonetic: hit.phonetic,
                pos: hit.pos,
                sourceEngine: .mock
            )
        } else {
            base = chinesePlaceholder(for: trimmed)
        }
        return base
            .withSourceEngine(.mock)
            .withFallbackErrorTip(tip)
            .ensuringChineseGlosses()
    }

    /// 未知词中文占位（永远含汉字；不把「请配置 API」当作主释义）
    private static func chinesePlaceholder(for trimmed: String) -> TranslationResult {
        if trimmed.contains(where: { $0.isWhitespace }) || trimmed.count > 24 {
            return TranslationResult(
                sourceText: trimmed,
                senses: [
                    TranslationSense(
                        gloss: "「\(trimmed)」可译为：……（本地示意）",
                        pos: "phrase"
                    ),
                    TranslationSense(
                        gloss: "本地示意：这段英文的中文意思",
                        pos: nil
                    )
                ],
                phonetic: nil,
                pos: "phrase"
            )
        }
        return TranslationResult(
            sourceText: trimmed,
            senses: [
                TranslationSense(gloss: "「\(trimmed)」可译为：……（本地示意）", pos: "n."),
                TranslationSense(gloss: "本地示意：「\(trimmed)」的中文意思", pos: "n.")
            ],
            phonetic: nil,
            pos: "n."
        )
    }
}
