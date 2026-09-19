// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HaloCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "HaloCore", targets: ["HaloCore"]),
        .executable(name: "halo-ci", targets: ["HaloCI"])
    ],
    dependencies: [.package(path: "SDK")],
    targets: [
        .target(name: "HaloCore", path: "Halo/Core",
                exclude: ["AppStore.swift", "WorkspaceStore.swift"],
                sources: ["Models.swift", "WorkspaceModels.swift", "ExtensionContracts.swift",
                          "SurfaceModels.swift", "WidgetModels.swift", "PersonalizationModels.swift"]),
        .executableTarget(name: "HaloCI", dependencies: [.product(name: "HaloCISDK", package: "SDK")], path: "Tools/HaloCI"),
        .testTarget(name: "HaloCoreTests", dependencies: ["HaloCore", .product(name: "HaloCISDK", package: "SDK")], path: "Tests")
    ]
)
