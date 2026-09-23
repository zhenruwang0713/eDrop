import AppKit
import SwiftUI

/// 设置页：选中即译置顶醒目、快捷键占位、开机启动占位、权限引导、翻译引擎、关于（含 slogan）
struct SettingsView: View {
    @ObservedObject var accessibility: AccessibilityPermission
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var coordinator: TranslateCoordinator
    var onAutoTranslateChanged: (() -> Void)?

    var body: some View {
        Form {
            // 选中即译置顶、醒目
            Section {
                HStack(spacing: 10) {
                    Circle()
                        .fill(AppTheme.ColorToken.brandAccent)
                        .frame(width: 10, height: 10)
                    Toggle(PlaceholderStrings.settingsAutoTranslate, isOn: Binding(
                        get: { preferences.autoTranslateOnSelection },
                        set: { newValue in
                            preferences.autoTranslateOnSelection = newValue
                            onAutoTranslateChanged?()
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    Text(PlaceholderStrings.settingsAutoTranslate)
                        .font(.body.weight(.semibold))
                    Spacer()
                    Text(preferences.autoTranslateOnSelection
                         ? PlaceholderStrings.menuTooltipAutoOn
                         : PlaceholderStrings.menuTooltipAutoOff)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(preferences.autoTranslateOnSelection
                                         ? AppTheme.ColorToken.brandAccent
                                         : .secondary)
                }
                Text(PlaceholderStrings.settingsAutoTranslateTip)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text(PlaceholderStrings.settingsAutoTranslateSection)
            }

            Section(PlaceholderStrings.settingsGeneral) {
                Toggle(PlaceholderStrings.settingsAutoSaveWordbook, isOn: Binding(
                    get: { preferences.autoSaveToWordbook },
                    set: { preferences.autoSaveToWordbook = $0 }
                ))
                Text(PlaceholderStrings.settingsAutoSaveWordbookTip)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(PlaceholderStrings.settingsLaunchAtLogin, isOn: .constant(false))
                    .disabled(true)
                HStack {
                    Text(PlaceholderStrings.settingsHotkey)
                    Spacer()
                    Text(HotkeyStub.plannedDefault)
                        .foregroundStyle(.secondary)
                }
                .opacity(0.6)
            }

            Section(PlaceholderStrings.settingsAccessibility) {
                HStack(alignment: .top) {
                    Image(systemName: accessibility.isTrusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(accessibility.isTrusted ? AppTheme.ColorToken.success : AppTheme.ColorToken.warning)
                        .imageScale(.large)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(accessibility.isTrusted
                             ? PlaceholderStrings.axTrusted
                             : PlaceholderStrings.axNotTrusted)
                            .font(.body.weight(.semibold))
                        if !accessibility.isTrusted {
                            Text(PlaceholderStrings.axToggleHint)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(PlaceholderStrings.axRelaunchHint)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(PlaceholderStrings.axUsageBrief)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(PlaceholderStrings.axDiagTrustedLabel)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(accessibility.isTrusted
                             ? PlaceholderStrings.axDiagTrustedYes
                             : PlaceholderStrings.axDiagTrustedNo)
                            .font(.system(.body, design: .monospaced, weight: .semibold))
                            .foregroundStyle(accessibility.isTrusted ? AppTheme.ColorToken.success : AppTheme.ColorToken.warning)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(PlaceholderStrings.axDiagBundlePathLabel)
                            .foregroundStyle(.secondary)
                        Text(accessibility.bundlePath)
                            .font(AppTheme.Typography.caption2)
                            .textSelection(.enabled)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(PlaceholderStrings.axPathMismatchHint)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)

                if !accessibility.isTrusted {
                    Button {
                        accessibility.openSystemSettings()
                    } label: {
                        Text(PlaceholderStrings.settingsOpenAXPrimary)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Button(PlaceholderStrings.settingsOpenSystemPrefs) {
                        accessibility.openSystemSettings()
                    }
                    Button(PlaceholderStrings.settingsCopyBundlePath) {
                        accessibility.copyBundlePathToPasteboard()
                    }
                    Button(PlaceholderStrings.settingsRevealInFinder) {
                        accessibility.revealAppInFinder()
                    }
                    HStack {
                        Button(PlaceholderStrings.settingsRefreshStatus) {
                            accessibility.refresh()
                        }
                        Button(PlaceholderStrings.settingsRequestPrompt) {
                            accessibility.refresh(promptIfNeeded: true)
                        }
                    }
                }
            }

            Section(PlaceholderStrings.settingsTranslate) {
                Text(coordinator.engineDisplayName)
                    .font(.body.weight(.semibold))
                Text(coordinator.lastEngineNote)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if let err = coordinator.lastErrorNote, !err.isEmpty {
                    Text("\(PlaceholderStrings.settingsEngineLastErrorPrefix)\(err)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.ColorToken.warning)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                Text(PlaceholderStrings.settingsEngineHint)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(PlaceholderStrings.settingsAbout) {
                // P0-D / brand.md：显示「点译 · eDrop」（勿用 eDrop Translate）；中文 slogan 主、英 slogan 次
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppTheme.ColorToken.brandAccent)
                        .frame(width: 8, height: 8)
                    Text(Constants.appDisplayFull)
                        .font(AppTheme.Typography.settingsDisplayName)
                }
                Text(PlaceholderStrings.brandSlogan)
                    .font(AppTheme.Typography.slogan)
                    .foregroundStyle(AppTheme.ColorToken.brandAccent)
                Text(PlaceholderStrings.brandSloganEnglish)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                Text(PlaceholderStrings.brandFeatureTagline)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                Text(PlaceholderStrings.settingsVersion)
                    .foregroundStyle(.secondary)
                Text(PlaceholderStrings.brandCopyright)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(Constants.bundleID)
                    .font(AppTheme.Typography.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(
            minWidth: Constants.Settings.minWidth,
            idealWidth: Constants.Settings.windowWidth,
            minHeight: Constants.Settings.minHeight,
            idealHeight: Constants.Settings.windowHeight
        )
        .navigationTitle(PlaceholderStrings.settingsTitle)
        .onAppear {
            accessibility.refresh()
            accessibility.startPeriodicRefresh()
        }
        .onDisappear {
            accessibility.stopPeriodicRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibility.refresh()
        }
    }
}
