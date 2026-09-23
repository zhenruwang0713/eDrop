import Foundation

/// M2 全局快捷键占位。
/// M1 仅提供「翻译选区」菜单显式触发；此处预留注册点，避免过早依赖 Carbon/CGEvent。
enum HotkeyStub {
    /// 未来：注册全局热键 → 回调 `translateSelection`。
    static let plannedDefault = "⌃⌥D"

    static let noteForFuture = """
    M2：用 Carbon RegisterEventHotKey 或 DDHotKey / MASShortcut 注册全局快捷键，
    触发与菜单「翻译选区」相同的路径。M1 不做轮询选区变化。
    """
}
