import AppKit
import Combine

/// AppKit `NSStatusItem` 菜单栏控制器（**唯一**菜单栏图标路径）。
///
/// 优先 Assets `MenuBarIcon`（template · 几何小写 **e** / eDrop，0.3.16 已嵌入 PNG）；
/// 槽位在 `Resources/Assets.xcassets/MenuBarIcon.imageset`。仅当 named image 缺失时
/// 回退 SF Symbol（权限态仍用 SF Symbol 以便可辨）。详见
/// `launch/figma-exports/P0-C-menubar-done.md`。
/// tooltip / 菜单用户可见处优先「点译」。
/// 0.3.7：菜单增加可点击「选中即译」Toggle（勾选 state 绑定 preferences）。
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private(set) var statusItem: NSStatusItem?
    private let accessibility: AccessibilityPermission
    private let coordinator: TranslateCoordinator
    private let preferences: AppPreferences
    private let onTranslateSelection: () -> Void
    private let onTranslateClipboard: () -> Void
    private let onOpenSettings: () -> Void
    private let onOpenWordbook: () -> Void
    private let onShowFloatingBall: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(
        accessibility: AccessibilityPermission,
        coordinator: TranslateCoordinator,
        preferences: AppPreferences,
        onTranslateSelection: @escaping () -> Void,
        onTranslateClipboard: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onOpenWordbook: @escaping () -> Void = {},
        onShowFloatingBall: @escaping () -> Void = {}
    ) {
        self.accessibility = accessibility
        self.coordinator = coordinator
        self.preferences = preferences
        self.onTranslateSelection = onTranslateSelection
        self.onTranslateClipboard = onTranslateClipboard
        self.onOpenSettings = onOpenSettings
        self.onOpenWordbook = onOpenWordbook
        self.onShowFloatingBall = onShowFloatingBall
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.isVisible = true
        if let button = item.button {
            button.image = makeStatusImage(symbol: symbol(for: coordinator.status))
            button.imagePosition = .imageOnly
            button.toolTip = currentTooltip()
            if button.image == nil {
                button.title = Constants.appNameCN
            }
        }
        let menu = buildMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item

        coordinator.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.applyStatus(status)
            }
            .store(in: &cancellables)

        preferences.$autoTranslateOnSelection
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyStatus(self?.coordinator.status ?? .idle)
            }
            .store(in: &cancellables)

        applyStatus(coordinator.status)
    }

    func menuWillOpen(_ menu: NSMenu) {
        coordinator.rememberFrontmostAppForMenu()
        coordinator.prefetchSelectionForMenu()
        accessibility.refresh()
    }

    private func symbol(for status: MenuBarStatus) -> String {
        status.symbolName
    }

    /// 优先 template `MenuBarIcon`（品牌几何 e，0.3.16 已嵌入）；空闲/翻译态用。
    /// 仅当 named image 缺失时回退 SF Symbol；权限态仍用 SF Symbol 以便可辨。
    private func makeStatusImage(symbol: String) -> NSImage? {
        if coordinator.status == .idle || coordinator.status == .translating {
            if let named = NSImage(named: "MenuBarIcon") {
                named.isTemplate = true
                return named
            }
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: Constants.appNameCN)
        image?.isTemplate = true
        return image
    }

    private func currentTooltip() -> String {
        accessibility.refresh()
        return coordinator.status.tooltip(
            autoOn: preferences.autoTranslateOnSelection,
            trusted: accessibility.isTrusted
        )
    }

    private func applyStatus(_ status: MenuBarStatus) {
        guard let button = statusItem?.button else { return }
        if let image = makeStatusImage(symbol: symbol(for: status)) {
            button.image = image
            button.title = ""
            if status == .needsPermission {
                button.image = NSImage(systemSymbolName: status.symbolName, accessibilityDescription: Constants.appNameCN)
                button.image?.isTemplate = true
            }
        } else {
            button.image = nil
            button.title = Constants.appNameCN
        }
        button.toolTip = currentTooltip()
        reloadMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let tipItem = NSMenuItem(
            title: PlaceholderStrings.menuTranslateSelectionTip,
            action: nil,
            keyEquivalent: ""
        )
        tipItem.isEnabled = false
        menu.addItem(tipItem)

        // 选中即译 Toggle（勾选 = 开）
        let autoItem = NSMenuItem(
            title: PlaceholderStrings.menuAutoTranslateToggle,
            action: #selector(toggleAutoTranslate),
            keyEquivalent: "a"
        )
        autoItem.target = self
        autoItem.state = preferences.autoTranslateOnSelection ? .on : .off
        menu.addItem(autoItem)

        menu.addItem(.separator())

        let translateItem = NSMenuItem(
            title: PlaceholderStrings.menuTranslateSelection,
            action: #selector(translateSelection),
            keyEquivalent: "t"
        )
        translateItem.target = self
        menu.addItem(translateItem)

        let clipboardItem = NSMenuItem(
            title: PlaceholderStrings.menuTranslateClipboard,
            action: #selector(translateClipboard),
            keyEquivalent: "v"
        )
        clipboardItem.target = self
        menu.addItem(clipboardItem)

        menu.addItem(.separator())

        let wordbookItem = NSMenuItem(
            title: PlaceholderStrings.menuOpenWordbook,
            action: #selector(openWordbook),
            keyEquivalent: "b"
        )
        wordbookItem.target = self
        menu.addItem(wordbookItem)

        let ballItem = NSMenuItem(
            title: PlaceholderStrings.menuShowFloatingBall,
            action: #selector(showFloatingBall),
            keyEquivalent: ""
        )
        ballItem.target = self
        menu.addItem(ballItem)

        menu.addItem(.separator())

        accessibility.refresh()
        let statusTitle: String
        switch coordinator.status {
        case .needsPermission:
            statusTitle = PlaceholderStrings.menuStatusNeedsPermission
        case .translating:
            statusTitle = PlaceholderStrings.menuStatusTranslating
        case .idle:
            statusTitle = accessibility.isTrusted
                ? PlaceholderStrings.menuAccessibilityOK
                : PlaceholderStrings.menuAccessibilityNeeded
        }
        let axStatusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        axStatusItem.isEnabled = false
        menu.addItem(axStatusItem)

        if !accessibility.isTrusted {
            let openAX = NSMenuItem(
                title: PlaceholderStrings.settingsOpenSystemPrefs,
                action: #selector(openAccessibility),
                keyEquivalent: ""
            )
            openAX.target = self
            menu.addItem(openAX)
        }

        let settingsItem = NSMenuItem(
            title: PlaceholderStrings.menuOpenSettings,
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: PlaceholderStrings.menuQuit,
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func toggleAutoTranslate() {
        preferences.autoTranslateOnSelection.toggle()
        // AppDelegate 订阅 preferences 会 sync monitor / tip；此处刷新菜单勾选
        reloadMenu()
    }

    @objc private func translateSelection() {
        onTranslateSelection()
    }

    @objc private func translateClipboard() {
        onTranslateClipboard()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func openWordbook() {
        onOpenWordbook()
    }

    @objc private func showFloatingBall() {
        onShowFloatingBall()
    }

    @objc private func openAccessibility() {
        accessibility.openSystemSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func reloadMenu() {
        let menu = buildMenu()
        statusItem?.menu = menu
        statusItem?.button?.toolTip = currentTooltip()
    }
}
