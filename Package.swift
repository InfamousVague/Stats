// swift-tools-version: 5.9
import PackageDescription

// Stats: three SPM products —
//
//   • `StatsPane` (.dynamic) — system monitor as a dynamic library
//     loaded at runtime by the MattsSoftware launcher.
//   • `Stats` (.executable) — thin standalone shim that hosts the
//     pane in its own NSStatusItem + NSPopover.
//   • `StatsShared` (.library, .static) — App Group id + the
//     `SharedStats` snapshot model + `StatsStore` read/write helper.
//     Consumed by `StatsPane`, `Stats`, AND the Xcode widget target
//     at `Widget/StatsWidgets.xcodeproj`. SwiftPM can't build the
//     widget extension itself (SR-14944: no app-extension
//     productType), but it can share data models cleanly via a
//     local-package dependency from the xcodeproj.
let package = Package(
    name: "Stats",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Stats", targets: ["Stats"]),
        .library(name: "StatsPane", type: .dynamic,
                 targets: ["StatsPane"]),
        .library(name: "StatsShared", targets: ["StatsShared"])
    ],
    dependencies: [ .package(path: "../suitekit-swift") ],
    targets: [
        .target(
            name: "StatsShared",
            path: "Sources/StatsShared"
        ),
        .target(
            name: "StatsPane",
            dependencies: [
                "StatsShared",
                .product(name: "SuiteKit", package: "suitekit-swift")
            ],
            path: "Sources/StatsPane"
        ),
        .executableTarget(
            name: "Stats",
            dependencies: [
                "StatsPane",
                "StatsShared",
                .product(name: "SuiteKit", package: "suitekit-swift")
            ],
            path: "Sources/Stats"
        )
    ]
)
