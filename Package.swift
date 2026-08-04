// swift-tools-version: 6.1

import PackageDescription

var package = Package(
    name: "NimbusLiveRampKit",
    platforms: [.iOS(.v13)],
    products: [
        .library(
           name: "NimbusLiveRampKit",
           targets: ["NimbusLiveRampKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/LiveRamp/ats-sdk-ios", from: "2.5.0")
    ],
    targets: [
        .target(
            name: "NimbusLiveRampKit",
            dependencies: [
                .product(name: "NimbusKit", package: "nimbus-ios-sdk"),
                .product(name: "LRAtsSDK", package: "ats-sdk-ios")
            ]
        ),
        .testTarget(
            name: "NimbusLiveRampKitTests",
            dependencies: ["NimbusLiveRampKit"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)

package.dependencies.append(.package(url: "https://github.com/adsbynimbus/nimbus-ios-sdk", from: "3.0.0-rc.3"))
