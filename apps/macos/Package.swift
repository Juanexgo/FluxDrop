// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "FluxDrop", defaultLocalization: "en", platforms: [.macOS(.v14)],
    products: [.executable(name: "FluxDrop", targets: ["FluxDrop"]), .library(name: "FluxCore", targets: ["FluxCore"])],
    dependencies: [.package(url: "https://github.com/jpsim/Yams.git", exact: "6.2.2")],
    targets: [
        .target(name: "FluxCore", dependencies: ["Yams", "CArchive", "CWebP"]),
        .systemLibrary(name: "CArchive"),
        .target(name: "CWebP", path: "Vendor/WebP", exclude: ["COPYING","PATENTS","AUTHORS","UPSTREAM.json"], sources: ["src/dec","src/dsp","src/enc","src/utils","sharpyuv"], publicHeadersPath: "include", cSettings: [.headerSearchPath("."), .define("WEBP_USE_THREAD")]),
        .executableTarget(name: "FluxDrop", dependencies: ["FluxCore"], resources: [.process("Resources")]),
        .testTarget(name: "FluxCoreTests", dependencies: ["FluxCore"])
    ], swiftLanguageModes: [.v6]
)
