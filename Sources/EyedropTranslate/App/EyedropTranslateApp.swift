import AppKit
import SwiftUI

/// 应用入口：菜单栏 App（LSUIElement），无 Dock 图标。
///
/// 菜单栏图标以 AppKit `NSStatusItem` 为**唯一**主路径（见 `AppDelegate`），
/// 此处仅保留 `Settings` Scene 以维持 SwiftUI App 生命周期；不再使用 `MenuBarExtra`，
/// 避免与 Status Item 重复出图标或不稳定。
@main
struct EyedropTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            if let coordinator = appDelegate.coordinator {
                SettingsView(
                    accessibility: appDelegate.accessibility,
                    preferences: appDelegate.preferences,
                    coordinator: coordinator,
                    onAutoTranslateChanged: {
                        // AppDelegate Combine sink + monitor sync also observe preferences
                    }
                )
            } else {
                Text(PlaceholderStrings.settingsEngineStatusIdle)
                    .padding()
            }
        }
    }
}
