// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HomeScenesDockWidget",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "HomeScenesDockWidget",
            type: .dynamic,
            targets: ["HomeScenesDockWidget"]
        ),
    ],
    dependencies: [
        .package(path: "../../sdk/swift"),
    ],
    targets: [
        .target(
            name: "HomeScenesDockWidget",
            dependencies: [
                .product(name: "VehlaDockWidgetSDK", package: "swift"),
            ]
        ),
        .testTarget(
            name: "HomeScenesDockWidgetTests",
            dependencies: ["HomeScenesDockWidget"]
        ),
    ]
)
