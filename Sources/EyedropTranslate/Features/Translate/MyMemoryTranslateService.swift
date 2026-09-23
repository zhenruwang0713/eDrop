import Foundation

/// 免费 MyMemory 英→中（无需 API Key）。
/// GET https://api.mymemory.translated.net/get?q=…&langpair=en|zh-CN&de=…
final class MyMemoryTranslateService: TranslateService {
    private let session: URLSession
    private let endpoint = URL(string: "https://api.mymemory.translated.net/get")!

    var engineDisplayName: String { PlaceholderStrings.settingsEngineMyMemory }

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            // ephemeral + 短超时；勿 waitsForConnectivity（会拖死再静默落到 Mock）
            let conf = URLSessionConfiguration.ephemeral
            conf.waitsForConnectivity = false
            conf.timeoutIntervalForRequest = 4
            conf.timeoutIntervalForResource = 5
            conf.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: conf)
        }
    }

    func translate(text: String, from: String, to: String) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslateError.emptyInput }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "langpair", value: "en|zh-CN"),
            // MyMemory free-tier tip（公开文档允许 email 参数提升配额；非密钥）
            URLQueryItem(name: "de", value: Constants.Translate.myMemoryContactEmail)
        ]
        guard let url = components.url else { throw TranslateError.network }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Constants.Translate.userAgent, forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 4

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 429 {
                    throw TranslateError.quota
                }
                if !(200...299).contains(http.statusCode) {
                    throw TranslateError.server(status: http.statusCode)
                }
            }

            let result = try Self.parseResilient(data: data, sourceText: trimmed)
            // 已有中文义项时不再被 Mock 占位覆盖
            return result.ensuringChineseGlosses()
        } catch let err as TranslateError {
            throw err
        } catch let err as URLError {
            switch err.code {
            case .timedOut: throw TranslateError.timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                throw TranslateError.network
            default: throw TranslateError.network
            }
        } catch is DecodingError {
            throw TranslateError.decoding
        } catch {
            throw TranslateError.network
        }
    }

    // MARK: - Resilient JSON (JSONSerialization first)

    /// Parse via JSONSerialization so weird `matches` / `quality` types never fail the whole decode.
    static func parseResilient(data: Data, sourceText: String) throws -> TranslationResult {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslateError.decoding
        }

        let status = intValue(root["responseStatus"]) ?? 0
        let details = stringValue(root["responseDetails"]) ?? ""
        let responseData = root["responseData"] as? [String: Any]
        let primaryText = stringValue(responseData?["translatedText"])

        if status == 429 || looksLikeWarning(primaryText) || looksLikeWarning(details) {
            throw TranslateError.quota
        }
        // Accept 200 (and treat missing status + valid text as OK)
        if status != 0 && status != 200 {
            // Non-200 body status without a usable translation
            if primaryText == nil || looksLikeWarning(primaryText) {
                if status == 429 { throw TranslateError.quota }
                throw TranslateError.server(status: status)
            }
        }

        var glosses: [String] = []

        if let primary = primaryText?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !primary.isEmpty,
           !looksLikeWarning(primary) {
            glosses.append(primary)
        }

        if let matches = root["matches"] as? [Any] {
            for item in matches {
                guard let dict = item as? [String: Any] else { continue }
                guard let t = stringValue(dict["translation"])?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !t.isEmpty,
                      !looksLikeWarning(t) else { continue }
                if !glosses.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                    glosses.append(t)
                }
                if glosses.count >= 3 { break }
            }
        }

        guard !glosses.isEmpty else { throw TranslateError.emptyResult }

        return TranslationResult(
            sourceText: sourceText,
            senses: glosses.prefix(3).map { TranslationSense(gloss: $0) },
            phonetic: nil,
            pos: nil,
            sourceEngine: .myMemory
        )
    }

    private static func looksLikeWarning(_ text: String?) -> Bool {
        guard let text, !text.isEmpty else { return false }
        let u = text.uppercased()
        return u.contains("MYMEMORY WARNING") || u.contains("YOU USED ALL AVAILABLE")
    }

    private static func stringValue(_ any: Any?) -> String? {
        switch any {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        default: return nil
        }
    }

    private static func intValue(_ any: Any?) -> Int? {
        switch any {
        case let i as Int: return i
        case let n as NSNumber: return n.intValue
        case let s as String: return Int(s.trimmingCharacters(in: .whitespacesAndNewlines))
        default: return nil
        }
    }
}

/// 主链失败时按序回退：MyMemory → Google → Lingva → Mock（仍保证中文释义；绝不向外抛错）
final class FallbackTranslateService: TranslateService {
    private let chain: [TranslateService]
    private let mock: TranslateService

    /// 上次是否走在线引擎成功（非 Mock）
    private(set) var lastUsedPrimary: Bool = true
    /// 在线链最近一次失败原因（供 Settings / 浮层脚注）
    private(set) var lastPrimaryErrorDescription: String?
    /// 短 tip：网络失败 / 额度用尽 / …
    private(set) var lastPrimaryErrorTip: String?
    /// 上次成功路径标签
    private(set) var lastEngineLabel: String = PlaceholderStrings.settingsEngineStatusIdle

    /// 配置说明：标明整条回退链
    var engineDisplayName: String { PlaceholderStrings.settingsEngineChainWithFallback }

    /// Settings 实时状态行
    var statusLine: String {
        var lines = [lastEngineLabel]
        if !lastUsedPrimary, let err = lastPrimaryErrorDescription, !err.isEmpty {
            lines.append("\(PlaceholderStrings.settingsEngineLastErrorPrefix)\(err)")
        }
        return lines.joined(separator: "\n")
    }

    init(
        chain: [TranslateService] = [MyMemoryTranslateService(), GoogleTranslateService(), LingvaTranslateService()],
        mock: TranslateService = MockTranslateService()
    ) {
        self.chain = chain
        self.mock = mock
    }

    /// 兼容旧两参调用：primary + secondary(Mock)
    convenience init(primary: TranslateService, secondary: TranslateService) {
        self.init(chain: [primary], mock: secondary)
    }

    func translate(text: String, from: String, to: String) async throws -> TranslationResult {
        var lastError: Error?
        for engine in chain {
            do {
                let result = try await engine.translate(text: text, from: from, to: to)
                    .ensuringChineseGlosses()
                // 必须有可展示中文；否则继续下一引擎（绝不把英译英当成功）
                guard result.hasDisplayableChineseSenses else {
                    lastError = TranslateError.emptyResult
                    continue
                }
                lastUsedPrimary = true
                lastPrimaryErrorDescription = nil
                lastPrimaryErrorTip = nil
                lastEngineLabel = Self.label(for: result.sourceEngine, engine: engine)
                let engineTag = result.sourceEngine ?? Self.tag(for: engine)
                return result.withSourceEngine(engineTag)
            } catch {
                lastError = error
                continue
            }
        }

        let err = lastError ?? TranslateError.network
        lastUsedPrimary = false
        lastPrimaryErrorDescription = Self.describe(err)
        lastPrimaryErrorTip = Self.shortTip(err)
        lastEngineLabel = PlaceholderStrings.settingsEngineLastMockFallback

        // 绝不向外抛错：Mock 必须成功；若被取消也返回中文占位
        do {
            let result = try await mock.translate(text: text, from: from, to: to)
                .ensuringChineseGlosses()
            return result
                .withSourceEngine(.mock)
                .withFallbackErrorTip(lastPrimaryErrorTip)
        } catch is CancellationError {
            return MockTranslateService.guaranteedChinese(
                for: text,
                tip: lastPrimaryErrorTip ?? PlaceholderStrings.overlayMockTipTimeout
            )
        } catch {
            return MockTranslateService.guaranteedChinese(
                for: text,
                tip: lastPrimaryErrorTip ?? Self.shortTip(error)
            )
        }
    }

    private static func label(for source: TranslationSourceEngine?, engine: TranslateService) -> String {
        switch source {
        case .myMemory: return PlaceholderStrings.settingsEngineLastMyMemory
        case .google: return PlaceholderStrings.settingsEngineLastGoogle
        case .lingva: return PlaceholderStrings.settingsEngineLastLingva
        case .remote: return PlaceholderStrings.settingsEngineLastRemote
        case .mock: return PlaceholderStrings.settingsEngineLastMockFallback
        case .none:
            if engine is MyMemoryTranslateService {
                return PlaceholderStrings.settingsEngineLastMyMemory
            }
            if engine is GoogleTranslateService {
                return PlaceholderStrings.settingsEngineLastGoogle
            }
            if engine is LingvaTranslateService {
                return PlaceholderStrings.settingsEngineLastLingva
            }
            return engine.engineDisplayName
        }
    }

    private static func tag(for engine: TranslateService) -> TranslationSourceEngine {
        if engine is MyMemoryTranslateService { return .myMemory }
        if engine is GoogleTranslateService { return .google }
        if engine is LingvaTranslateService { return .lingva }
        if engine is URLSessionTranslateService { return .remote }
        return .mock
    }

    static func describe(_ error: Error) -> String {
        if let te = error as? TranslateError {
            switch te {
            case .timeout: return "超时"
            case .network: return "网络异常"
            case .decoding: return "解析失败"
            case .quota: return "配额/429"
            case .emptyResult: return "空结果"
            case .emptyInput: return "空输入"
            case .server(let status): return "服务端\(status.map(String.init) ?? "?")"
            }
        }
        return (error as NSError).localizedDescription
    }

    /// 浮层脚注短 tip
    static func shortTip(_ error: Error) -> String {
        if let te = error as? TranslateError {
            switch te {
            case .timeout: return PlaceholderStrings.overlayMockTipTimeout
            case .network: return PlaceholderStrings.overlayMockTipNetwork
            case .quota: return PlaceholderStrings.overlayMockTipQuota
            case .decoding: return PlaceholderStrings.overlayMockTipDecode
            case .emptyResult, .emptyInput: return PlaceholderStrings.overlayMockTipEmpty
            case .server: return PlaceholderStrings.overlayMockTipServer
            }
        }
        return PlaceholderStrings.overlayMockTipNetwork
    }
}
