import AppKit
import SwiftUI

/// 设置窗口：从菜单栏打开
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let accessibility: AccessibilityPermission
    private let preferences: AppPreferences
    private let coordinatorProvider: () -> TranslateCoordinator?
    private let onAutoTranslateChanged: (() -> Void)?

    init(
        accessibility: AccessibilityPermission,
        preferences: AppPreferences,
        coordinatorProvider: @escaping () -> TranslateCoordinator?,
        onAutoTranslateChanged: (() -> Void)? = nil
    ) {
        self.accessibility = accessibility
        self.preferences = preferences
        self.coordinatorProvider = coordinatorProvider
        self.onAutoTranslateChanged = onAutoTranslateChanged
    }

    func show() {
        guard let coordinator = coordinatorProvider() else { return }

        if let window {
            if let hosting = window.contentViewController as? NSHostingController<SettingsView> {
                hosting.rootView = makeRoot(coordinator: coordinator)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: makeRoot(coordinator: coordinator))

        let window = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0,
                width: Constants.Settings.windowWidth,
                height: Constants.Settings.windowHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = PlaceholderStrings.settingsTitle
        // LIVE Figma ~360×280；min 宽 360，内容更高时可拉高滚动
        window.minSize = NSSize(
            width: Constants.Settings.minWidth,
            height: Constants.Settings.minHeight
        )
        window.contentViewController = hosting
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private func makeRoot(coordinator: TranslateCoordinator) -> SettingsView {
        SettingsView(
            accessibility: accessibility,
            preferences: preferences,
            coordinator: coordinator,
            onAutoTranslateChanged: onAutoTranslateChanged
        )
    }
}
