import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingSecurityAlert = false
    @State private var securityAlertMessage = ""
    
    var body: some View {
        if !authManager.isAuthenticated {
            AuthenticationView()
        } else {
            NavigationView {
                List(clipboardManager.clipboardItems) { item in
                    ClipboardItemView(item: item)
                }
                .navigationTitle("Secure Clipboard")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            secureLogout()
                        }) {
                            Image(systemName: "lock.fill")
                        }
                    }
                }
                .alert("Security Alert", isPresented: $showingSecurityAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(securityAlertMessage)
                }
            }
        }
    }
    
    private func secureLogout() {
        // Clear clipboard before logout
        NSPasteboard.general.clearContents()
        authManager.logout()
    }
}

struct ClipboardItemView: View {
    let item: ClipboardItem
    @EnvironmentObject var clipboardManager: ClipboardManager
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.content)
                .lineLimit(3)
                .font(.body)
                .contextMenu {
                    Button(action: {
                        clipboardManager.copyToClipboard(item)
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    
                    Button(role: .destructive, action: {
                        // Securely remove item
                        clipboardManager.removeItem(item)
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            
            HStack {
                Text(item.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    clipboardManager.copyToClipboard(item)
                }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .opacity(isHovered ? 1 : 0.6)
            }
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingError = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Secure Clipboard")
                .font(.title)
                .bold()
            
            Text("Authenticate to access your clipboard history")
                .foregroundColor(.secondary)
            
            Button(action: {
                authManager.authenticate()
            }) {
                Label("Authenticate", systemImage: "faceid")
                    .font(.headline)
                    .padding()
                    .frame(width: 200)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .alert("Authentication Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Too many failed attempts. Please try again later.")
        }
    }
} 