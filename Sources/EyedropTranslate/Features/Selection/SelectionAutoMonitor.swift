import AppKit
import Foundation

/// 选中即译：监听全局/本地鼠标按下+抬起，按拖拽距离判定选区手势，debounce 后触发自动翻译。
///
/// - 需辅助功能信任才能安装全局监视器（跨 App 划词）。
/// - 默认开启；用户可在设置关闭。
/// - 点击本 App 浮层/设置窗口时忽略，避免误触发。
/// - 拖拽距离 < 5pt 视为点击 → 静默跳过；≥ 5pt 视为选区手势 → 必走 auto（失败可见）。
@MainActor
final class SelectionAutoMonitor {
    /// debounce（秒），对齐 PRD 200–300ms
    private let debounceNs: UInt64 = 250_000_000
    /// 未授权提示最短间隔，避免刷屏
    private let permissionNagMinInterval: TimeInterval = 45
    /// 拖拽判定阈值（屏幕点）
    private let dragThresholdPoints: CGFloat = 5

    private let accessibility: AccessibilityPermission
    private let preferences: AppPreferences
    /// `expectSelection == true`：确认为拖拽选区手势，失败必须可见
    private let onAutoTranslate: (_ expectSelection: Bool) -> Void
    private let onPermissionNeeded: () -> Void
    private let shouldIgnoreEvent: () -> Bool

    private var globalMouseUpMonitor: Any?
    private var localMouseUpMonitor: Any?
    private var globalMouseDownMonitor: Any?
    private var localMouseDownMonitor: Any?
    private var debounceTask: Task<Void, Never>?
    private var lastPermissionNagAt: Date?
    private var isRunning = false

    /// 最近一次 leftMouseDown 屏幕坐标（AppKit，左下原点）
    private var mouseDownLocation: CGPoint?

    init(
        accessibility: AccessibilityPermission,
        preferences: AppPreferences,
        onAutoTranslate: @escaping (_ expectSelection: Bool) -> Void,
        onPermissionNeeded: @escaping () -> Void,
        shouldIgnoreEvent: @escaping () -> Bool = { false }
    ) {
        self.accessibility = accessibility
        self.preferences = preferences
        self.onAutoTranslate = onAutoTranslate
        self.onPermissionNeeded = onPermissionNeeded
        self.shouldIgnoreEvent = shouldIgnoreEvent
    }

    // 退出时由 AppDelegate.applicationWillTerminate → stop() 拆除监视器。

    /// 根据「选中即译」开关与 AX 信任，启动或停止监视。
    /// 若已启动但 global 监视器为 nil，会继续尝试补装。
    func syncWithPreferencesAndTrust() {
        accessibility.refresh()
        let shouldRun = preferences.autoTranslateOnSelection && accessibility.isTrusted
        if shouldRun {
            start()
        } else {
            stop()
        }
    }

    func start() {
        accessibility.refresh()
        guard accessibility.isTrusted else { return }
        guard preferences.autoTranslateOnSelection else { return }

        installMonitorsIfNeeded()
        isRunning = hasAnyMonitor
    }

    func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        mouseDownLocation = nil
        removeAllMonitors()
        isRunning = false
    }

    /// 是否已有任一监视器（供状态诊断）
    var hasGlobalMonitor: Bool { globalMouseUpMonitor != nil }
    var hasAnyMonitor: Bool {
        globalMouseUpMonitor != nil
            || localMouseUpMonitor != nil
            || globalMouseDownMonitor != nil
            || localMouseDownMonitor != nil
    }

    // MARK: - Private · install

    private func installMonitorsIfNeeded() {
        let downHandler: (NSEvent) -> Void = { [weak self] event in
            Task { @MainActor in
                self?.handleMouseDown(event)
            }
        }
        let upHandler: (NSEvent) -> Void = { [weak self] event in
            Task { @MainActor in
                self?.handleMouseUp(event)
            }
        }

        if globalMouseDownMonitor == nil {
            globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { event in
                downHandler(event)
            }
        }
        if localMouseDownMonitor == nil {
            localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
                downHandler(event)
                return event
            }
        }
        if globalMouseUpMonitor == nil {
            globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { event in
                upHandler(event)
            }
        }
        if localMouseUpMonitor == nil {
            localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
                upHandler(event)
                return event
            }
        }
    }

    private func removeAllMonitors() {
        if let globalMouseDownMonitor {
            NSEvent.removeMonitor(globalMouseDownMonitor)
            self.globalMouseDownMonitor = nil
        }
        if let localMouseDownMonitor {
            NSEvent.removeMonitor(localMouseDownMonitor)
            self.localMouseDownMonitor = nil
        }
        if let globalMouseUpMonitor {
            NSEvent.removeMonitor(globalMouseUpMonitor)
            self.globalMouseUpMonitor = nil
        }
        if let localMouseUpMonitor {
            NSEvent.removeMonitor(localMouseUpMonitor)
            self.localMouseUpMonitor = nil
        }
    }

    // MARK: - Private · events

    private func handleMouseDown(_ event: NSEvent) {
        guard preferences.autoTranslateOnSelection else { return }
        if shouldIgnoreEvent() { return }
        mouseDownLocation = Self.screenLocation(of: event)
    }

    private func handleMouseUp(_ event: NSEvent) {
        guard preferences.autoTranslateOnSelection else { return }
        if shouldIgnoreEvent() { return }

        let upLoc = Self.screenLocation(of: event)
        let downLoc = mouseDownLocation
        mouseDownLocation = nil

        // 无 down 记录时保守按选区手势处理（避免丢划词）；有记录则按距离判定
        let distance: CGFloat
        if let downLoc {
            let dx = upLoc.x - downLoc.x
            let dy = upLoc.y - downLoc.y
            distance = hypot(dx, dy)
        } else {
            distance = dragThresholdPoints
        }

        // 纯点击：静默跳过，不刷失败浮层
        guard distance >= dragThresholdPoints else { return }

        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.debounceNs)
            guard !Task.isCancelled else { return }
            self.fireAfterDebounce(expectSelection: true)
        }
    }

    private func fireAfterDebounce(expectSelection: Bool) {
        accessibility.refresh()
        guard preferences.autoTranslateOnSelection else { return }

        if !accessibility.isTrusted {
            nagPermissionIfNeeded()
            stop()
            return
        }

        // 信任后若 global 仍 nil，再试一次补装
        if globalMouseUpMonitor == nil {
            installMonitorsIfNeeded()
        }

        if shouldIgnoreEvent() { return }
        onAutoTranslate(expectSelection)
    }

    private func nagPermissionIfNeeded() {
        let now = Date()
        if let last = lastPermissionNagAt, now.timeIntervalSince(last) < permissionNagMinInterval {
            return
        }
        lastPermissionNagAt = now
        onPermissionNeeded()
    }

    /// AppKit 屏幕坐标（左下原点）
    private static func screenLocation(of event: NSEvent) -> CGPoint {
        // 全局监视器事件的 locationInWindow 常相对主屏；mouseLocation 更稳
        if event.window == nil {
            return NSEvent.mouseLocation
        }
        let loc = event.locationInWindow
        guard let window = event.window else { return NSEvent.mouseLocation }
        return window.convertPoint(toScreen: loc)
    }
}
