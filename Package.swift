// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "HaloCore", platforms: [.macOS(.v13)], products: [.library(name: "HaloCore", targets: ["HaloCore"])], targets: [.target(name: "HaloCore", path: "Halo/Core", exclude: ["AppStore.swift", "WorkspaceStore.swift"], sources: ["Models.swift", "WorkspaceModels.swift", "ExtensionContracts.swift"]), .testTarget(name: "HaloCoreTests", dependencies: ["HaloCore"], path: "Tests")])
