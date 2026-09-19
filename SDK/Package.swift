// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HaloCISDK",
    platforms: [.macOS(.v13)],
    products: [.library(name: "HaloCISDK", targets: ["HaloCISDK"])],
    targets: [
        .target(name: "HaloCISDK"),
        .testTarget(name: "HaloCISDKTests", dependencies: ["HaloCISDK"])
    ]
)
