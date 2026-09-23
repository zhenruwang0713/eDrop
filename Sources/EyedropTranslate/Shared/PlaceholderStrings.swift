import Foundation

/// 面向用户的中文 UI 文案 · 品牌「点译 · eDrop」· 0.3.17
enum PlaceholderStrings {
    // MARK: - 品牌
    static let brandSlogan = Constants.slogan
    static let brandSloganEnglish = Constants.sloganEnglish
    static let brandFeatureTagline = Constants.featureTagline
    static let brandDisplayFull = Constants.appDisplayFull
    static let brandCopyright = Constants.copyright

    // MARK: - 菜单栏
    static let menuStatusIdle = "空闲"
    static let menuStatusTranslating = "翻译中…"
    static let menuStatusNeedsPermission = "需要辅助功能权限"
    static let menuTranslateSelection = "翻译选区（兜底）"
    static let menuTranslateClipboard = "翻译剪贴板（兜底）"
    static let menuTranslateSelectionTip = "主路径：划选英文后松开鼠标即可自动翻译"
    static let menuOpenSettings = "设置…"
    static let menuOpenWordbook = "划词本…"
    static let menuShowFloatingBall = "显示悬浮球"
    static let menuQuit = "退出点译"
    static let menuAccessibilityOK = "辅助功能：已授权"
    static let menuAccessibilityNeeded = "辅助功能：需要授权"
    /// 菜单 Toggle 项标题（勾选表示开）
    static let menuAutoTranslateToggle = "选中即译"
    static let menuTooltipAutoOn = "选中即译：开"
    static let menuTooltipAutoOff = "选中即译：关"
    static let menuTooltipTrusted = "已授权"
    static let menuTooltipUntrusted = "需授权"

    // MARK: - 浮层
    static let overlayTitle = Constants.appNameCN  // 「点译」品牌头（Figma PNG）
    static let overlayLoading = "正在翻译…"
    /// LIVE Figma 识别中（选区未取到 / 空 fetch 时展示）
    static let overlayRecognizing = "正在识别文字…"
    static let overlayChineseSensesLabel = "中文释义"
    /// 选中即译：拖拽松开后、尚未取到原文时的占位 sentinel（UI 显示 overlayRecognizing）
    static let overlayFetchingSelection = "正在取词…"
    static let overlayClose = "关闭"
    static let overlayRetry = "重试"
    static let overlayOpenAccessibility = "打开辅助功能设置"

    // MARK: - 失败 / 选区（短句：首行结论，必要时第二句操作）
    /// Figma overlay-error：无法识别选区中的文字（选区空 / 未读到字）
    static let failUnrecognizedSelection = "无法识别选区中的文字"
    static let failNoSelection = failUnrecognizedSelection
    static let failNoSelectionWebHint = failUnrecognizedSelection
    static let failClipboardEmpty = "剪贴板为空。\n先复制文本再试。"
    static let failNoPermission = "需要辅助功能权限。\n请在系统设置中为「点译」开启。"
    static let failUnsupported = "当前应用不支持读选区。\n换到可选中文本的应用，或手动复制。"
    static let failOther = "读取选区失败，请稍后重试。"
    static let failNetwork = "网络异常。\n检查网络后点「重试」。"
    static let failTimeout = "翻译超时。\n稍后重试。"
    static let failServer = "翻译服务暂不可用。\n稍后重试。"
    static let failEmptyResult = "未获得有效释义。\n换词或稍后重试。"
    static let failSelectionTooLong = "选区过长。\n请选短一点（约 40 词 / 200 字内）。"

    /// 失败态：拆成标题 + 说明（首行 / 其余）
    static func failureTitleAndDetail(_ message: String) -> (title: String, detail: String?) {
        let parts = message
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let first = parts.first else { return (message, nil) }
        if parts.count == 1 { return (first, nil) }
        return (first, parts.dropFirst().joined(separator: " "))
    }

    // MARK: - 设置
    static let settingsTitle = "设置"
    static let settingsGeneral = "通用"
    static let settingsAutoTranslate = "选中即译"
    static let settingsAutoTranslateSection = "选中即译（主路径）"
    static let settingsAutoTranslateTip = "划词即译 · 英译中：划选英文后松开，中文释义随即出现。网页等可用；过长选区会提示选短一点。也可在菜单栏勾选，或右键悬浮球切换。"
    static let settingsAutoSaveWordbook = "自动收入划词本"
    static let settingsAutoSaveWordbookTip = "翻译成功后默认写入本地划词本（可关）。不做云同步。"
    static let settingsHotkey = "快捷键（M2 占位）"
    static let settingsLaunchAtLogin = "开机启动（占位）"
    static let settingsAccessibility = "辅助功能权限"
    static let settingsAbout = "关于"
    static let settingsTranslate = "翻译服务"
    static let settingsOpenSystemPrefs = "打开系统设置"
    static let settingsRevealInFinder = "在访达中显示本 App（方便 + 添加）"
    static let settingsRefreshStatus = "刷新状态"
    static let settingsRequestPrompt = "请求系统授权框"
    static let settingsOpenAXPrimary = "打开辅助功能并开启「点译」或「eDrop」"
    static let settingsVersion = "0.3.17 · eDrop · 划词即译 · 英译中"
    static let settingsEngineMock = "当前：本地 Mock（离线示意）"
    static let settingsEngineRemote = "当前：远程 API"
    static let settingsEngineMyMemory = "当前：MyMemory 免费英→中"
    static let settingsEngineLingva = "当前：Lingva 免费英→中"
    static let settingsEngineGoogle = "当前：Google 免费英→中"
    static let settingsEngineMyMemoryWithFallback = "当前：MyMemory（失败时回退 Mock）"
    static let settingsEngineChainWithFallback = "当前：MyMemory → Google → Lingva → Mock"
    static let settingsEngineStatusIdle = "尚未翻译 · 默认 MyMemory → Google → Lingva"
    static let settingsEngineLastMyMemory = "上次：MyMemory"
    static let settingsEngineLastGoogle = "上次：Google"
    static let settingsEngineLastLingva = "上次：Lingva"
    static let settingsEngineLastMockFallback = "上次：本地 Mock（在线引擎暂不可用）"
    static let settingsEngineLastRemote = "上次：远程 API"
    static let settingsEngineLastErrorPrefix = "上次错误："
    static let settingsEngineHint = "默认 MyMemory → Google → Lingva（均免费、无需 Key）；都失败才回退本地示意。免费额度用尽时会走 Google。设置页会显示上次引擎与错误原因。若看不到引擎变化，请打开本仓库 eDrop.xcodeproj，Clean Build Folder 后 ⌘R。"

    // MARK: - Mock footer（可读）
    static let overlayMockFooter = "暂用本地释义"
    static let overlayMockTipNetwork = "网络失败"
    static let overlayMockTipTimeout = "网络超时"
    static let overlayMockTipQuota = "额度用尽"
    static let overlayMockTipDecode = "解析失败"
    static let overlayMockTipEmpty = "空结果"
    static let overlayMockTipServer = "服务异常"

    static func overlayMockFooter(tip: String?) -> String {
        if let tip, !tip.isEmpty {
            return "暂用本地释义（\(tip)）"
        }
        return overlayMockFooter
    }

    // MARK: - 划词本
    static let wordbookTitle = "划词本"
    static let wordbookEmpty = "暂无收录。翻译成功后会自动写入（可在设置关闭）。"
    static let wordbookSearchPrompt = "搜索原文或释义"
    static let wordbookDelete = "删除"
    static let wordbookSourceUnknown = "未知来源"

    // MARK: - 悬浮球
    static let floatingBallTooltip = "点译 · 单击打开划词本 · 右键切换选中即译"
    static let floatingBallTooltipAutoOn = "点译 · 选中即译：开 · 单击划词本 · 右键关闭"
    static let floatingBallTooltipAutoOff = "点译 · 选中即译：关 · 单击划词本 · 右键开启"
    static let floatingBallMenuToggleAuto = "选中即译"
    static let floatingBallMenuOpenWordbook = "打开划词本"
    static let floatingBallMenuOpenSettings = "设置…"

    // MARK: - 设置 · 辅助功能诊断（始终可见）
    static let axDiagTrustedLabel = "Trusted"
    static let axDiagTrustedYes = "YES"
    static let axDiagTrustedNo = "NO"
    static let axDiagBundlePathLabel = "Bundle path"
    static let settingsCopyBundlePath = "复制路径到剪贴板"
    static let axPathMismatchHint = """
若开关已开仍显示未授权，请在辅助功能列表删除「点译」或「eDrop」（或旧名），用「在访达中显示」把*当前*这个 App 重新 ＋ 添加并打开开关，然后完全退出再 ⌘R
"""

    // MARK: - 权限引导
    static let axTrusted = "已授予辅助功能权限"
    static let axNotTrusted = "尚未授予辅助功能权限。划词取词需要此权限。"
    static let axUsageBrief = "用于读取您选中的文本并自动显示释义（选中即译）；不会在后台持续读取屏幕内容。"
    static let axFirstRunTitle = "需要开启辅助功能"
    static let axToggleHint = """
重要：在辅助功能列表里找到「点译」或「eDrop」（也可能显示旧工程名），把右侧开关拨到「开」（蓝色）。只打开设置页面不够，必须把开关打开。
"""
    static let axRelaunchHint = """
若开关已开仍显示未授权，请在辅助功能列表删除「点译」或「eDrop」（或旧名），用「在访达中显示」把*当前*这个 App 重新 ＋ 添加并打开开关，然后完全退出再 ⌘R（TCC 常把信任绑到旧 DerivedData 路径）。
"""
    static let axFirstRunBody = """
需要辅助功能权限。
请到系统设置 → 隐私与安全性 → 辅助功能，找到「点译」或「eDrop」并打开开关。
"""
    static let axHowToEnable = "系统设置 → 隐私与安全性 → 辅助功能"
}
