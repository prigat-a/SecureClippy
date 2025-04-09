import SwiftUI
import LocalAuthentication

@main
struct SecureClipboardApp: App {
    @StateObject private var clipboardManager = ClipboardManager()
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(clipboardManager)
                .environmentObject(authManager)
        }
    }
} 