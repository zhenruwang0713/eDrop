import AppKit
import Combine
import QuartzCore

/// 桌面挂件默认形态：**悬浮球 48**（对齐 Figma「02 组件」品牌 e 标）
/// - 48pt 品牌黑 `#0A0A0A` 圆角方（continuous）+ 白色几何 **e**（`FloatingBallIcon` 矢量 PDF）
/// - **单击**：打开划词本
/// - **右键**：切换「选中即译」（关态更透、灰边、弱化 e）
/// - `nonactivatingPanel`，不抢焦点；`orderFrontRegardless` + floating + canJoinAllSpaces
@MainActor
final class DesktopFloatingBallController {
    private var panel: NSPanel?
    private var ballView: FloatingBallView?
    private let preferences: AppPreferences
    private let onClick: () -> Void
    private let onToggleAutoTranslate: () -> Void
    private let onOpenSettings: (() -> Void)?
    private var dragStartMouse: NSPoint?
    private var dragStartOrigin: NSPoint?
    private var didDrag = false
    private var cancellables = Set<AnyCancellable>()

    private let diameter = AppTheme.Metrics.floatingBallDiameter
    private let edgeInset = AppTheme.Metrics.floatingBallEdgeInset

    init(
        preferences: AppPreferences,
        onClick: @escaping () -> Void,
        onToggleAutoTranslate: @escaping () -> Void,
        onOpenSettings: (() -> Void)? = nil
    ) {
        self.preferences = preferences
        self.onClick = onClick
        self.onToggleAutoTranslate = onToggleAutoTranslate
        self.onOpenSettings = onOpenSettings
    }

    /// 安装并前置；已安装时再次 `orderFrontRegardless`（菜单「显示悬浮球」）
    func install() {
        guard panel == nil else {
            panel?.orderFrontRegardless()
            applyAutoTranslateAppearance()
            return
        }

        let size = NSSize(width: diameter, height: diameter)
        let ball = FloatingBallView(frame: NSRect(origin: .zero, size: size))
        ball.onMouseDown = { [weak self] event in
            self?.beginDrag(event)
        }
        ball.onMouseDragged = { [weak self] event in
            self?.continueDrag(event)
        }
        ball.onMouseUp = { [weak self] event in
            self?.endDrag(event)
        }
        ball.onRightMouseUp = { [weak self] _ in
            self?.toggleAutoTranslate()
        }
        ballView = ball

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
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
        panel.contentView = ball
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = false

        self.panel = panel
        positionDefault(panel)
        applyAutoTranslateAppearance()
        panel.orderFrontRegardless()

        preferences.$autoTranslateOnSelection
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyAutoTranslateAppearance()
            }
            .store(in: &cancellables)
    }

    /// 菜单「显示悬浮球」入口
    func show() {
        install()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    /// 外部偏好变更时也可主动刷新外观
    func applyAutoTranslateAppearance() {
        let on = preferences.autoTranslateOnSelection
        ballView?.applyAutoTranslateOn(on)
        ballView?.toolTip = on
            ? PlaceholderStrings.floatingBallTooltipAutoOn
            : PlaceholderStrings.floatingBallTooltipAutoOff
    }

    private func toggleAutoTranslate() {
        onToggleAutoTranslate()
        applyAutoTranslateAppearance()
    }

    // MARK: - Position

    private func positionDefault(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.maxX - diameter - edgeInset - 12,
            y: visible.midY - diameter / 2
        )
        panel.setFrameOrigin(snap(origin, size: panel.frame.size, in: visible))
    }

    private func snap(_ origin: NSPoint, size: NSSize, in visible: NSRect) -> NSPoint {
        var o = origin
        o.x = min(max(o.x, visible.minX + edgeInset), visible.maxX - size.width - edgeInset)
        o.y = min(max(o.y, visible.minY + edgeInset), visible.maxY - size.height - edgeInset)

        let distLeft = o.x - visible.minX
        let distRight = visible.maxX - (o.x + size.width)
        let distBottom = o.y - visible.minY
        let distTop = visible.maxY - (o.y + size.height)
        let threshold: CGFloat = 36

        if distLeft < threshold && distLeft <= distRight {
            o.x = visible.minX + edgeInset
        } else if distRight < threshold {
            o.x = visible.maxX - size.width - edgeInset
        }
        if distBottom < threshold && distBottom <= distTop {
            o.y = visible.minY + edgeInset
        } else if distTop < threshold {
            o.y = visible.maxY - size.height - edgeInset
        }
        return o
    }

    // MARK: - Drag / click

    private func beginDrag(_ event: NSEvent) {
        guard let panel else { return }
        dragStartMouse = NSEvent.mouseLocation
        dragStartOrigin = panel.frame.origin
        didDrag = false
    }

    private func continueDrag(_ event: NSEvent) {
        guard let panel,
              let startMouse = dragStartMouse,
              let startOrigin = dragStartOrigin else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - startMouse.x
        let dy = now.y - startMouse.y
        if hypot(dx, dy) > 3 { didDrag = true }
        let next = NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy)
        let screen = NSScreen.screens.first(where: { NSMouseInRect(now, $0.visibleFrame, false) })
            ?? NSScreen.main
        let visible = screen?.visibleFrame ?? panel.frame
        panel.setFrameOrigin(clamp(next, size: panel.frame.size, in: visible))
    }

    private func endDrag(_ event: NSEvent) {
        defer {
            dragStartMouse = nil
            dragStartOrigin = nil
        }
        guard let panel else { return }
        if didDrag {
            let screen = NSScreen.screens.first(where: {
                NSMouseInRect(NSEvent.mouseLocation, $0.visibleFrame, false)
            }) ?? NSScreen.main
            if let visible = screen?.visibleFrame {
                let snapped = snap(panel.frame.origin, size: panel.frame.size, in: visible)
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.18
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    panel.animator().setFrameOrigin(snapped)
                }
            }
        } else {
            onClick()
        }
        didDrag = false
    }

    private func clamp(_ origin: NSPoint, size: NSSize, in visible: NSRect) -> NSPoint {
        var o = origin
        o.x = min(max(o.x, visible.minX + edgeInset), visible.maxX - size.width - edgeInset)
        o.y = min(max(o.y, visible.minY + edgeInset), visible.maxY - size.height - edgeInset)
        return o
    }
}

/// Figma「悬浮球 48」：品牌黑圆角方 + 白色几何 e（FloatingBallIcon PDF）；无 MenuBarIcon 放大、无 drop.fill
@MainActor
private final class FloatingBallView: NSView {
    var onMouseDown: ((NSEvent) -> Void)?
    var onMouseDragged: ((NSEvent) -> Void)?
    var onMouseUp: ((NSEvent) -> Void)?
    var onRightMouseUp: ((NSEvent) -> Void)?

    private let fillLayer = CALayer()
    private let borderLayer = CALayer()
    private let symbol = NSImageView()
    private var autoOn = true

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false

        let corner = AppTheme.Metrics.floatingBallCornerRadius
        fillLayer.frame = bounds
        fillLayer.cornerRadius = corner
        fillLayer.cornerCurve = .continuous
        fillLayer.backgroundColor = AppTheme.LiquidGlass.brandBlack.cgColor
        layer?.addSublayer(fillLayer)

        borderLayer.frame = bounds
        borderLayer.cornerRadius = corner
        borderLayer.cornerCurve = .continuous
        borderLayer.borderWidth = 1.0
        borderLayer.borderColor = NSColor.clear.cgColor
        borderLayer.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(borderLayer)

        // 勿用 MenuBarIcon 16/32：放大到悬浮球会糊。专用矢量 FloatingBallIcon（PDF）。
        if let named = NSImage(named: "FloatingBallIcon") {
            named.isTemplate = true
            symbol.image = named
        } else if let fallback = NSImage(named: "MenuBarIcon") {
            fallback.isTemplate = true
            symbol.image = fallback
        }
        symbol.contentTintColor = .white
        symbol.imageScaling = .scaleProportionallyUpOrDown
        let inset = AppTheme.Metrics.floatingBallIconInset
        symbol.frame = bounds.insetBy(dx: inset, dy: inset)
        symbol.autoresizingMask = [.width, .height]
        addSubview(symbol)

        toolTip = PlaceholderStrings.floatingBallTooltip
        applyAutoTranslateOn(true)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let corner = AppTheme.Metrics.floatingBallCornerRadius
        fillLayer.frame = bounds
        fillLayer.cornerRadius = corner
        borderLayer.frame = bounds
        borderLayer.cornerRadius = corner
        let inset = AppTheme.Metrics.floatingBallIconInset
        symbol.frame = bounds.insetBy(dx: inset, dy: inset)
    }

    func applyAutoTranslateOn(_ on: Bool) {
        autoOn = on
        alphaValue = on ? AppTheme.LiquidGlass.ballOnOpacity : AppTheme.LiquidGlass.ballOffOpacity
        fillLayer.backgroundColor = AppTheme.LiquidGlass.brandBlack.cgColor
        if on {
            borderLayer.borderWidth = 0
            borderLayer.borderColor = NSColor.clear.cgColor
            symbol.contentTintColor = .white
            symbol.alphaValue = 1.0
        } else {
            borderLayer.borderWidth = 1.0
            borderLayer.borderColor = NSColor.secondaryLabelColor
                .withAlphaComponent(AppTheme.LiquidGlass.ballBorderOffOpacity + 0.2).cgColor
            symbol.contentTintColor = NSColor.white.withAlphaComponent(0.55)
            symbol.alphaValue = 0.75
        }
    }

    override func mouseDown(with event: NSEvent) { onMouseDown?(event) }
    override func mouseDragged(with event: NSEvent) { onMouseDragged?(event) }
    override func mouseUp(with event: NSEvent) { onMouseUp?(event) }

    override func rightMouseUp(with event: NSEvent) {
        onRightMouseUp?(event)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
