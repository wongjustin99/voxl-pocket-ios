// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AccessCredentials",
    products: [.library(name: "AccessCredentials", targets: ["AccessCredentials"])],
    targets: [
        .target(name: "AccessCredentials", path: "Sources/CloudflareAccess"),
        .target(name: "PointerInput", path: "Sources/PointerInput"),
        .testTarget(name: "PointerInputTests", dependencies: ["PointerInput"], path: "GestureTests"),
        .testTarget(name: "AccessCredentialsTests", dependencies: ["AccessCredentials"], path: "Tests"),
    ]
)
