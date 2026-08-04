// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WiroKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "WiroKit", targets: ["WiroKit"]),
    ],
    targets: [
        .target(
            name: "WiroKit",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "WiroKitTests",
            dependencies: ["WiroKit"],
            resources: [
                .copy("Fixtures"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
