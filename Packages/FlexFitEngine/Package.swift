// swift-tools-version: 6.0
// The adaptation engine: plan generation, swaps, pivots, targets.
// Pure Swift, no UI and no Apple-only frameworks, so it can be ported to Android later.
import PackageDescription

let package = Package(
    name: "FlexFitEngine",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "FlexFitEngine", targets: ["FlexFitEngine"]),
    ],
    targets: [
        .target(name: "FlexFitEngine", resources: [.copy("Resources/exercises.json")]),
        .testTarget(name: "FlexFitEngineTests", dependencies: ["FlexFitEngine"]),
    ]
)
