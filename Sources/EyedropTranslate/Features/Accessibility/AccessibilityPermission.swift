import ApplicationServices
import AppKit
import Combine
import Foundation

/// 辅助功能（Accessibility）权限：检查信任、引导开启、深链系统设置。
@MainActor
final class AccessibilityPermission: ObservableObject {
    @Published private(set) var isTrusted: Bool = false

    /// 当前可执行 Bundle 路径（诊断用；TCC 常绑旧 DerivedData）。
    var bundlePath: String { Bundle.main.bundlePath }

    private var becomeActiveObserver: NSObjectProtocol?
    private var refreshTimer: Timer?
    /// 信任状态从 false→true 时回调（用于立即刷新菜单栏状态）。
    var onBecameTrusted: (() -> Void)?

    init() {
        refresh()
        becomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAndNotifyIfNewlyTrusted()
            }
        }
    }

    deinit {
        if let becomeActiveObserver {
            NotificationCenter.default.removeObserver(becomeActiveObserver)
        }
        refreshTimer?.invalidate()
    }

    /// 刷新当前进程是否已获辅助功能信任。
    func refresh() {
        isTrusted = AXIsProcessTrusted()
    }

    /// 刷新；若本次从未信任变为已信任，触发 `onBecameTrusted`。
    func refreshAndNotifyIfNewlyTrusted() {
        let wasTrusted = isTrusted
        refresh()
        if !wasTrusted && isTrusted {
            onBecameTrusted?()
        }
    }

    /// - Parameter prompt: 为 `true` 时尝试触发系统提示对话框。
    @discardableResult
    func refresh(promptIfNeeded prompt: Bool) -> Bool {
        // 最可靠的 Swift 形式：CFString 键直接入 NSDictionary / CFDictionary，避免多余 String 桥接。
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let options = [promptKey: prompt] as CFDictionary
        let wasTrusted = isTrusted
        isTrusted = AXIsProcessTrustedWithOptions(options)
        if !wasTrusted && isTrusted {
            onBecameTrusted?()
        }
        return isTrusted
    }

    /// 打开「系统设置 → 隐私与安全性 → 辅助功能」（best-effort + 多 URL 回退）。
    @discardableResult
    func openSystemSettings() -> Bool {
        let candidates = [
            Constants.AccessibilityURLs.modern,
            Constants.AccessibilityURLs.ventura,
            Constants.AccessibilityURLs.legacy,
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return true
            }
        }
        // 最后手段：打开系统设置根
        if let url = URL(string: "x-apple.systempreferences:") {
            return NSWorkspace.shared.open(url)
        }
        return false
    }

    /// 在访达中显示本 App（方便用户对照 TCC 列表中的 EyedropTranslate 路径后 + 添加）。
    func revealAppInFinder() {
        let url = Bundle.main.bundleURL
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// 将当前 Bundle path 复制到通用剪贴板（诊断 / 对照 TCC）。
    func copyBundlePathToPasteboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(bundlePath, forType: .string)
    }

    /// 设置页可见时启动周期性刷新（TCC 状态常滞后于开关切换）。
    func startPeriodicRefresh(interval: TimeInterval = 1.5) {
        stopPeriodicRefresh()
        refresh()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAndNotifyIfNewlyTrusted()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    /// 设置页关闭 / 消失时停止周期性刷新。
    func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
