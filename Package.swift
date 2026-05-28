// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OpenDictate",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OpenDictate", targets: ["OpenDictate"])
    ],
    targets: [
        .executableTarget(
            name: "OpenDictate",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Security")
            ]
        )
    ]
)
