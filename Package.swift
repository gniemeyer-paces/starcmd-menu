// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StarCmd",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "StarCmd", targets: ["StarCmd"]),
        .library(name: "StarCmdCore", targets: ["StarCmdCore"])
    ],
    targets: [
        .executableTarget(
            name: "StarCmd",
            dependencies: ["StarCmdCore"]
        ),
        .target(
            name: "StarCmdCore"
        ),
        .testTarget(
            name: "StarCmdCoreTests",
            dependencies: ["StarCmdCore"]
        )
    ]
)
