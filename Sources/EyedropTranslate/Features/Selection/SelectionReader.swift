import ApplicationServices
import AppKit
import CoreGraphics
import Foundation

// MARK: - Result types

/// 选区读取失败分类（对用户可见；禁止静默失败）
enum SelectionFailureKind: Equatable {
    case noSelection
    case noPermission
    case unsupported
    case other

    var userMessage: String {
        switch self {
        case .noSelection: return PlaceholderStrings.failNoSelection
        case .noPermission: return PlaceholderStrings.failNoPermission
        case .unsupported: return PlaceholderStrings.failUnsupported
        case .other: return PlaceholderStrings.failOther
        }
    }
}

/// 一次成功的选区快照
struct SelectionSnapshot: Equatable {
    let text: String
    /// 屏幕坐标系（AppKit，左下原点）下的选区包围框（若可得）
    let anchorRect: CGRect?

    var anchorPoint: CGPoint {
        if let anchorRect, !anchorRect.isNull, anchorRect.width > 0 || anchorRect.height > 0 {
            return CGPoint(x: anchorRect.midX, y: anchorRect.midY)
        }
        return NSEvent.mouseLocation
    }
}

enum SelectionReadResult: Equatable {
    case success(SelectionSnapshot)
    case failure(SelectionFailureKind)
}

@MainActor
protocol SelectionReading: AnyObject {
    func readCurrentSelection() -> SelectionReadResult
}

// MARK: - AX attribute names (string forms — reliable when Swift CFString constants differ by SDK)

private enum AXAttr {
    static let focusedApplication = "AXFocusedApplication"
    static let focusedUIElement = "AXFocusedUIElement"
    static let selectedText = "AXSelectedText"
    static let selectedTextRange = "AXSelectedTextRange"
    static let boundsForRange = "AXBoundsForRange"
    static let frame = "AXFrame"
}

// MARK: - Implementation

/// 通过 Accessibility API 读取当前选区（`AXSelectedText` / 焦点元素）。
///
/// **0.3.0 主路径**：`autoTranslateAfterSelection` 在鼠标松开后调用（焦点仍在源 App）。
/// **兜底**：菜单「翻译选区」；菜单打开时预读以防焦点丢失。
/// **不做 L2 吸管。**
@MainActor
final class SelectionReader: SelectionReading {
    private let accessibility: AccessibilityPermission
    private let selfPID = ProcessInfo.processInfo.processIdentifier

    init(accessibility: AccessibilityPermission) {
        self.accessibility = accessibility
    }

    func readCurrentSelection() -> SelectionReadResult {
        accessibility.refresh()
        guard accessibility.isTrusted else {
            return .failure(.noPermission)
        }

        if let fromFocused = readFromFocusedElement() {
            return fromFocused
        }

        if let fromFrontmost = readFromFrontmostApplication() {
            return fromFrontmost
        }

        return .failure(.noSelection)
    }

    // MARK: Private

    private func readFromFocusedElement() -> SelectionReadResult? {
        let systemWide = AXUIElementCreateSystemWide()
        guard let focusedApp = copyElement(systemWide, attribute: AXAttr.focusedApplication) else {
            return nil
        }
        // 菜单栏点击后焦点常落在本进程 —— 跳过自己，交给 frontmost 回退 / 预取
        if pid(of: focusedApp) == selfPID {
            return nil
        }
        guard let focusedUI = copyElement(focusedApp, attribute: AXAttr.focusedUIElement) else {
            return nil
        }
        let result = readSelection(from: focusedUI)
        // 成功或「明确无选区」直接返回；unsupported/other 允许再试 frontmost
        switch result {
        case .success, .failure(.noSelection), .failure(.noPermission):
            return result
        case .failure(.unsupported), .failure(.other):
            return nil
        }
    }

    private func readFromFrontmostApplication() -> SelectionReadResult? {
        var list: [NSRunningApplication] = []
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != selfPID {
            list.append(front)
        }
        for app in NSWorkspace.shared.runningApplications {
            guard app.processIdentifier != selfPID,
                  app.activationPolicy == .regular,
                  !app.isTerminated,
                  !list.contains(where: { $0.processIdentifier == app.processIdentifier })
            else { continue }
            list.append(app)
        }

        guard !list.isEmpty else { return .failure(.noSelection) }

        var lastFailure: SelectionFailureKind = .noSelection
        for app in list.prefix(4) {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            if let focused = copyElement(appElement, attribute: AXAttr.focusedUIElement) {
                let result = readSelection(from: focused)
                if case .success = result { return result }
                if case .failure(let kind) = result {
                    lastFailure = kind
                    if kind == .noSelection || kind == .unsupported { continue }
                }
            }
        }
        return .failure(lastFailure)
    }

    private func readSelection(from element: AXUIElement) -> SelectionReadResult {
        var textValue: CFTypeRef?
        let textErr = AXUIElementCopyAttributeValue(
            element,
            AXAttr.selectedText as CFString,
            &textValue
        )

        if textErr == .success {
            guard let bridged = textValue as? String else { return .failure(.other) }
            let trimmed = bridged.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return .failure(.noSelection)
            }
            let rect = resolveAnchorRect(for: element)
            return .success(SelectionSnapshot(text: trimmed, anchorRect: rect))
        }
        if textErr == .attributeUnsupported {
            return .failure(.unsupported)
        }
        if textErr == .noValue || textErr == .invalidUIElement {
            return .failure(.noSelection)
        }
        if textErr == .cannotComplete || textErr == .apiDisabled || textErr == .notImplemented {
            return accessibility.isTrusted ? .failure(.other) : .failure(.noPermission)
        }
        return .failure(.other)
    }

    private func resolveAnchorRect(for element: AXUIElement) -> CGRect? {
        if let rangeRect = selectedTextBounds(for: element) {
            return convertAXRectToCocoa(rangeRect)
        }
        if let frame = copyRect(element, attribute: AXAttr.frame) {
            return convertAXRectToCocoa(frame)
        }
        return nil
    }

    private func selectedTextBounds(for element: AXUIElement) -> CGRect? {
        var rangeValue: CFTypeRef?
        let rangeErr = AXUIElementCopyAttributeValue(
            element,
            AXAttr.selectedTextRange as CFString,
            &rangeValue
        )
        guard rangeErr == .success, let rangeValue else { return nil }

        var boundsValue: CFTypeRef?
        let boundsErr = AXUIElementCopyParameterizedAttributeValue(
            element,
            AXAttr.boundsForRange as CFString,
            rangeValue,
            &boundsValue
        )
        guard boundsErr == .success else { return nil }
        return axValueToRect(boundsValue)
    }

    private func pid(of element: AXUIElement) -> pid_t {
        var value: pid_t = 0
        AXUIElementGetPid(element, &value)
        return value
    }

    private func copyElement(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard err == .success, let value else { return nil }
        return (value as! AXUIElement)
    }

    private func copyRect(_ element: AXUIElement, attribute: String) -> CGRect? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard err == .success else { return nil }
        return axValueToRect(value)
    }

    private func axValueToRect(_ value: CFTypeRef?) -> CGRect? {
        guard let value else { return nil }
        let axVal = unsafeBitCast(value, to: AXValue.self)
        var rect = CGRect.zero
        guard AXValueGetValue(axVal, .cgRect, &rect) else { return nil }
        return rect
    }

    /// AX 全局坐标（左上原点）→ AppKit 屏幕坐标（左下原点）。
    private func convertAXRectToCocoa(_ axRect: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.maxY
            ?? NSScreen.main?.frame.height
            ?? axRect.height
        let y = primaryHeight - axRect.origin.y - axRect.height
        return CGRect(x: axRect.origin.x, y: y, width: axRect.width, height: axRect.height)
    }
}
