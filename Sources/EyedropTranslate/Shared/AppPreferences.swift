import Combine
import Foundation

/// 用户偏好（UserDefaults）。「选中即译」默认开启；「自动收入划词本」默认开启。
@MainActor
final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    private enum Keys {
        static let autoTranslateOnSelection = "eyedrop.autoTranslateOnSelection"
        static let autoSaveToWordbook = "eyedrop.autoSaveToWordbook"
    }

    /// 「选中即译」：松开选区后自动翻译。默认 ON。
    @Published var autoTranslateOnSelection: Bool {
        didSet {
            UserDefaults.standard.set(autoTranslateOnSelection, forKey: Keys.autoTranslateOnSelection)
        }
    }

    /// 译成功后默认写入划词本。默认 ON。
    @Published var autoSaveToWordbook: Bool {
        didSet {
            UserDefaults.standard.set(autoSaveToWordbook, forKey: Keys.autoSaveToWordbook)
        }
    }

    private init() {
        if UserDefaults.standard.object(forKey: Keys.autoTranslateOnSelection) == nil {
            UserDefaults.standard.set(true, forKey: Keys.autoTranslateOnSelection)
        }
        if UserDefaults.standard.object(forKey: Keys.autoSaveToWordbook) == nil {
            UserDefaults.standard.set(true, forKey: Keys.autoSaveToWordbook)
        }
        autoTranslateOnSelection = UserDefaults.standard.bool(forKey: Keys.autoTranslateOnSelection)
        autoSaveToWordbook = UserDefaults.standard.bool(forKey: Keys.autoSaveToWordbook)
    }
}
