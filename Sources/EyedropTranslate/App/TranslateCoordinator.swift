import AppKit
import Foundation

/// 菜单栏状态（反映权限 / 空闲 / 翻译中）
enum MenuBarStatus: Equatable {
    case needsPermission
    case idle
    case translating

    var symbolName: String {
        switch self {
        case .needsPermission: return "exclamationmark.triangle"
        case .idle: return "character.book.closed"
        case .translating: return "ellipsis.circle"
        }
    }

    /// 菜单栏 tooltip：含选中即译开关与信任状态
    func tooltip(autoOn: Bool, trusted: Bool) -> String {
        let autoPart = autoOn
            ? PlaceholderStrings.menuTooltipAutoOn
            : PlaceholderStrings.menuTooltipAutoOff
        let trustPart = trusted
            ? PlaceholderStrings.menuTooltipTrusted
            : PlaceholderStrings.menuTooltipUntrusted
        switch self {
        case .needsPermission:
            return "\(Constants.appName) · \(PlaceholderStrings.menuStatusNeedsPermission) · \(autoPart)"
        case .idle:
            return "\(Constants.appName) · \(PlaceholderStrings.menuStatusIdle) · \(autoPart) · \(trustPart)"
        case .translating:
            return "\(PlaceholderStrings.menuStatusTranslating) · \(autoPart)"
        }
    }
}

/// M1 编排：读选区 → 浮层 loading → 翻译 → success/failure（带超时，禁止永远卡住）
/// 0.3.1：拖拽选区手势可见 loading；失败可见；Mock 中文义；⌘C 更稳。
@MainActor
final class TranslateCoordinator: ObservableObject {
    @Published private(set) var status: MenuBarStatus = .idle
    /// Settings 实时：上次引擎路径 + 可选错误
    @Published private(set) var lastEngineNote: String = PlaceholderStrings.settingsEngineStatusIdle
    @Published private(set) var lastErrorNote: String?

    let accessibility: AccessibilityPermission
    private let selectionReader: SelectionReading
    private let translateService: TranslateService
    private let overlay: OverlayPanelController
    private let preferences: AppPreferences
    private let wordbookStore: WordbookStore

    private var currentTask: Task<Void, Never>?
    /// 剪贴板回退独立任务，避免与 `beginTranslate` 的 `currentTask` 互相 cancel / nil
    private var clipboardFallbackTask: Task<Void, Never>?
    private var lastSourceText: String?
    private var lastAnchor: CGPoint?
    /// 选中即译去重：仅记录**成功**译过的规范化文本（失败不占位，允许重试）
    private var lastAutoTranslatedText: String?
    /// 当前 auto 路径待写入的去重键（成功后写入 lastAutoTranslatedText）
    private var pendingAutoDedupeKey: String?
    /// 菜单打开瞬间预读的选区（避免菜单抢焦点后选区丢失）
    private var prefetched: SelectionReadResult?
    /// 菜单打开前的前台 App（排除自身），供 Cmd+C 前回活
    private var previousFrontmostApp: NSRunningApplication?

    /// 翻译硬超时（秒），超时 → failure，不静默、不永不结束
    private let translateTimeoutSeconds: TimeInterval = 15

    /// 复活前台 App 后等待焦点稳定
    private let reactivateDelayNs: UInt64 = 250_000_000
    /// 合成 Cmd+C 后等待读板（菜单路径）
    private let clipboardFallbackDelayNs: UInt64 = 350_000_000
    /// 选中即译 Cmd+C 后等待读板（~350ms）
    private let autoClipboardDelayNs: UInt64 = 350_000_000

    init(
        accessibility: AccessibilityPermission,
        selectionReader: SelectionReading,
        translateService: TranslateService,
        overlay: OverlayPanelController,
        preferences: AppPreferences,
        wordbookStore: WordbookStore
    ) {
        self.accessibility = accessibility
        self.selectionReader = selectionReader
        self.translateService = translateService
        self.overlay = overlay
        self.preferences = preferences
        self.wordbookStore = wordbookStore

        overlay.onRetry = { [weak self] in
            self?.retry()
        }
        overlay.onOpenAccessibility = { [weak self] in
            self?.accessibility.openSystemSettings()
        }

        refreshStatus()
    }

    var engineDisplayName: String { translateService.engineDisplayName }

    /// Settings「翻译服务」状态行（含上次路径 / 错误）
    var engineStatusLine: String {
        let live = translateService.statusLine
        if live != translateService.engineDisplayName {
            return live
        }
        if let err = lastErrorNote, !err.isEmpty {
            return "\(lastEngineNote)\n\(PlaceholderStrings.settingsEngineLastErrorPrefix)\(err)"
        }
        return lastEngineNote
    }

    var isAutoTranslateEnabled: Bool { preferences.autoTranslateOnSelection }

    func refreshStatus() {
        accessibility.refresh()
        if !accessibility.isTrusted {
            status = .needsPermission
        } else if currentTask != nil || clipboardFallbackTask != nil {
            status = .translating
        } else {
            status = .idle
        }
    }

    // MARK: - 选中即译（P0 · 0.3.1）

    /// 鼠标松开 debounce 后由 `SelectionAutoMonitor` 调用。
    /// - Parameter expectSelection: 拖拽距离 ≥ 阈值，确认为选区手势；失败必须可见，禁止静默。
    func autoTranslateAfterSelection(expectSelection: Bool = true) {
        guard preferences.autoTranslateOnSelection else { return }

        accessibility.refresh()
        if !accessibility.isTrusted {
            presentAutoPermissionFailure()
            return
        }

        let near = NSEvent.mouseLocation

        // 可观测性：确认选区手势后立刻出 loading，让用户看到 auto 路径已触发
        if expectSelection {
            status = .translating
            overlay.show(.loading(sourceText: PlaceholderStrings.overlayFetchingSelection), near: near)
        }

        let result = selectionReader.readCurrentSelection()

        switch result {
        case .success(let snapshot):
            considerAutoTranslate(text: snapshot.text, anchor: snapshot.anchorPoint, fromAuto: true)
        case .failure(let kind):
            switch kind {
            case .noPermission:
                presentAutoPermissionFailure()
            case .noSelection, .unsupported, .other:
                // 网页等 AX 常空：焦点仍在源 App → 合成 ⌘C 取词
                attemptAutoClipboardThenSkipOrFail(near: near, expectSelection: expectSelection)
            }
        }
    }

    /// 未授权时的可见失败（由 Monitor 限流后调用，或 auto 路径内）
    func presentAutoPermissionFailure() {
        let near = NSEvent.mouseLocation
        status = .needsPermission
        pendingAutoDedupeKey = nil
        overlay.show(
            .failure(
                message: PlaceholderStrings.axFirstRunBody,
                retryText: nil,
                showOpenAccessibility: true
            ),
            near: near
        )
        accessibility.refresh(promptIfNeeded: true)
        refreshStatus()
    }

    private func considerAutoTranslate(text: String, anchor: CGPoint, fromAuto: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let normalized = Self.normalizeForDedupe(trimmed)
        // 仅跳过成功译过的同一文本；失败不占位
        if fromAuto, normalized == lastAutoTranslatedText {
            overlay.dismissIfLoadingFetchPlaceholder()
            refreshStatus()
            return
        }

        if Self.isTooLongForAuto(trimmed) {
            if fromAuto { pendingAutoDedupeKey = nil }
            overlay.show(
                .failure(
                    message: PlaceholderStrings.failSelectionTooLong,
                    retryText: nil,
                    showOpenAccessibility: false
                ),
                near: anchor
            )
            refreshStatus()
            return
        }

        // EN→ZH 产品启发式：无拉丁字母则跳过（避免中文划选误触发）；静默
        guard Self.containsLatinLetter(trimmed) else {
            if fromAuto {
                // 若已显示「正在取词」loading，关掉以免卡住
                overlay.dismissIfLoadingFetchPlaceholder()
                refreshStatus()
            }
            return
        }

        if fromAuto {
            pendingAutoDedupeKey = normalized
        }
        beginTranslate(text: trimmed, anchor: anchor, commitAutoDedupeOnSuccess: fromAuto)
    }

    /// 选中即译剪贴板回退：前台已是源 App，合成 ⌘C → 等 → 读板 → 还原。
    /// `expectSelection == false`：仍空则静默；`true`：可见失败（网页 hint）。
    private func attemptAutoClipboardThenSkipOrFail(near: CGPoint, expectSelection: Bool) {
        accessibility.refresh()
        guard accessibility.isTrusted else {
            presentAutoPermissionFailure()
            return
        }

        clipboardFallbackTask?.cancel()
        if expectSelection {
            status = .translating
        }

        clipboardFallbackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.clipboardFallbackTask = nil
                if self.currentTask == nil {
                    self.refreshStatus()
                }
            }

            if let text = await self.clipboardSnapshotViaCopyInPlace() {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    self.considerAutoTranslate(text: trimmed, anchor: near, fromAuto: true)
                    return
                }
            }

            guard !Task.isCancelled else { return }

            if expectSelection {
                // 真实拖拽选区却读不到：禁止静默
                self.pendingAutoDedupeKey = nil
                self.overlay.show(
                    .failure(
                        message: PlaceholderStrings.failNoSelectionWebHint,
                        retryText: nil,
                        showOpenAccessibility: false
                    ),
                    near: near
                )
            }
            // 非选区手势：静默（普通点击不应出失败浮层）
        }
    }

    /// 不复活 App（选中即译时焦点仍在源 App）：存板 → ⌘C → 等 → 读 → 还原。
    private func clipboardSnapshotViaCopyInPlace() async -> String? {
        let pb = NSPasteboard.general
        let savedString = pb.string(forType: .string)

        guard postCommandC() else { return nil }

        try? await Task.sleep(nanoseconds: autoClipboardDelayNs)
        guard !Task.isCancelled else { return nil }

        let newString = pb.string(forType: .string)

        pb.clearContents()
        if let savedString {
            pb.setString(savedString, forType: .string)
        }

        guard let newString else { return nil }
        let trimmed = newString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let savedString, newString == savedString { return nil }
        return trimmed
    }

    // MARK: - Auto heuristics

    static func normalizeForDedupe(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }

    static func containsLatinLetter(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (scalar.value >= 0x41 && scalar.value <= 0x5A)
                || (scalar.value >= 0x61 && scalar.value <= 0x7A)
        }
    }

    static func isTooLongForAuto(_ text: String) -> Bool {
        if text.count > Constants.AutoTranslate.maxCharacterCount { return true }
        let words = text.split { $0.isWhitespace || $0.isNewline }.filter { !$0.isEmpty }
        return words.count > Constants.AutoTranslate.maxWordCount
    }

    // MARK: - Menu paths（兜底）

    /// 菜单即将打开：记录前台 App，并趁焦点未丢先读选区
    func prefetchSelectionForMenu() {
        capturePreviousFrontmostApp()
        accessibility.refresh()
        guard accessibility.isTrusted else {
            prefetched = .failure(.noPermission)
            return
        }
        prefetched = selectionReader.readCurrentSelection()
    }

    /// 仅记录菜单打开前的前台 App（排除自身）
    func rememberFrontmostAppForMenu() {
        capturePreviousFrontmostApp()
    }

    private func capturePreviousFrontmostApp() {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != selfPID,
           !front.isTerminated {
            previousFrontmostApp = front
        }
    }

    /// 菜单「翻译选区」入口（兜底）
    func translateSelection() {
        accessibility.refresh()
        if !accessibility.isTrusted {
            status = .needsPermission
            let near = NSEvent.mouseLocation
            overlay.show(
                .failure(
                    message: PlaceholderStrings.axFirstRunBody,
                    retryText: nil,
                    showOpenAccessibility: true
                ),
                near: near
            )
            accessibility.refresh(promptIfNeeded: true)
            refreshStatus()
            prefetched = nil
            return
        }

        // 优先用菜单打开时的预取；失败再现场读一次
        let cached = prefetched
        prefetched = nil
        let result: SelectionReadResult
        if let cached, case .success = cached {
            result = cached
        } else {
            let live = selectionReader.readCurrentSelection()
            if case .success = live {
                result = live
            } else {
                result = cached ?? live
            }
        }

        switch result {
        case .success(let snapshot):
            beginTranslate(text: snapshot.text, anchor: snapshot.anchorPoint, commitAutoDedupeOnSuccess: false)
        case .failure(let kind):
            // AX 失败（无选区 / 不支持 / 其他）→ 剪贴板 / 复活+Cmd+C 回退
            switch kind {
            case .noSelection, .unsupported, .other:
                attemptClipboardFallbackThenFail(axFailure: kind)
            case .noPermission:
                presentSelectionFailure(kind)
            }
        }
    }

    /// 菜单「翻译剪贴板」：不走 AX，直接翻译当前通用剪贴板字符串
    func translateClipboard() {
        let near = NSEvent.mouseLocation
        let pb = NSPasteboard.general
        guard let raw = pb.string(forType: .string) else {
            overlay.show(
                .failure(
                    message: PlaceholderStrings.failClipboardEmpty,
                    retryText: nil,
                    showOpenAccessibility: false
                ),
                near: near
            )
            refreshStatus()
            return
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            overlay.show(
                .failure(
                    message: PlaceholderStrings.failClipboardEmpty,
                    retryText: nil,
                    showOpenAccessibility: false
                ),
                near: near
            )
            refreshStatus()
            return
        }
        beginTranslate(text: trimmed, anchor: near, commitAutoDedupeOnSuccess: false)
    }

    func retry() {
        if let text = lastSourceText ?? overlay.presentation.sourceTextForRetry {
            beginTranslate(text: text, anchor: lastAnchor ?? NSEvent.mouseLocation, commitAutoDedupeOnSuccess: false)
        } else {
            translateSelection()
        }
    }

    // MARK: - Clipboard fallback (菜单「翻译选区」)

    /// AX 读选区失败后：
    /// 1) 若剪贴板已有像用户内容的文本 → 直接翻译（可先 ⌘C 再点「翻译选区」）
    /// 2) 否则复活菜单打开前的前台 App → 短等 → 合成 ⌘C → 再等 → 读板 → 还原
    private func attemptClipboardFallbackThenFail(axFailure: SelectionFailureKind) {
        let near = NSEvent.mouseLocation

        if let existing = existingClipboardUserContent() {
            beginTranslate(text: existing, anchor: near, commitAutoDedupeOnSuccess: false)
            return
        }

        accessibility.refresh()
        guard accessibility.isTrusted else {
            presentSelectionFailure(axFailure, near: near)
            return
        }

        clipboardFallbackTask?.cancel()
        status = .translating

        clipboardFallbackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.clipboardFallbackTask = nil
                if self.currentTask == nil {
                    self.refreshStatus()
                }
            }

            if let text = await self.clipboardSnapshotViaCopyAfterReactivate() {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    self.beginTranslate(text: trimmed, anchor: near, commitAutoDedupeOnSuccess: false)
                    return
                }
            }
            guard !Task.isCancelled else { return }
            self.presentSelectionFailure(axFailure, near: near)
        }
    }

    private func existingClipboardUserContent() -> String? {
        guard let raw = NSPasteboard.general.string(forType: .string) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard looksLikeUserContent(trimmed) else { return nil }
        return trimmed
    }

    private func looksLikeUserContent(_ text: String) -> Bool {
        guard !text.isEmpty, text.count <= 50_000 else { return false }
        return text.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }

    private func presentSelectionFailure(_ kind: SelectionFailureKind, near: CGPoint? = nil) {
        let point = near ?? NSEvent.mouseLocation
        let message: String
        switch kind {
        case .noSelection, .unsupported, .other:
            message = PlaceholderStrings.failNoSelectionWebHint
        case .noPermission:
            message = kind.userMessage
        }
        overlay.show(
            .failure(
                message: message,
                retryText: nil,
                showOpenAccessibility: kind == .noPermission
            ),
            near: point
        )
        refreshStatus()
    }

    private func clipboardSnapshotViaCopyAfterReactivate() async -> String? {
        await reactivatePreviousFrontmostApp()
        guard !Task.isCancelled else { return nil }

        let pb = NSPasteboard.general
        let savedString = pb.string(forType: .string)

        guard postCommandC() else { return nil }

        try? await Task.sleep(nanoseconds: clipboardFallbackDelayNs)
        guard !Task.isCancelled else { return nil }

        let newString = pb.string(forType: .string)

        pb.clearContents()
        if let savedString {
            pb.setString(savedString, forType: .string)
        }

        guard let newString else { return nil }
        let trimmed = newString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let savedString, newString == savedString { return nil }
        return trimmed
    }

    private func reactivatePreviousFrontmostApp() async {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let target: NSRunningApplication?
        if let remembered = previousFrontmostApp, !remembered.isTerminated,
           remembered.processIdentifier != selfPID {
            target = remembered
        } else if let front = NSWorkspace.shared.frontmostApplication,
                  front.processIdentifier != selfPID,
                  !front.isTerminated {
            target = front
        } else {
            target = nil
        }

        guard let target else { return }

        if #available(macOS 14.0, *) {
            _ = target.activate()
        } else {
            _ = target.activate(options: [.activateIgnoringOtherApps])
        }

        try? await Task.sleep(nanoseconds: reactivateDelayNs)
    }

    /// 合成 ⌘C：先确认 AX 信任；优先 hidSystemState，失败再试 combinedSessionState；
    /// keyDown / keyUp 均带 `.maskCommand`。
    @discardableResult
    private func postCommandC() -> Bool {
        accessibility.refresh()
        guard accessibility.isTrusted else { return false }

        let keyCodeC: CGKeyCode = 8 // kVK_ANSI_C
        let stateIDs: [CGEventSourceStateID] = [.hidSystemState, .combinedSessionState]

        for stateID in stateIDs {
            guard let source = CGEventSource(stateID: stateID) else { continue }
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeC, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeC, keyDown: false)
            else {
                continue
            }
            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            return true
        }
        return false
    }

    private func beginTranslate(text: String, anchor: CGPoint, commitAutoDedupeOnSuccess: Bool) {
        lastSourceText = text
        lastAnchor = anchor
        currentTask?.cancel()
        status = .translating

        overlay.show(.loading(sourceText: text), near: anchor)

        let timeoutNs = UInt64(translateTimeoutSeconds * 1_000_000_000)
        let dedupeKey = pendingAutoDedupeKey
        currentTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.currentTask = nil
                self.refreshStatus()
            }

            let work = Task { @MainActor in
                try await self.translateService.translateENToZH(text)
            }
            let watchdog = Task { @MainActor in
                try await Task.sleep(nanoseconds: timeoutNs)
                work.cancel()
            }

            do {
                let result = try await work.value
                watchdog.cancel()
                guard !Task.isCancelled else { return }
                // 仅成功后写入去重键；失败允许同一词再试
                if commitAutoDedupeOnSuccess, let dedupeKey {
                    self.lastAutoTranslatedText = dedupeKey
                }
                self.pendingAutoDedupeKey = nil
                // 强制中文 gloss，禁止空 senses / 英译英进入 success 态
                let display = result.ensuringChineseGlosses()
                self.publishEngineNote(from: display, primaryError: nil)
                self.recordWordbookIfNeeded(display)
                self.overlay.show(.success(display), near: anchor)
            } catch is CancellationError {
                // 真超时 / 取消：尽量 Mock 成功 + tip「网络超时」，避免空白失败页
                watchdog.cancel()
                if Task.isCancelled { return }
                self.pendingAutoDedupeKey = nil
                self.presentMockSuccess(
                    text: text,
                    anchor: anchor,
                    tip: PlaceholderStrings.overlayMockTipTimeout,
                    commitAutoDedupeOnSuccess: commitAutoDedupeOnSuccess,
                    dedupeKey: dedupeKey
                )
            } catch let err as TranslateError {
                watchdog.cancel()
                guard !Task.isCancelled else { return }
                self.pendingAutoDedupeKey = nil
                if case .emptyInput = err {
                    self.publishFailureEngineNote(err.userMessage)
                    self.overlay.update(
                        .failure(
                            message: err.userMessage,
                            retryText: text,
                            showOpenAccessibility: false
                        )
                    )
                } else {
                    // 链仍 throw（罕见）：再试 Mock 成功态，而非只亮 failure
                    self.presentMockSuccess(
                        text: text,
                        anchor: anchor,
                        tip: FallbackTranslateService.shortTip(err),
                        commitAutoDedupeOnSuccess: commitAutoDedupeOnSuccess,
                        dedupeKey: dedupeKey
                    )
                }
            } catch {
                watchdog.cancel()
                guard !Task.isCancelled else { return }
                self.pendingAutoDedupeKey = nil
                self.presentMockSuccess(
                    text: text,
                    anchor: anchor,
                    tip: PlaceholderStrings.overlayMockTipNetwork,
                    commitAutoDedupeOnSuccess: commitAutoDedupeOnSuccess,
                    dedupeKey: dedupeKey
                )
            }
        }
    }


    /// 译成功默认收录（含 mock）；设置可关。去重同 source。
    private func recordWordbookIfNeeded(_ result: TranslationResult) {
        guard preferences.autoSaveToWordbook else { return }
        let gloss = result.ensuringChineseGlosses().senses.first?.gloss
            ?? result.senses.first?.gloss
            ?? ""
        guard !gloss.isEmpty else { return }
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let appName: String?
        if let remembered = previousFrontmostApp, !remembered.isTerminated,
           remembered.processIdentifier != selfPID {
            appName = remembered.localizedName
        } else if let front = NSWorkspace.shared.frontmostApplication,
                  front.processIdentifier != selfPID {
            appName = front.localizedName
        } else {
            appName = nil
        }
        wordbookStore.upsert(source: result.sourceText, gloss: gloss, sourceApp: appName)
    }


    /// 额外兜底：用 Mock 产出成功态（超时 / 链抛错时避免空白失败页）
    private func presentMockSuccess(
        text: String,
        anchor: CGPoint,
        tip: String,
        commitAutoDedupeOnSuccess: Bool,
        dedupeKey: String?
    ) {
        let display = MockTranslateService.guaranteedChinese(for: text, tip: tip)
        if commitAutoDedupeOnSuccess, let dedupeKey {
            lastAutoTranslatedText = dedupeKey
        }
        publishEngineNote(from: display, primaryError: tip)
        recordWordbookIfNeeded(display)
        overlay.show(.success(display), near: anchor)
    }

    private func publishEngineNote(from result: TranslationResult, primaryError: String?) {
        let fallbackErr = extractFallbackPrimaryError()
        switch result.sourceEngine {
        case .myMemory:
            lastEngineNote = PlaceholderStrings.settingsEngineLastMyMemory
            lastErrorNote = nil
        case .google:
            lastEngineNote = PlaceholderStrings.settingsEngineLastGoogle
            lastErrorNote = nil
        case .lingva:
            lastEngineNote = PlaceholderStrings.settingsEngineLastLingva
            lastErrorNote = fallbackErr ?? primaryError
        case .mock:
            lastEngineNote = PlaceholderStrings.settingsEngineLastMockFallback
            lastErrorNote = fallbackErr ?? result.fallbackErrorTip ?? primaryError
        case .remote:
            lastEngineNote = PlaceholderStrings.settingsEngineLastRemote
            lastErrorNote = nil
        case .none:
            lastEngineNote = translateService.statusLine
            lastErrorNote = fallbackErr ?? primaryError
        }
    }

    private func extractFallbackPrimaryError() -> String? {
        if let fb = translateService as? FallbackTranslateService {
            return fb.lastPrimaryErrorDescription
        }
        if let caching = translateService as? CachingTranslateService {
            return caching.fallbackService?.lastPrimaryErrorDescription
        }
        return nil
    }

    private func publishFailureEngineNote(_ message: String) {
        lastErrorNote = message
        // Entire chain failed (rare — Mock usually succeeds)
        lastEngineNote = translateService.engineDisplayName
    }

}
