import AppKit
import SwiftUI

/// 划词本窗口：菜单「划词本…」或悬浮球单击打开
@MainActor
final class WordbookWindowController {
    private var window: NSWindow?
    private let store: WordbookStore

    init(store: WordbookStore) {
        self.store = store
    }

    func show() {
        if let window {
            if let hosting = window.contentViewController as? NSHostingController<WordbookView> {
                hosting.rootView = WordbookView(store: store)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: WordbookView(store: store))
        let window = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0,
                width: Constants.Wordbook.windowWidth,
                height: Constants.Wordbook.windowHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = PlaceholderStrings.wordbookTitle
        window.contentViewController = hosting
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
