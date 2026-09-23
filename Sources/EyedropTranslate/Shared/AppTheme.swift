import AppKit
import SwiftUI

/// 设计 tokens：集中换肤钩子。Overlay / Settings / Widget 只读此处，勿散落魔法数。
/// 权威源：`eyedrop-translate/launch/figma-exports/LIVE-FIGMA-TOKENS.md`（live Figma · 0.3.16）。
/// 过渡摘要仍见 `launch/design-tokens-overlay.md`（已指向 LIVE tokens）。
enum AppTheme {
    // MARK: - Appearance / Palette

    enum Appearance: String, CaseIterable {
        case system
        case light
        case dark
    }

    /// 语义色与材质偏好（浮层正文跟系统 Label；品牌 accent 仅用于开关/色点）
    struct Palette {
        var preferredAppearance: Appearance = .system
        var prefersVibrancy: Bool = true
        var primaryLabel: Color = Color(nsColor: .labelColor)
        var secondaryLabel: Color = Color(nsColor: .secondaryLabelColor)
        var tertiaryLabel: Color = Color(nsColor: .tertiaryLabelColor)
        var separator: Color = Color(nsColor: .separatorColor)
        /// 品牌安静蓝绿（非系统 Accent）；浮层正文勿用此色铺字
        var accent: Color = LiquidGlass.brandAccent
        var shadow: Color = Color.black.opacity(SolidCard.shadowOpacity)
        var cornerRadius: CGFloat = Metrics.overlayCornerRadius
        var padding: CGFloat = Metrics.overlayPadding
        var sectionSpacing: CGFloat = Metrics.sectionSpacing
        var appearDuration: TimeInterval = Motion.appearDuration
        var dismissDuration: TimeInterval = Motion.dismissDuration
        var contentCrossfade: TimeInterval = Motion.contentCrossfade
    }

    /// 当前运行时 palette（后续可从偏好注入；默认跟随系统）
    static var palette = Palette()

    // MARK: - Solid Card（LIVE Figma：白底实卡，非液化玻璃）

    /// 浮层卡片材质：浅色 **纯白实底**；深色 **系统 elevated / controlBackground**（勿发明 fancy glass）。
    enum SolidCard {
        /// Figma 浅色卡面
        static let lightFill = Color.white
        /// 深色 elevated 实底（跟系统控件底，非 material）
        static var darkFill: Color { Color(nsColor: .controlBackgroundColor) }
        /// 分割线近似 #E0E0E8（浅色）；深色仍跟系统 separator
        static let lightSeparator = Color(red: 0xE0 / 255.0, green: 0xE0 / 255.0, blue: 0xE8 / 255.0)
        /// 正文主色近似 #181818（浅色稿）；运行时优先系统 label
        static let lightPrimary = Color(red: 0x18 / 255.0, green: 0x18 / 255.0, blue: 0x18 / 255.0)
        /// 次要灰近似 #686870
        static let lightSecondary = Color(red: 0x68 / 255.0, green: 0x68 / 255.0, blue: 0x70 / 255.0)

        /// LIVE shadow：radius ~12, y ~3, opacity ~0.10
        static let shadowOpacity: Double = 0.10
        static let shadowRadius: CGFloat = 12
        static let shadowY: CGFloat = 3
        static let borderOpacity: Double = 0.08
    }

    // MARK: - Liquid Glass（悬浮球等仍用；浮层已改实卡）

    /// 保留给悬浮球 / accent；浮层勿再叠 ultraThinMaterial。
    enum LiquidGlass {
        /// 品牌 accent `#2AA8A0`（LIVE `accent`）
        static let brandAccentTeal = NSColor(srgbRed: 0x2A / 255.0, green: 0xA8 / 255.0, blue: 0xA0 / 255.0, alpha: 1)
        static var brandAccent: Color { Color(nsColor: brandAccentTeal) }

        /// 品牌黑 `#0A0A0A`（LIVE `color/brand/black`；字标 / 主按钮）
        static let brandBlack = NSColor(srgbRed: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x0A / 255.0, alpha: 1)
        static var brandBlackColor: Color { Color(nsColor: brandBlack) }

        static let borderHighlightOpacity: Double = 0.45
        static var borderHighlight: Color { Color.white.opacity(borderHighlightOpacity) }

        static let glassTintOpacity: Double = 0.05
        static var glassTint: Color { Color.white.opacity(glassTintOpacity) }

        static let topHighlightOpacity: Double = 0.55
        static let topHighlightHeight: CGFloat = 1

        /// 悬浮球仍可用略不同阴影；浮层卡用 SolidCard shadow
        static let shadowOpacity: Double = 0.08
        static let shadowRadius: CGFloat = 14
        static let shadowY: CGFloat = 2

        static let ballOnOpacity: CGFloat = 0.95
        static let ballOffOpacity: CGFloat = 0.55
        static let ballBorderOnOpacity: CGFloat = 0.65
        static let ballBorderOffOpacity: CGFloat = 0.25
    }

    // MARK: - Motion（出现 150–200ms；消失 ~120ms；rise 更轻 3pt）

    enum Motion {
        static let appearDuration: TimeInterval = 0.18
        static let dismissDuration: TimeInterval = 0.12
        static let contentCrossfade: TimeInterval = 0.12
        static let appearRise: CGFloat = 3
        static let appearScaleFrom: CGFloat = 0.98
    }

    // MARK: - Color tokens

    enum ColorToken {
        static let overlayMaterialOpacity: Double = 1.0
        static var overlayShadow: Color { AppTheme.palette.shadow }
        static var senseBullet: Color { AppTheme.palette.secondaryLabel }
        static let posChipBackground = Color(nsColor: .secondaryLabelColor).opacity(0.10)
        static let skeletonPrimary = Color(nsColor: .secondaryLabelColor).opacity(0.20)
        static let skeletonSecondary = Color(nsColor: .secondaryLabelColor).opacity(0.12)
        static let success = Color.green
        static let warning = Color.orange
        static var brandAccent: Color { LiquidGlass.brandAccent }
        /// LIVE `color/brand/black` `#0A0A0A`
        static var brandBlack: Color { LiquidGlass.brandBlackColor }
    }

    // MARK: - Typography（LIVE Figma type table + overlay hierarchy）

    enum Typography {
        /// 壳标题「点译」~13–14 medium/semibold
        static let overlayHeader: Font = .system(size: 13.5, weight: .semibold)
        /// 兼容旧名 → 同 overlayHeader
        static let overlayTitle: Font = overlayHeader
        /// 设置关于显示名 / Title 16 Medium（LIVE）
        static let settingsDisplayName: Font = .system(size: 16, weight: .medium)
        /// 成功态：首条中文 gloss ~17–18 semibold（如「翻译器」）
        static let glossPrimary: Font = .system(size: 17.5, weight: .semibold)
        /// 成功态：英文 source ~12–13 regular secondary（如「translator」）
        static let sourceSecondary: Font = .system(size: 12.5, weight: .regular)
        /// 旧：原文作主行（已弃用层级；保留以免其他引用断裂）
        static let sourceWord: Font = glossPrimary
        /// 音标 · 词性 compact caption
        static let metaCaption: Font = .system(size: 11, weight: .regular)
        /// 额外义项 bullets
        static let sensePrimary: Font = .system(size: 13, weight: .medium)
        static let senseSecondary: Font = .system(size: 12, weight: .regular)
        static let senseBody: Font = .system(size: 13, weight: .medium)
        static let caption: Font = .caption
        static let caption2: Font = .caption2
        /// 失败体文（PNG：secondary gray ~13）
        static let failureTitle: Font = .system(size: 13, weight: .semibold)
        static let failureBody: Font = .system(size: 13, weight: .regular)
        static let loadingBody: Font = .system(size: 13, weight: .regular)
        static let slogan: Font = .system(size: 13, weight: .medium)
    }

    // MARK: - Metrics（LIVE Figma card：宽 260，圆角 16，padding 16，头带 ~40）

    enum Metrics {
        static let overlayWidth: CGFloat = 260
        /// Direct Figma card radius **16**（raster ≈14；工程对齐图层值）
        static let overlayCornerRadius: CGFloat = 16
        static let overlayPadding: CGFloat = 16
        /// 头带到分割线 ≈ 40pt
        static let overlayHeaderBandHeight: CGFloat = 40
        static let overlaySeparatorHeight: CGFloat = 0.5
        static let sectionSpacing: CGFloat = 8
        static let overlayShadowRadius: CGFloat = SolidCard.shadowRadius
        static let overlayShadowY: CGFloat = SolidCard.shadowY
        static let overlayBorderWidth: CGFloat = 0.5
        /// 加载/成功内容区最小高度（壳外另加 header band）
        static let overlayContentMinHeight: CGFloat = 40
        static let floatingBallDiameter: CGFloat = 48
        static let floatingBallEdgeInset: CGFloat = 8
        /// Figma「悬浮球 48」圆角方 continuous（约 12pt）
        static let floatingBallCornerRadius: CGFloat = 12
        /// 白色几何 e 相对 48pt 球的内边距
        static let floatingBallIconInset: CGFloat = 12
    }
}
