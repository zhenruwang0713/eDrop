import AppKit
import QuartzCore
import SwiftUI

/// 释义浮层：`NSPanel` + `.nonactivatingPanel`，不抢焦点；Esc / 点外关闭。
/// 出现：150–200ms fade + 上移 3pt；消失：120ms fade。
@MainActor
final class OverlayPanelController {
    private var panel: NSPanel?
    private var hosting: NSHostingView<OverlayContentView>?
    private var localKeyMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    private(set) var presentation: OverlayPresentation = .loading(sourceText: "")
    var onRetry: (() -> Void)?
    var onOpenAccessibility: (() -> Void)?

    var isVisible: Bool { panel?.isVisible ?? false }

    /// 屏幕坐标点是否落在浮层内（选中即译忽略点击本浮层）
    func containsScreenPoint(_ point: NSPoint) -> Bool {
        guard let panel, panel.isVisible else { return false }
        return panel.frame.contains(point)
    }

    func show(_ presentation: OverlayPresentation, near point: NSPoint? = nil) {
        self.presentation = presentation
        let panel = ensurePanel()
        refreshContent()
        resizeToFit()
        position(panel, near: point)
        animateAppear(panel)
        installDismissMonitors()
    }

    /// 更新内容；若面板已关闭则重新展示（避免 loading 后静默无结果）
    func update(_ presentation: OverlayPresentation) {
        self.presentation = presentation
        if !isVisible {
            show(presentation, near: NSEvent.mouseLocation)
            return
        }
        refreshContent()
        resizeToFit()
    }

    func hide() {
        removeDismissMonitors()
        guard let panel, panel.isVisible else {
            panel?.orderOut(nil)
            return
        }
        animateDismiss(panel)
    }

    /// 若当前仍是「正在取词…」占位 loading（无拉丁选区被启发式跳过），关掉以免卡住。
    func dismissIfLoadingFetchPlaceholder() {
        if case .loading(let source) = presentation,
           source == PlaceholderStrings.overlayFetchingSelection {
            hide()
        }
    }

    // MARK: - Appear / Dismiss

    private func animateAppear(_ panel: NSPanel) {
        let rise = AppTheme.Motion.appearRise
        var frame = panel.frame
        // 从下方 3pt 起，淡入上移（AppTheme.Motion.appearRise）
        frame.origin.y -= rise
        panel.alphaValue = 0
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()

        var target = frame
        target.origin.y += rise

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = AppTheme.Motion.appearDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(target, display: true)
        }
    }

    private func animateDismiss(_ panel: NSPanel) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = AppTheme.Motion.dismissDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
        })
    }

    // MARK: - Panel

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let content = makeContentView()
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(
            x: 0, y: 0,
            width: Constants.Overlay.defaultWidth,
            height: Constants.Overlay.defaultHeight
        )

        let panel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.contentView = hostingView
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.alphaValue = 1

        self.hosting = hostingView
        self.panel = panel
        return panel
    }

    private func makeContentView() -> OverlayContentView {
        OverlayContentView(
            presentation: presentation,
            onClose: { [weak self] in self?.hide() },
            onRetry: { [weak self] in self?.onRetry?() },
            onOpenAccessibility: { [weak self] in self?.onOpenAccessibility?() }
        )
    }

    private func refreshContent() {
        guard let hosting else { return }
        hosting.rootView = makeContentView()
        hosting.needsLayout = true
        hosting.needsDisplay = true
        hosting.invalidateIntrinsicContentSize()
    }

    private func resizeToFit() {
        guard let panel, let hosting else { return }
        hosting.invalidateIntrinsicContentSize()
        let size = hosting.fittingSize
        var frame = panel.frame
        frame.size = NSSize(
            width: max(Constants.Overlay.defaultWidth, size.width),
            height: min(Constants.Overlay.maxHeight, max(Constants.Overlay.loadingHeight, size.height))
        )
        panel.setFrame(frame, display: true)
    }

    private func position(_ panel: NSPanel, near point: NSPoint?) {
        let size = panel.frame.size
        if let point {
            var origin = NSPoint(
                x: point.x + 12,
                y: point.y - size.height - 12
            )
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.visibleFrame, false) })
                ?? NSScreen.main {
                let visible = screen.visibleFrame
                origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
                origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
            }
            panel.setFrameOrigin(origin)
        } else if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let x = frame.midX - size.width / 2
            let y = frame.midY - size.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    // MARK: - Esc / 点外关闭

    private func installDismissMonitors() {
        removeDismissMonitors()

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.hide()
                return nil
            }
            return event
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.dismissIfOutside(event)
            return event
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.dismissIfOutside(event)
        }
    }

    private func dismissIfOutside(_ event: NSEvent) {
        guard let panel, panel.isVisible else { return }
        let point: NSPoint
        if event.window == nil {
            point = NSEvent.mouseLocation
        } else {
            let loc = event.locationInWindow
            point = event.window?.convertPoint(toScreen: loc) ?? NSEvent.mouseLocation
        }
        if !panel.frame.contains(point) {
            hide()
        }
    }

    private func removeDismissMonitors() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }
}
