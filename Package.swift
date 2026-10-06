// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SelectionMath",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SelectionMath", targets: ["SelectionMath"])],
    targets: [
        .target(name: "MathCore"),
        .executableTarget(
            name: "SelectionMath", dependencies: ["MathCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "MathCoreTests", dependencies: ["MathCore"]),
        .testTarget(name: "SelectionMathTests", dependencies: ["SelectionMath"])
    ]
)
