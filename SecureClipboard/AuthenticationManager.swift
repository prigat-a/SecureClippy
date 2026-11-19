import AppKit
import LocalAuthentication

final class AuthenticationManager: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isAuthenticating = false
    @Published var errorMessage: String?

    private var observers: [NSObjectProtocol] = []

    init() {
        // Lock whenever the screen locks or the Mac goes to sleep, whether or
        // not the main window is open.
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in self?.logout() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.logout() })
    }

    deinit {
        observers.forEach {
            DistributedNotificationCenter.default().removeObserver($0)
            NSWorkspace.shared.notificationCenter.removeObserver($0)
        }
    }

    /// Uses Touch ID when available and falls back to the account password.
    /// Retry limits and lockout are enforced by the system, which (unlike an
    /// in-app counter) survive restarting the app.
    func authenticate() {
        guard !isAuthenticating, !isAuthenticated else { return }
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            errorMessage = error?.localizedDescription ?? "Authentication isn't available on this Mac."
            return
        }

        isAuthenticating = true
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "access your clipboard history") { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isAuthenticating = false
                if success {
                    self.isAuthenticated = true
                    self.errorMessage = nil
                } else if let laError = error as? LAError,
                          [.userCancel, .appCancel, .systemCancel].contains(laError.code) {
                    // Dismissed by the user or system; not worth an alert.
                } else {
                    self.errorMessage = error?.localizedDescription ?? "Authentication failed."
                }
            }
        }
    }

    func logout() {
        isAuthenticated = false
    }
}
