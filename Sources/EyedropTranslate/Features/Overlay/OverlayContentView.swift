import SwiftUI

/// 浮层 SwiftUI：loading / success / failure
/// LIVE Figma（0.3.15）：实白卡 radius 16 +「点译」头 + 分割线；成功态中文主行 / 英文次行。
struct OverlayContentView: View {
    let presentation: OverlayPresentation
    var onClose: () -> Void = {}
    var onRetry: () -> Void = {}
    var onOpenAccessibility: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme
    @State private var contentID = UUID()

    private var theme: AppTheme.Palette { AppTheme.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBand
            separator
            content
                .padding(.horizontal, theme.padding)
                .padding(.top, 10)
                .padding(.bottom, theme.padding)
                .frame(minHeight: AppTheme.Metrics.overlayContentMinHeight, alignment: .topLeading)
                .id(contentID)
                .transition(.opacity)
        }
        .frame(width: AppTheme.Metrics.overlayWidth, alignment: .topLeading)
        .frame(minHeight: minHeight, maxHeight: Constants.Overlay.maxHeight, alignment: .topLeading)
        .background(panelBackground)
        .animation(.easeInOut(duration: theme.contentCrossfade), value: contentIdentity)
        .onChange(of: contentIdentity) { _ in
            contentID = UUID()
        }
    }

    private var contentIdentity: String {
        switch presentation {
        case .loading(let s): return "loading:\(s)"
        case .success(let r): return "success:\(r.sourceText):\(r.senses.count)"
        case .failure(let m, _, _): return "failure:\(m)"
        }
    }

    private var minHeight: CGFloat {
        switch presentation {
        case .loading: return Constants.Overlay.loadingHeight
        case .success: return Constants.Overlay.defaultHeight
        case .failure: return Constants.Overlay.defaultHeight
        }
    }

    /// 实卡：浅色纯白；深色系统 elevated（controlBackground）。非 liquid glass。
    private var panelBackground: some View {
        let radius = theme.cornerRadius
        let fill: Color = colorScheme == .dark
            ? AppTheme.SolidCard.darkFill
            : AppTheme.SolidCard.lightFill
        let stroke: Color = colorScheme == .dark
            ? Color.white.opacity(AppTheme.SolidCard.borderOpacity)
            : Color.black.opacity(AppTheme.SolidCard.borderOpacity)
        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: AppTheme.Metrics.overlayBorderWidth)
            )
            .shadow(
                color: theme.shadow,
                radius: AppTheme.Metrics.overlayShadowRadius,
                y: AppTheme.Metrics.overlayShadowY
            )
    }

    /// 头带 ≈ 40pt：「点译」+  discreet Close
    private var headerBand: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(PlaceholderStrings.overlayTitle)
                .font(AppTheme.Typography.overlayHeader)
                .foregroundStyle(theme.primaryLabel)
            Spacer(minLength: 0)
            Button(action: onClose) {
                Text(PlaceholderStrings.overlayClose)
                    .font(AppTheme.Typography.caption2)
                    .foregroundStyle(theme.tertiaryLabel)
            }
            .buttonStyle(.borderless)
            .help(PlaceholderStrings.overlayClose)
        }
        .padding(.horizontal, theme.padding)
        .frame(height: AppTheme.Metrics.overlayHeaderBandHeight, alignment: .center)
    }

    private var separator: some View {
        Rectangle()
            .fill(
                colorScheme == .dark
                    ? theme.separator.opacity(0.55)
                    : AppTheme.SolidCard.lightSeparator
            )
            .frame(height: AppTheme.Metrics.overlaySeparatorHeight)
    }

    @ViewBuilder
    private var content: some View {
        switch presentation {
        case .loading(let source):
            loadingView(source: source)
        case .success(let result):
            successView(result: result.ensuringChineseGlosses())
        case .failure(let message, _, let showAX):
            failureView(message: message, showOpenAccessibility: showAX)
        }
    }

    /// Loading：LIVE 双态 —— 识别中「正在识别文字…」/ 翻译中「正在翻译…」（无骨架 / 无 ProgressView）
    private func loadingView(source: String) -> some View {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let label: String = {
            if trimmed.isEmpty || trimmed == PlaceholderStrings.overlayFetchingSelection {
                return PlaceholderStrings.overlayRecognizing
            }
            return PlaceholderStrings.overlayLoading
        }()
        return Text(label)
            .font(AppTheme.Typography.loadingBody)
            .foregroundStyle(theme.secondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Success：Figma 层级 —— 中文 gloss 大主行 + 英文 source 小次行（见 P0-A-success-content-diff.md）
    private func successView(result: TranslationResult) -> some View {
        let display = result.ensuringChineseGlosses()
        let senses = Array(display.senses.prefix(3))
        let primaryGloss = senses.first?.gloss ?? ""
        let extraSenses = Array(senses.dropFirst())
        let hasMeta = display.primaryPOS != nil || display.primaryPhonetic != nil

        return VStack(alignment: .leading, spacing: 6) {
            if !primaryGloss.isEmpty {
                Text(primaryGloss)
                    .font(AppTheme.Typography.glossPrimary)
                    .foregroundStyle(theme.primaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            Text(display.sourceText)
                .font(AppTheme.Typography.sourceSecondary)
                .foregroundStyle(theme.secondaryLabel)
                .textSelection(.enabled)

            if hasMeta {
                HStack(spacing: 5) {
                    if let phonetic = display.primaryPhonetic {
                        Text(phonetic)
                            .font(AppTheme.Typography.metaCaption)
                            .foregroundStyle(theme.tertiaryLabel)
                    }
                    if display.primaryPhonetic != nil, display.primaryPOS != nil {
                        Text("·")
                            .font(AppTheme.Typography.metaCaption)
                            .foregroundStyle(theme.tertiaryLabel)
                    }
                    if let pos = display.primaryPOS {
                        Text(pos)
                            .font(AppTheme.Typography.metaCaption)
                            .foregroundStyle(theme.tertiaryLabel)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AppTheme.ColorToken.posChipBackground, in: Capsule())
                    }
                }
            }

            ForEach(Array(extraSenses.enumerated()), id: \.offset) { _, sense in
                HStack(alignment: .top, spacing: 5) {
                    Text("·")
                        .foregroundStyle(AppTheme.ColorToken.senseBullet)
                    Text(sense.gloss)
                        .font(AppTheme.Typography.senseSecondary)
                        .foregroundStyle(theme.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            if display.isMockFallback {
                Text(PlaceholderStrings.overlayMockFooter(tip: display.fallbackErrorTip))
                    .font(AppTheme.Typography.caption2)
                    .foregroundStyle(theme.tertiaryLabel)
                    .padding(.top, 2)
            }
        }
    }

    /// Error：PNG 体文为 secondary 灰；保留重试；AX 失败仍用清晰主文案
    private func failureView(message: String, showOpenAccessibility: Bool) -> some View {
        let parts = PlaceholderStrings.failureTitleAndDetail(message)
        return VStack(alignment: .leading, spacing: 10) {
            if showOpenAccessibility {
                Text(parts.title)
                    .font(AppTheme.Typography.failureTitle)
                    .foregroundStyle(theme.primaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = parts.detail {
                    Text(detail)
                        .font(AppTheme.Typography.failureBody)
                        .foregroundStyle(theme.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                // 选区无法识别等：匹配 PNG —— 单行 secondary gray body
                Text(parts.title)
                    .font(AppTheme.Typography.failureBody)
                    .foregroundStyle(theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = parts.detail {
                    Text(detail)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(theme.tertiaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Button(PlaceholderStrings.overlayRetry, action: onRetry)
                    .keyboardShortcut(.defaultAction)
                if showOpenAccessibility {
                    Button(PlaceholderStrings.overlayOpenAccessibility, action: onOpenAccessibility)
                }
            }
        }
    }
}
