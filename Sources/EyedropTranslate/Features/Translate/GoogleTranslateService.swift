import Foundation

/// 免费 Google（Chrome dict 端点）英→中，无需 API Key。
/// GET https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=en&tl=zh-CN&q=…
/// 响应形如 `["你好"]` 或嵌套数组；短超时，供 Fallback 链快速备援。
final class GoogleTranslateService: TranslateService {
    private let session: URLSession
    private let endpoint = URL(string: "https://clients5.google.com/translate_a/t")!

    /// request 4s / resource 5s（本引擎专用，短于全局默认）
    private static let requestTimeout: TimeInterval = 4
    private static let resourceTimeout: TimeInterval = 5

    var engineDisplayName: String { PlaceholderStrings.settingsEngineGoogle }

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let conf = URLSessionConfiguration.ephemeral
            conf.waitsForConnectivity = false
            conf.timeoutIntervalForRequest = Self.requestTimeout
            conf.timeoutIntervalForResource = Self.resourceTimeout
            conf.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: conf)
        }
    }

    func translate(text: String, from: String, to: String) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslateError.emptyInput }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client", value: "dict-chrome-ex"),
            URLQueryItem(name: "sl", value: "en"),
            URLQueryItem(name: "tl", value: "zh-CN"),
            URLQueryItem(name: "q", value: trimmed)
        ]
        guard let url = components.url else { throw TranslateError.network }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Constants.Translate.userAgent, forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = Self.requestTimeout

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 429 {
                    throw TranslateError.quota
                }
                if !(200...299).contains(http.statusCode) {
                    throw TranslateError.server(status: http.statusCode)
                }
                let mime = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
                if mime.contains("html") {
                    throw TranslateError.decoding
                }
            }
            // HTML 拦截页常以 < 开头
            if let prefix = String(data: data.prefix(8), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               prefix.hasPrefix("<") {
                throw TranslateError.decoding
            }

            let gloss = try Self.parseGloss(data: data, sourceText: trimmed)
            return TranslationResult(
                sourceText: trimmed,
                senses: [TranslationSense(gloss: gloss)],
                phonetic: nil,
                pos: nil,
                sourceEngine: .google
            ).ensuringChineseGlosses()
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

    /// 健壮解析：`["你好"]` / `[["你好","hello",…],…]` 等 → 第一个含汉字且非原文回显的字符串。
    static func parseGloss(data: Data, sourceText: String) throws -> String {
        // jsonObject 返回 Any（非 Optional），不能 guard let
        let root = try JSONSerialization.jsonObject(with: data)
        var candidates: [String] = []
        collectStrings(from: root, into: &candidates)

        let src = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        for raw in candidates {
            let g = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !g.isEmpty else { continue }
            let hasHan = g.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
            guard hasHan else { continue }
            if g.compare(src, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
                continue
            }
            return g
        }
        throw TranslateError.emptyResult
    }

    private static func collectStrings(from any: Any, into out: inout [String]) {
        switch any {
        case let s as String:
            out.append(s)
        case let arr as [Any]:
            for item in arr {
                collectStrings(from: item, into: &out)
            }
        case let dict as [String: Any]:
            for value in dict.values {
                collectStrings(from: value, into: &out)
            }
        default:
            break
        }
    }
}
