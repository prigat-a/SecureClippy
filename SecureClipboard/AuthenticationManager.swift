import AppKit
import LocalAuthentication

final class AuthenticationManager {
    private(set) var isAuthenticated = false
    private var isAuthenticating = false
    private var observers: [NSObjectProtocol] = []

    init() {
        // Lock whenever the screen locks or the Mac goes to sleep.
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
    func authenticate(completion: ((Bool) -> Void)? = nil) {
        if isAuthenticated { completion?(true); return }
        guard !isAuthenticating else { return }

        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            showError(error?.localizedDescription ?? "Authentication isn't available on this Mac.")
            completion?(false)
            return
        }

        isAuthenticating = true
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "access your clipboard history") { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isAuthenticating = false
                self.isAuthenticated = success
                if !success, let error, !Self.isCancellation(error) {
                    self.showError(error.localizedDescription)
                }
                completion?(success)
            }
        }
    }

    func logout() {
        isAuthenticated = false
    }

    private static func isCancellation(_ error: Error) -> Bool {
        guard let laError = error as? LAError else { return false }
        return [.userCancel, .appCancel, .systemCancel].contains(laError.code)
    }

    private func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Couldn't unlock Secure Clipboard"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
