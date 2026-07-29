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
        // Pure logic: no AppKit, no AVFoundation, no network, no globals.
        // Everything it needs is passed in, so it can be tested directly.
        .target(name: "OpenDictateCore"),
        .executableTarget(
            name: "OpenDictate",
            dependencies: ["OpenDictateCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "OpenDictateCoreTests",
            dependencies: ["OpenDictateCore"]
        )
    ]
)
