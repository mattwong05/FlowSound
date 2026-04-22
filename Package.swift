// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FlowSound",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "FlowSound", targets: ["FlowSound"])
    ],
    targets: [
        .executableTarget(name: "FlowSound"),
        .testTarget(
            name: "FlowSoundTests",
            dependencies: ["FlowSound"]
        )
    ]
)
