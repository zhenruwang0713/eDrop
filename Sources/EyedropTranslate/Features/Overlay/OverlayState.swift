import Foundation

/// 浮层三态（PRD：加载骨架 / 成功释义 / 失败+重试）
enum OverlayPresentation: Equatable {
    case loading(sourceText: String)
    case success(TranslationResult)
    case failure(message: String, retryText: String?, showOpenAccessibility: Bool)

    var sourceTextForRetry: String? {
        switch self {
        case .loading(let t): return t
        case .success(let r): return r.sourceText
        case .failure(_, let retry, _): return retry
        }
    }
}
