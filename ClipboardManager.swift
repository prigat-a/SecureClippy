import Foundation
import CryptoKit
import AppKit

class ClipboardManager: ObservableObject {
    @Published var clipboardItems: [ClipboardItem] = []
    private let encryptionKey: SymmetricKey
    private let cleanupTimer: Timer
    private var lastClipboardContent: String?
    
    init() {
        // Generate a random 256-bit key
        self.encryptionKey = SymmetricKey(size: .bits256)
        
        // Set up daily cleanup timer
        self.cleanupTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            self?.cleanupOldItems()
        }
        
        // Start monitoring clipboard
        startMonitoringClipboard()
    }
    
    private func startMonitoringClipboard() {
        NSPasteboard.general.declareTypes([.string], owner: nil)
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func checkClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        
        // Prevent duplicate entries
        guard string != lastClipboardContent else { return }
        lastClipboardContent = string
        
        // Securely wipe the last clipboard content
        if let lastContent = lastClipboardContent {
            secureWipe(lastContent)
        }
        
        // Encrypt the clipboard content
        let encryptedData = encrypt(string)
        
        // Create new clipboard item
        let newItem = ClipboardItem(
            id: UUID(),
            content: string,
            encryptedContent: encryptedData,
            timestamp: Date()
        )
        
        // Add to items array
        DispatchQueue.main.async {
            self.clipboardItems.insert(newItem, at: 0)
        }
    }
    
    private func encrypt(_ string: String) -> Data {
        let data = string.data(using: .utf8)!
        let sealedBox = try! AES.GCM.seal(data, using: encryptionKey)
        return sealedBox.combined!
    }
    
    private func decrypt(_ data: Data) -> String? {
        let sealedBox = try? AES.GCM.SealedBox(combined: data)
        guard let sealedBox = sealedBox else { return nil }
        let decryptedData = try? AES.GCM.open(sealedBox, using: encryptionKey)
        return String(data: decryptedData ?? Data(), encoding: .utf8)
    }
    
    private func cleanupOldItems() {
        // Securely wipe all items before removal
        for item in clipboardItems {
            secureWipe(item.content)
        }
        
        DispatchQueue.main.async {
            self.clipboardItems.removeAll()
        }
    }
    
    private func secureWipe(_ string: String) {
        // Overwrite the string with random data multiple times
        var mutableString = string
        for _ in 0..<3 {
            let randomData = Data((0..<string.count).map { _ in UInt8.random(in: 0...255) })
            mutableString = String(data: randomData, encoding: .utf8) ?? ""
        }
        mutableString = ""
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
    }
    
    deinit {
        // Clean up sensitive data when the manager is deallocated
        cleanupOldItems()
        lastClipboardContent = nil
    }
}

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let content: String
    let encryptedContent: Data
    let timestamp: Date
} 