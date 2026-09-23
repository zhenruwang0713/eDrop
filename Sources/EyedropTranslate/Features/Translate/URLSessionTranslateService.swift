import Foundation

/// 基于 URLSession 的远程翻译客户端。
///
/// ## JSON 约定（README 同步）
/// `POST {baseURL}` 或 `POST {baseURL}/translate`
/// Request: `{"text":"...","from":"en","to":"zh"}`
/// Response: `{"senses":[{"gloss":"狗","pos":"n.","phonetic":"/dɔːɡ/"}],"phonetic":"...","pos":"..."}`
///
/// Header（可选）: `Authorization: Bearer <API_KEY>` 或 `X-API-Key: <API_KEY>`
final class URLSessionTranslateService: TranslateService {
    private let config: TranslateAPIConfig
    private let session: URLSession

    var engineDisplayName: String { PlaceholderStrings.settingsEngineRemote }

    init(config: TranslateAPIConfig, session: URLSession? = nil) {
        self.config = config
        if let session {
            self.session = session
        } else {
            let conf = URLSessionConfiguration.ephemeral
            conf.waitsForConnectivity = false
            conf.timeoutIntervalForRequest = Constants.Translate.requestTimeout
            conf.timeoutIntervalForResource = Constants.Translate.resourceTimeout
            self.session = URLSession(configuration: conf)
        }
    }

    func translate(text: String, from: String, to: String) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslateError.emptyInput }
        guard let base = config.baseURL else { throw TranslateError.server(status: nil) }

        let endpoint = resolveEndpoint(base: base)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let key = config.apiKey, !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.setValue(key, forHTTPHeaderField: "X-API-Key")
        }
        request.httpBody = try JSONEncoder().encode(
            TranslateRequestBody(text: trimmed, from: from, to: to)
        )

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                throw TranslateError.server(status: http.statusCode)
            }
            let decoded = try JSONDecoder().decode(TranslateResponseBody.self, from: data)
            guard let result = decoded.toResult(sourceText: trimmed) else {
                throw TranslateError.emptyResult
            }
            return result
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

    private func resolveEndpoint(base: URL) -> URL {
        let path = base.path
        if path.hasSuffix("/translate") || path.contains("/translate?") {
            return base
        }
        if path.isEmpty || path == "/" {
            return base.appendingPathComponent("translate")
        }
        // 已带路径则原样 POST
        return base
    }
}
