// swift-tools-version: 6.1

import PackageDescription

var package = Package(
    name: "NimbusLiveRampKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(
           name: "NimbusLiveRampKit",
           targets: ["NimbusLiveRampKit"])
    ],
    targets: [
        .target(
            name: "NimbusLiveRampKit",
            dependencies: [
                .product(name: "NimbusKit", package: "nimbus-ios-sdk")
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

package.dependencies.append(.package(url: "https://github.com/adsbynimbus/nimbus-ios-sdk", from: "3.0.0-rc.5"))
