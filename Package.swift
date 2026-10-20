// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XcodeSizeCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "XcodeSizeCore", targets: ["XcodeSizeCore"])],
    targets: [
        .target(name: "XcodeSizeCore", path: "XcodeSize/XcodeSize/Core", resources: [.process("Resources")]),
        .testTarget(name: "XcodeSizeCoreTests", dependencies: ["XcodeSizeCore"], path: "Tests")
    ]
)
