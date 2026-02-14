// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HotkeyCanvas",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "HotkeyCanvasApp", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.58.0")
    ],
    targets: [
        .target(
            name: "Domain"
        ),
        .target(
            name: "Application",
            dependencies: ["Domain"]
        ),
        .target(
            name: "Infrastructure"
        ),
        .target(
            name: "InterfaceAdapters",
            dependencies: ["Application", "Domain"]
        ),
        .executableTarget(
            name: "App",
            dependencies: ["Application", "Domain", "InterfaceAdapters", "Infrastructure"]
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"]
        ),
        .testTarget(
            name: "ApplicationTests",
            dependencies: ["Application", "Domain"]
        ),
        .testTarget(
            name: "InterfaceAdaptersTests",
            dependencies: ["InterfaceAdapters", "Domain"]
        ),
    ]
)
