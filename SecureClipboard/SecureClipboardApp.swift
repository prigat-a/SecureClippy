import SwiftUI
import AppKit
import Carbon.HIToolbox

@main
struct SecureClipboardApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.clipboardManager)
                .environmentObject(appDelegate.authManager)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let clipboardManager = ClipboardManager()
    let authManager = AuthenticationManager()
    private var quickPaste: QuickPasteController?
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched via `swift run` (no app bundle) so the window
        // gets a Dock icon and comes to the front.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let quickPaste = QuickPasteController(clipboard: clipboardManager, auth: authManager)
        self.quickPaste = quickPaste
        hotKey = HotKey(keyCode: kVK_ANSI_V, modifiers: cmdKey | shiftKey) { [weak quickPaste] in
            quickPaste?.toggle()
        }
        if hotKey == nil {
            NSLog("Secure Clipboard: ⌘⇧V is already used by another app")
        }
    }

    /// Keep running (and recording) after the window is closed; ⌘⇧V still works.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
