import AppKit
import Combine

/// AppKit 生命周期：装配 Overlay / Selection / Translate / Settings / 划词本 / 悬浮球 / 菜单栏 / 选中即译监视。
///
/// **菜单栏策略**：始终安装 `NSStatusItem`（可靠主路径）。不使用 SwiftUI `MenuBarExtra`，避免双图标。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let accessibility = AccessibilityPermission()
    let preferences = AppPreferences.shared
    let wordbookStore = WordbookStore.shared
    private(set) lazy var overlay = OverlayPanelController()
    private(set) lazy var settingsWindow = SettingsWindowController(
        accessibility: accessibility,
        preferences: preferences,
        coordinatorProvider: { [weak self] in self?.coordinator },
        onAutoTranslateChanged: { [weak self] in
            self?.autoMonitor?.syncWithPreferencesAndTrust()
            self?.coordinator?.refreshStatus()
            self?.menuBarController?.reloadMenu()
        }
    )
    private(set) lazy var wordbookWindow = WordbookWindowController(store: wordbookStore)

    private(set) var coordinator: TranslateCoordinator?
    private var menuBarController: MenuBarController?
    private var autoMonitor: SelectionAutoMonitor?
    private var floatingBall: DesktopFloatingBallController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        accessibility.refresh()

        let reader = SelectionReader(accessibility: accessibility)
        let service = TranslateServiceFactory.make()
        let coord = TranslateCoordinator(
            accessibility: accessibility,
            selectionReader: reader,
            translateService: service,
            overlay: overlay,
            preferences: preferences,
            wordbookStore: wordbookStore
        )
        self.coordinator = coord

        let controller = MenuBarController(
            accessibility: accessibility,
            coordinator: coord,
            preferences: preferences,
            onTranslateSelection: { [weak self] in self?.translateSelection() },
            onTranslateClipboard: { [weak self] in self?.translateClipboard() },
            onOpenSettings: { [weak self] in self?.openSettings() },
            onOpenWordbook: { [weak self] in self?.openWordbook() },
            onShowFloatingBall: { [weak self] in self?.showFloatingBall() }
        )
        controller.install()
        menuBarController = controller

        // 桌面悬浮球（默认挂件形态）：单击划词本；右键切换选中即译
        let ball = DesktopFloatingBallController(
            preferences: preferences,
            onClick: { [weak self] in
                self?.openWordbook()
            },
            onToggleAutoTranslate: { [weak self] in
                guard let self else { return }
                self.preferences.autoTranslateOnSelection.toggle()
                // preferences 订阅会 sync monitor / 菜单；此处保证球外观即时刷新
                self.floatingBall?.applyAutoTranslateAppearance()
                self.menuBarController?.reloadMenu()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        )
        ball.install()
        floatingBall = ball

        let monitor = SelectionAutoMonitor(
            accessibility: accessibility,
            preferences: preferences,
            onAutoTranslate: { [weak self] expectSelection in
                self?.coordinator?.autoTranslateAfterSelection(expectSelection: expectSelection)
                self?.menuBarController?.reloadMenu()
            },
            onPermissionNeeded: { [weak self] in
                self?.coordinator?.presentAutoPermissionFailure()
                self?.menuBarController?.reloadMenu()
            },
            shouldIgnoreEvent: { [weak self] in
                self?.shouldIgnoreAutoTranslateEvent() ?? false
            }
        )
        self.autoMonitor = monitor

        accessibility.onBecameTrusted = { [weak self] in
            self?.coordinator?.refreshStatus()
            self?.menuBarController?.reloadMenu()
            self?.autoMonitor?.syncWithPreferencesAndTrust()
        }

        preferences.$autoTranslateOnSelection
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.autoMonitor?.syncWithPreferencesAndTrust()
                self?.coordinator?.refreshStatus()
                self?.menuBarController?.reloadMenu()
                self?.floatingBall?.applyAutoTranslateAppearance()
            }
            .store(in: &cancellables)

        coord.refreshStatus()
        monitor.syncWithPreferencesAndTrust()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        accessibility.refreshAndNotifyIfNewlyTrusted()
        coordinator?.refreshStatus()
        menuBarController?.reloadMenu()
        autoMonitor?.syncWithPreferencesAndTrust()
        floatingBall?.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        autoMonitor?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func translateSelection() {
        coordinator?.translateSelection()
        menuBarController?.reloadMenu()
    }

    func translateClipboard() {
        coordinator?.translateClipboard()
        menuBarController?.reloadMenu()
    }

    func openSettings() {
        accessibility.refresh()
        settingsWindow.show()
    }

    func openWordbook() {
        wordbookWindow.show()
    }

    func showFloatingBall() {
        floatingBall?.show()
    }

    /// 点击落在本 App 浮层 / 设置窗 / 悬浮球 / 状态栏菜单时不触发选中即译
    private func shouldIgnoreAutoTranslateEvent() -> Bool {
        let point = NSEvent.mouseLocation
        if overlay.containsScreenPoint(point) {
            return true
        }
        for window in NSApp.windows where window.isVisible {
            if window.frame.contains(point) {
                return true
            }
        }
        let selfPID = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier == selfPID,
           NSApp.windows.contains(where: { $0.isVisible && $0.frame.contains(point) }) {
            return true
        }
        return false
    }
}
