// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SecureClipboard",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "SecureClipboard",
            path: "SecureClipboard",
            exclude: ["Info.plist"]
        )
    ]
)
