import CoreGraphics
import Foundation

/// 产品常量（对齐 PRD v0.3 · 0.3.17 品牌 e 悬浮球 + eDrop PRODUCT_NAME）
///
/// 品牌：中文名「点译」；英文 eDrop；Bundle ID 暂 app.eyedrop.translate
/// Slogan：点落生词，畅读外文
enum Constants {
    /// 用户可见中文名
    static let appNameCN = "点译"
    /// 英文产品名（用户可见）
    static let appNameEN = "eDrop"
    /// 对外显示名（菜单栏 tip / 关于 / 退出等）
    static let appName = "点译"
    /// 完整对外显示（设置关于页等）
    static let appDisplayFull = "点译 · eDrop"
    /// 品牌 slogan（已定）
    static let slogan = "点落生词，畅读外文"
    static let sloganEnglish = "Drop the word, keep reading."
    /// 功能短句（商店一行 / 设置说明）
    static let featureTagline = "划词即译 · 英译中"
    /// 著作权声明（关于页 / Info.plist 对齐）
    static let copyright = "Copyright © 2026 王振茹 (Zhenru Wang). All rights reserved."
    static let bundleID = "app.eyedrop.translate"
    static let prdVersion = "v0.3"
    static let appVersionLabel = "0.3.17 · eDrop"

    /// 菜单栏 / 浮层尺寸（宽 ~260，对齐 Figma PNG 实白卡（P0-A））
    enum Overlay {
        static let defaultWidth: CGFloat = AppTheme.Metrics.overlayWidth
        static let defaultHeight: CGFloat = 120
        static let loadingHeight: CGFloat = 96
        static let maxHeight: CGFloat = 260
    }

    /// 设置窗：LIVE Figma ~360×280；min 宽 360，内容更高时可滚/可长
    enum Settings {
        static let windowWidth: CGFloat = 360
        static let windowHeight: CGFloat = 280
        static let minWidth: CGFloat = 360
        static let minHeight: CGFloat = 280
    }

    enum Wordbook {
        static let windowWidth: CGFloat = 420
        static let windowHeight: CGFloat = 480
        static let maxEntries = 200
    }

    enum Translate {
        /// 短缓存 TTL（秒）
        static let cacheTTL: TimeInterval = 15 * 60
        static let cacheCapacity = 64
        static let requestTimeout: TimeInterval = 8
        static let resourceTimeout: TimeInterval = 10
        static let userAgent = "eDrop/0.3.17"
        /// MyMemory 公开 `de=` 联系邮箱（提升免费配额；非密钥）
        static let myMemoryContactEmail = "dianyi.eyedrop@gmail.com"
        static let sourceLanguage = "en"
        static let targetLanguage = "zh"
        /// Info.plist / 环境变量键（切勿硬编码密钥）
        static let envBaseURLKey = "EYEDROP_TRANSLATE_API_BASE_URL"
        static let envAPIKeyKey = "EYEDROP_TRANSLATE_API_KEY"
        static let plistBaseURLKey = "EyedropTranslateAPIBaseURL"
        static let plistAPIKeyKey = "EyedropTranslateAPIKey"
    }

    /// 选中即译（P0）
    enum AutoTranslate {
        /// 字符数上限；超过提示「选短一点」
        static let maxCharacterCount = 200
        /// 词数上限（空白分词）
        static let maxWordCount = 40
        /// debounce 毫秒（文档/设置提示用）
        static let debounceMilliseconds = 250
    }

    /// 辅助功能系统设置深链（best-effort；失败时 README / 设置页有手写路径）
    enum AccessibilityURLs {
        static let legacy =
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        /// macOS 13+ System Settings
        static let ventura =
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        /// Sequoia / 较新：隐私与安全性 → 辅助功能
        static let modern =
            "x-apple.systempreferences:com.apple.Settings.extension.PrivacySecurity.extension?Privacy_Accessibility"
    }
}
