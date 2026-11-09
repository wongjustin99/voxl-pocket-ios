// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AccessCredentials",
    products: [.library(name: "AccessCredentials", targets: ["AccessCredentials"])],
    targets: [
        .target(name: "AccessCredentials", path: "Sources/CloudflareAccess"),
        .testTarget(name: "AccessCredentialsTests", dependencies: ["AccessCredentials"], path: "Tests"),
    ]
)
