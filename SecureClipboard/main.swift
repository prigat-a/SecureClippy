import AppKit
import Carbon.HIToolbox

/// Menu bar app: no window, no Dock icon. Plain AppKit (no SwiftUI) keeps
/// memory use and launch time down.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let clipboardManager = ClipboardManager()
    private let authManager = AuthenticationManager()
    private var statusMenu: StatusMenuController?
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusMenu = StatusMenuController(clipboard: clipboardManager, auth: authManager)
        self.statusMenu = statusMenu

        hotKey = HotKey(keyCode: kVK_ANSI_V, modifiers: cmdKey | shiftKey) { [weak statusMenu] in
            statusMenu?.popUpAtMouse()
        }
        if hotKey == nil {
            NSLog("Secure Clipboard: ⌘⇧V is already used by another app")
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Also set by LSUIElement in Info.plist; repeated here for `swift run`.
app.setActivationPolicy(.accessory)
app.run()
