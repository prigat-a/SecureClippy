import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import SwiftUI

/// The ⌘⇧V popup: a floating panel that lists the history and pastes the
/// chosen entry into whatever app was in front.
///
/// The panel is non-activating, so the app you were typing in stays the
/// frontmost app and receives the paste.
final class QuickPasteController {
    private let clipboard: ClipboardManager
    private let auth: AuthenticationManager
    private let model = QuickPasteModel()
    private var panel: QuickPastePanel?
    private var cancellables = Set<AnyCancellable>()
    private var askedForAccessibility = false

    init(clipboard: ClipboardManager, auth: AuthenticationManager) {
        self.clipboard = clipboard
        self.auth = auth

        auth.$isAuthenticated.dropFirst().sink { [weak self] unlocked in
            guard let panel = self?.panel, panel.isVisible else { return }
            // Take keyboard focus back after the Touch ID prompt, or close on lock.
            if unlocked { panel.makeKeyAndOrderFront(nil) } else { panel.close() }
        }.store(in: &cancellables)
    }

    func toggle() {
        if let panel, panel.isVisible {
            panel.close()
        } else {
            show()
        }
    }

    private func show() {
        model.selection = 0
        let panel = self.panel ?? makePanel()
        self.panel = panel
        positionNearMouse(panel)
        panel.makeKeyAndOrderFront(nil)
        if !auth.isAuthenticated { auth.authenticate() }
    }

    private func makePanel() -> QuickPastePanel {
        let panel = QuickPastePanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        [.closeButton, .miniaturizeButton, .zoomButton].forEach {
            panel.standardWindowButton($0)?.isHidden = true
        }

        panel.contentView = NSHostingView(rootView:
            QuickPasteView(model: model, onPick: { [weak self] in self?.paste(at: $0) })
                .environmentObject(clipboard)
                .environmentObject(auth)
        )
        panel.onKeyDown = { [weak self] in self?.handleKey($0) ?? false }
        panel.onResignKey = { [weak self, weak panel] in
            // Clicking elsewhere closes it, but not while the Touch ID prompt has focus.
            guard let self, !self.auth.isAuthenticating else { return }
            panel?.close()
        }
        return panel
    }

    private func positionNearMouse(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height - 8)
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        panel.setFrameOrigin(origin)
    }

    // MARK: - Keyboard

    private func handleKey(_ event: NSEvent) -> Bool {
        let count = clipboard.clipboardItems.count
        switch Int(event.keyCode) {
        case kVK_Escape:
            panel?.close()
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if auth.isAuthenticated { paste(at: model.selection) } else { auth.authenticate() }
        case kVK_DownArrow:
            model.selection = min(model.selection + 1, max(count - 1, 0))
        case kVK_UpArrow:
            model.selection = max(model.selection - 1, 0)
        default:
            guard let digit = event.charactersIgnoringModifiers.flatMap(Int.init),
                  (1...9).contains(digit) else { return false }
            paste(at: digit - 1)
        }
        return true
    }

    // MARK: - Pasting

    private func paste(at index: Int) {
        guard auth.isAuthenticated, clipboard.clipboardItems.indices.contains(index) else { return }
        clipboard.copyToClipboard(clipboard.clipboardItems[index])
        panel?.close()

        // Sending ⌘V to another app needs Accessibility permission. Without it
        // the entry is still on the clipboard and a manual ⌘V pastes it.
        guard AXIsProcessTrusted() else {
            requestAccessibilityOnce()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { Self.sendCommandV() }
    }

    private func requestAccessibilityOnce() {
        guard !askedForAccessibility else { return }
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

final class QuickPasteModel: ObservableObject {
    @Published var selection = 0
}

final class QuickPastePanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?
    var onResignKey: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true { super.keyDown(with: event) }
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

struct QuickPasteView: View {
    @ObservedObject var model: QuickPasteModel
    @EnvironmentObject var clipboard: ClipboardManager
    @EnvironmentObject var auth: AuthenticationManager
    let onPick: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if auth.isAuthenticated {
                history
            } else {
                locked
            }
        }
        .frame(width: 380, height: 420)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var history: some View {
        let items = clipboard.clipboardItems
        if items.isEmpty {
            Text("Nothing copied yet")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            row(index: index, item: item)
                                .id(item.id)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 28) // room for the transparent title bar
                    .padding(.bottom, 6)
                }
                .onChange(of: model.selection) { selection in
                    if items.indices.contains(selection) { proxy.scrollTo(items[selection].id) }
                }
            }
        }
        Divider()
        Text("↩ paste   ↑↓ select   1–9 quick paste   esc close")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(8)
    }

    private func row(index: Int, item: ClipboardItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(index < 9 ? "\(index + 1)" : " ")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 14)
            Text(clipboard.content(of: item) ?? "⚠︎ Unable to decrypt")
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(index == model.selection ? Color.accentColor.opacity(0.25) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { if $0 { model.selection = index } }
        .onTapGesture { onPick(index) }
    }

    private var locked: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)
            Text("History is locked")
                .font(.headline)
            Button(action: auth.authenticate) {
                Label("Unlock", systemImage: "touchid")
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
