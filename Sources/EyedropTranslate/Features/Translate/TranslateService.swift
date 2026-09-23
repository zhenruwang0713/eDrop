import Foundation

/// 翻译服务协议（EN→ZH）
protocol TranslateService: AnyObject {
    var engineDisplayName: String { get }
    /// Settings 实时状态（默认等同 engineDisplayName）
    var statusLine: String { get }
    func translate(text: String, from: String, to: String) async throws -> TranslationResult
}

extension TranslateService {
    var statusLine: String { engineDisplayName }

    func translateENToZH(_ text: String) async throws -> TranslationResult {
        try await translate(
            text: text,
            from: Constants.Translate.sourceLanguage,
            to: Constants.Translate.targetLanguage
        )
    }
}

/// 从环境变量 / Info.plist 读取 API 配置（永不硬编码密钥）
struct TranslateAPIConfig: Equatable {
    let baseURL: URL?
    let apiKey: String?

    var hasRemoteEndpoint: Bool {
        baseURL != nil
    }

    /// 有自定义 base URL → 远程客户端；否则默认 MyMemory → Google → Lingva → Mock
    var shouldUseCustomRemote: Bool {
        baseURL != nil
    }

    static func load(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> TranslateAPIConfig {
        let envURL = environment[Constants.Translate.envBaseURLKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let plistURL = (bundle.object(forInfoDictionaryKey: Constants.Translate.plistBaseURLKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = [envURL, plistURL]
            .compactMap { $0 }
            .first { !$0.isEmpty }

        let envKey = environment[Constants.Translate.envAPIKeyKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let plistKey = (bundle.object(forInfoDictionaryKey: Constants.Translate.plistAPIKeyKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let key = [envKey, plistKey]
            .compactMap { $0 }
            .first { !$0.isEmpty }

        return TranslateAPIConfig(
            baseURL: urlString.flatMap(URL.init(string:)),
            apiKey: key
        )
    }
}

/// 装配：有自定义 Base URL → URLSession；否则 Caching(Fallback(MyMemory → Google → Lingva → Mock))
enum TranslateServiceFactory {
    @MainActor
    static func make(config: TranslateAPIConfig = .load()) -> TranslateService {
        let cache = TranslationCache()
        if config.shouldUseCustomRemote {
            let remote = URLSessionTranslateService(config: config)
            return CachingTranslateService(inner: remote, cache: cache)
        }
        let fallback = FallbackTranslateService(
            chain: [MyMemoryTranslateService(), GoogleTranslateService(), LingvaTranslateService()],
            mock: MockTranslateService()
        )
        return CachingTranslateService(inner: fallback, cache: cache)
    }
}

/// 缓存装饰器
final class CachingTranslateService: TranslateService {
    private let inner: TranslateService
    private let cache: TranslationCache

    var engineDisplayName: String { inner.engineDisplayName }
    var statusLine: String { inner.statusLine }

    /// 供 Coordinator 读取 Fallback 状态（若内层是 Fallback）
    var fallbackService: FallbackTranslateService? { inner as? FallbackTranslateService }

    init(inner: TranslateService, cache: TranslationCache) {
        self.inner = inner
        self.cache = cache
    }

    func translate(text: String, from: String, to: String) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslateError.emptyInput }
        if let hit = cache.value(for: trimmed) {
            return hit.ensuringChineseGlosses()
        }
        let result = try await inner.translate(text: trimmed, from: from, to: to)
            .ensuringChineseGlosses()
        cache.insert(result)
        return result
    }
}
