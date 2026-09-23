import Foundation

/// 桌面挂件入口说明（0.3.7）
///
/// **默认形态已定为悬浮球**，可运行实现见 `DesktopFloatingBallController`：
/// - 直径约 48pt（44–52 区间）；液化玻璃 + 细描边
/// - 可拖拽 + 松手边缘吸附
/// - **单击**打开划词本
/// - **右键**切换「选中即译」（开/关态：描边与透明度区分）
/// - NSPanel + nonactivatingPanel，不抢焦点
///
/// 其他形态（迷你条 / 桌面小部件）本版本不做。
enum DesktopWidgetKind: String {
    case floatingBall
    case miniBar
    case desktopWidget
}

enum DesktopWidgetStub {
    static let defaultKind: DesktopWidgetKind = .floatingBall
    static let notes = "实现见 DesktopFloatingBallController；右键切换选中即译；miniBar / desktopWidget 未做。"
}
