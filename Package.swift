// swift-tools-version: 5.9
import PackageDescription

// Stats: `StatsPane` (system monitor as a dynamic library via
// SuiteKit, loadable by the launcher) + `Stats` (thin @main
// standalone shim, behaviour unchanged incl. the rasterised
// menu-bar widget).
let package = Package(
    name: "Stats",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Stats", targets: ["Stats"]),
        .library(name: "StatsPane", type: .dynamic, targets: ["StatsPane"])
    ],
    dependencies: [ .package(path: "../suitekit-swift") ],
    targets: [
        .target(
            name: "StatsPane",
            dependencies: [.product(name: "SuiteKit", package: "suitekit-swift")],
            path: "Sources/StatsPane"
        ),
        .executableTarget(
            name: "Stats",
            dependencies: ["StatsPane", .product(name: "SuiteKit", package: "suitekit-swift")],
            path: "Sources/Stats"
        )
    ]
)
