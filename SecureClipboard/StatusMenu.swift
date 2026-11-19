import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// The menu bar icon and its dropdown. The same menu also pops up at the
/// mouse pointer when you press ⌘⇧V.
///
/// The menu is rebuilt each time it opens, so history is only decrypted while
/// you're looking at it. Choosing an entry copies it and pastes it into the app
/// you were using (menus don't take focus away from that app).
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let clipboard: ClipboardManager
    private let auth: AuthenticationManager
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private var askedForAccessibility = false

    /// Entries shown directly in the menu; older ones go into submenus of this size.
    private let pageSize = 10
    private let maxTitleLength = 60

    init(clipboard: ClipboardManager, auth: AuthenticationManager) {
        self.clipboard = clipboard
        self.auth = auth
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Secure Clipboard")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Secure Clipboard (⌘⇧V)"
        }
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    /// ⌘⇧V: unlock first if needed, then show the menu at the pointer.
    func popUpAtMouse() {
        guard auth.isAuthenticated else {
            auth.authenticate { [weak self] unlocked in
                if unlocked { self?.popUpAtMouse() }
            }
            return
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: - Building the menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if auth.isAuthenticated {
            addHistory(to: menu)
            menu.addItem(.separator())
            menu.addItem(item("Clear History", action: #selector(clearHistory),
                              enabled: !clipboard.clipboardItems.isEmpty))
            menu.addItem(item("Lock", action: #selector(lock)))
        } else {
            let count = clipboard.clipboardItems.count
            menu.addItem(item("Unlock History…", action: #selector(unlock)))
            menu.addItem(info(count == 1 ? "1 item, locked" : "\(count) items, locked"))
        }

        menu.addItem(.separator())
        if !AXIsProcessTrusted() {
            menu.addItem(item("Allow Pasting into Apps…", action: #selector(openAccessibilitySettings)))
        }
        menu.addItem(info("Open this menu anywhere with ⌘⇧V"))
        menu.addItem(item("Quit Secure Clipboard", action: #selector(quit), key: "q", modifiers: .command))
    }

    private func addHistory(to menu: NSMenu) {
        let items = clipboard.clipboardItems
        guard !items.isEmpty else {
            menu.addItem(info("Nothing copied yet"))
            return
        }

        menu.addItem(info("History"))
        for (index, entry) in items.prefix(pageSize).enumerated() {
            menu.addItem(historyItem(entry, index: index))
        }

        // Older entries in submenus of ten: "11 – 20", "21 – 30", ...
        var start = pageSize
        while start < items.count {
            let end = min(start + pageSize, items.count)
            let submenu = NSMenu()
            submenu.autoenablesItems = false
            for index in start..<end {
                submenu.addItem(historyItem(items[index], index: index))
            }
            let parent = NSMenuItem(title: "\(start + 1) – \(end)", action: nil, keyEquivalent: "")
            parent.submenu = submenu
            menu.addItem(parent)
            start = end
        }
    }

    private func historyItem(_ entry: ClipboardItem, index: Int) -> NSMenuItem {
        let text = clipboard.content(of: entry).map(preview) ?? "⚠︎ Unable to decrypt"
        // 1–9 then 0, like the number row; pressing it while the menu is open picks the entry.
        let key = index < 9 ? "\(index + 1)" : (index == 9 ? "0" : "")
        let menuItem = item(text, action: #selector(select(_:)), key: key, modifiers: [])
        menuItem.representedObject = entry.id
        return menuItem
    }

    /// One line, trimmed, at most `maxTitleLength` characters.
    private func preview(_ text: String) -> String {
        let oneLine = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ⏎ ")
        guard !oneLine.isEmpty else { return "(whitespace)" }
        return oneLine.count > maxTitleLength ? String(oneLine.prefix(maxTitleLength - 1)) + "…" : oneLine
    }

    private func item(_ title: String, action: Selector, key: String = "",
                      modifiers: NSEvent.ModifierFlags = [], enabled: Bool = true) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.keyEquivalentModifierMask = modifiers
        menuItem.target = self
        menuItem.isEnabled = enabled
        return menuItem
    }

    private func info(_ title: String) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItem.isEnabled = false
        return menuItem
    }

    // MARK: - Actions

    @objc private func select(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let entry = clipboard.clipboardItems.first(where: { $0.id == id }) else { return }
        clipboard.copyToClipboard(entry)

        // Sending ⌘V to another app needs Accessibility permission. Without it
        // the entry is still on the clipboard and a manual ⌘V pastes it.
        guard AXIsProcessTrusted() else {
            requestAccessibilityOnce()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { Self.sendCommandV() }
    }

    @objc private func unlock() {
        auth.authenticate { [weak self] unlocked in
            // Reopen the menu so the history is right there.
            if unlocked { self?.statusItem.button?.performClick(nil) }
        }
    }

    @objc private func lock() {
        auth.logout()
    }

    @objc private func clearHistory() {
        clipboard.removeAll()
    }

    @objc private func openAccessibilitySettings() {
        requestAccessibilityOnce(force: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Pasting

    private func requestAccessibilityOnce(force: Bool = false) {
        guard force || !askedForAccessibility else { return }
        askedForAccessibility = true
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: keyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }
}
