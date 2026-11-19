import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                historyView
            } else {
                AuthenticationView()
            }
        }
        .frame(minWidth: 360, minHeight: 420)
    }

    private var historyView: some View {
        Group {
            if clipboardManager.clipboardItems.isEmpty {
                VStack(spacing: 6) {
                    Text("Nothing copied yet")
                    Text("Press ⌘⇧V in any app to paste from your history")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(clipboardManager.clipboardItems) { item in
                    ClipboardItemView(item: item)
                }
            }
        }
        .navigationTitle("Secure Clipboard")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: clipboardManager.removeAll) {
                    Image(systemName: "trash")
                }
                .help("Clear history")
                .disabled(clipboardManager.clipboardItems.isEmpty)

                Button(action: authManager.logout) {
                    Image(systemName: "lock.fill")
                }
                .help("Lock")
            }
        }
    }
}

struct ClipboardItemView: View {
    let item: ClipboardItem
    @EnvironmentObject var clipboardManager: ClipboardManager
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(clipboardManager.content(of: item) ?? "⚠︎ Unable to decrypt")
                .lineLimit(3)
                .font(.body)

            HStack {
                Text(item.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { clipboardManager.copyToClipboard(item) }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy")
                .opacity(isHovered ? 1 : 0.6)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(action: { clipboardManager.copyToClipboard(item) }) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button(role: .destructive, action: { clipboardManager.removeItem(item) }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Secure Clipboard")
                .font(.title)
                .bold()

            Text("Authenticate to access your clipboard history")
                .foregroundColor(.secondary)

            Button(action: authManager.authenticate) {
                Label("Unlock", systemImage: "touchid")
                    .font(.headline)
                    .frame(width: 180)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .alert("Authentication Error", isPresented: Binding(
            get: { authManager.errorMessage != nil },
            set: { if !$0 { authManager.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authManager.errorMessage ?? "")
        }
    }
}
