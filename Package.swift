// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XcodeFitCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "XcodeFitCore", targets: ["XcodeFitCore"])],
    targets: [
        .target(name: "XcodeFitCore", path: "XcodeFit/XcodeFit/Core", resources: [.process("Resources")]),
        .testTarget(name: "XcodeFitCoreTests", dependencies: ["XcodeFitCore"], path: "Tests")
    ]
)
