import Foundation

/// 免费 Lingva 英→中（无需 API Key）。
/// GET https://lingva.ml/api/v1/en/zh/{urlencoded}
/// 失败时再试 https://lingva.thedaviddelta.com/api/v1/en/zh/...
final class LingvaTranslateService: TranslateService {
    private let session: URLSession
    private let hosts: [String] = [
        "https://lingva.ml/api/v1/en/zh",
        "https://lingva.thedaviddelta.com/api/v1/en/zh"
    ]

    var engineDisplayName: String { PlaceholderStrings.settingsEngineLingva }

    /// 每 host 短超时（3–4s），避免 Cloudflare HTML 拖死整条 Fallback 链
    private static let requestTimeout: TimeInterval = 3.5
    private static let resourceTimeout: TimeInterval = 4

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

        var lastError: Error = TranslateError.network
        for host in hosts {
            do {
                return try await translateOnce(trimmed: trimmed, hostBase: host)
            } catch let err as TranslateError {
                lastError = err
                // quota / hard server — still try next host once
                continue
            } catch {
                lastError = error
                continue
            }
        }
        if let te = lastError as? TranslateError {
            throw te
        }
        throw TranslateError.network
    }

    private func translateOnce(trimmed: String, hostBase: String) async throws -> TranslationResult {
        var pathAllowed = CharacterSet.alphanumerics
        pathAllowed.insert(charactersIn: "-._~")
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: pathAllowed) ?? trimmed
        guard let url = URL(string: "\(hostBase)/\(encoded)") else {
            throw TranslateError.network
        }

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
            }
            // Cloudflare / 错误页：立刻 decoding，勿空等 JSON
            let mime = ((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
            if mime.contains("html") {
                throw TranslateError.decoding
            }
            if let prefix = String(data: data.prefix(8), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               prefix.hasPrefix("<") {
                throw TranslateError.decoding
            }
            let gloss = try Self.parseTranslation(data: data)
            // 拒绝英译英 / 原文回显（部分实例对 zh 会原样返回）
            let hasHan = gloss.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
            if !hasHan || gloss.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
                throw TranslateError.emptyResult
            }
            return TranslationResult(
                sourceText: trimmed,
                senses: [TranslationSense(gloss: gloss)],
                phonetic: nil,
                pos: nil,
                sourceEngine: .lingva
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

    /// Parse `{"translation":"..."}` via JSONSerialization.
    static func parseTranslation(data: Data) throws -> String {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslateError.decoding
        }
        let raw: String?
        if let s = root["translation"] as? String {
            raw = s
        } else if let n = root["translation"] as? NSNumber {
            raw = n.stringValue
        } else {
            raw = nil
        }
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw TranslateError.emptyResult
        }
        return text
    }
}
