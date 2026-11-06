// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Productimer",
    platforms: [.macOS("26.0")],
    targets: [
        // Rules and data logic with no SwiftUI, so tests run without the app.
        .target(name: "ProductimerKit"),
        .executableTarget(
            name: "Productimer",
            dependencies: ["ProductimerKit"],
            // App code runs on the main thread unless you say otherwise.
            swiftSettings: [.unsafeFlags(["-default-isolation", "MainActor"])]
        ),
        .testTarget(name: "ProductimerKitTests", dependencies: ["ProductimerKit"]),
    ]
)
