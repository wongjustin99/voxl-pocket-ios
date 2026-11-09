// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AccessCredentials",
    products: [.library(name: "AccessCredentials", targets: ["AccessCredentials"])],
    dependencies: [.package(url: "https://github.com/jedisct1/swift-sodium", exact: "0.11.0")],
    targets: [
        .target(name: "AccessCredentials", dependencies: [.product(name: "Sodium", package: "swift-sodium")], path: "Sources/CloudflareAccess"),
        .target(name: "PointerInput", path: "Sources/PointerInput"),
        .testTarget(name: "PointerInputTests", dependencies: ["PointerInput"], path: "GestureTests"),
        .testTarget(name: "AccessCredentialsTests", dependencies: ["AccessCredentials"], path: "Tests"),
    ]
)
