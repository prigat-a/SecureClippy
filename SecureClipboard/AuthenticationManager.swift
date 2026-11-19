import AppKit
import LocalAuthentication

final class AuthenticationManager {
    /// Choices for the "Lock After" menu. `nil` means only when the Mac locks or sleeps.
    static let lockOptions: [(title: String, seconds: TimeInterval?)] = [
        ("Immediately", 0),
        ("1 Minute", 60),
        ("5 Minutes", 5 * 60),
        ("15 Minutes", 15 * 60),
        ("1 Hour", 60 * 60),
        ("Only When the Mac Locks or Sleeps", nil),
    ]
    private static let lockTimeoutKey = "lockTimeout"
    private static let defaultLockTimeout: TimeInterval = 5 * 60

    private(set) var isAuthenticated = false
    private var isAuthenticating = false
    private var lastUsed = Date()
    private var observers: [NSObjectProtocol] = []

    /// Idle time before Touch ID is needed again: 0 = every time, nil = never
    /// (still locks with the screen and on sleep). Saved between launches.
    var lockTimeout: TimeInterval? {
        get {
            guard let stored = UserDefaults.standard.object(forKey: Self.lockTimeoutKey) as? Double else {
                return Self.defaultLockTimeout
            }
            return stored < 0 ? nil : stored
        }
        set {
            UserDefaults.standard.set(newValue ?? -1, forKey: Self.lockTimeoutKey)
        }
    }

    /// Call whenever the history is used, to restart the idle countdown.
    func noteActivity() {
        lastUsed = Date()
    }

    /// Locks if the history has been idle for longer than `lockTimeout`.
    /// Checked whenever the menu is about to open, so no timer has to run.
    func lockIfIdle() {
        guard isAuthenticated, let timeout = lockTimeout, timeout > 0 else { return }
        if Date().timeIntervalSince(lastUsed) >= timeout { logout() }
    }

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
                if success { self.lastUsed = Date() }
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
