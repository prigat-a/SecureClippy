import Foundation
import LocalAuthentication
import CryptoKit

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    private var authenticationAttempts = 0
    private let maxAttempts = 5
    private var lastAttemptTime: Date?
    private let lockoutDuration: TimeInterval = 300 // 5 minutes
    private var isLockedOut = false
    
    func authenticate() {
        guard !isLockedOut else {
            handleLockout()
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to access your clipboard history"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, error in
                DispatchQueue.main.async {
                    self?.handleAuthenticationResult(success: success, error: error)
                }
            }
        } else {
            // Fallback to password authentication if Touch ID is not available
            authenticateWithPassword()
        }
    }
    
    private func handleAuthenticationResult(success: Bool, error: Error?) {
        if success {
            authenticationAttempts = 0
            isAuthenticated = true
            lastAttemptTime = nil
            isLockedOut = false
        } else {
            authenticationAttempts += 1
            lastAttemptTime = Date()
            
            if authenticationAttempts >= maxAttempts {
                isLockedOut = true
                handleLockout()
            }
        }
    }
    
    private func handleLockout() {
        guard let lastAttempt = lastAttemptTime else { return }
        
        let timeRemaining = lockoutDuration - Date().timeIntervalSince(lastAttempt)
        if timeRemaining <= 0 {
            isLockedOut = false
            authenticationAttempts = 0
            lastAttemptTime = nil
        }
    }
    
    private func authenticateWithPassword() {
        // Implement password authentication fallback with rate limiting
        // This would typically show a password prompt
    }
    
    func logout() {
        isAuthenticated = false
        authenticationAttempts = 0
        lastAttemptTime = nil
        isLockedOut = false
    }
} 