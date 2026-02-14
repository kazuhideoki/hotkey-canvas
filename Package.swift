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
            name: "Domain",
            path: "Domain"
        ),
        .target(
            name: "Application",
            dependencies: ["Domain"],
            path: "Application"
        ),
        .target(
            name: "Infrastructure",
            path: "Infrastructure"
        ),
        .target(
            name: "InterfaceAdapters",
            dependencies: ["Application", "Domain"],
            path: "InterfaceAdapters"
        ),
        .executableTarget(
            name: "App",
            dependencies: ["Application", "Domain", "InterfaceAdapters", "Infrastructure"],
            path: "App"
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"],
            path: "Tests/DomainTests"
        ),
        .testTarget(
            name: "ApplicationTests",
            dependencies: ["Application", "Domain"],
            path: "Tests/ApplicationTests"
        ),
    ]
)
