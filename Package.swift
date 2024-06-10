// swift-tools-version:5.7.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GetStreamActivityFeed",
    defaultLocalization: "en", // Set the default localization here
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(
            name: "GetStreamActivityFeed",
            targets: ["GetStreamActivityFeed"])
    ],
    dependencies: [
        .package(url: "https://github.com/camelan/stream-swift", branch: "release-2-8-34-10-6-2024"),
        .package(url: "https://github.com/kean/Nuke", .exactItem("12.6.0")),
        .package(url: "https://github.com/AliSoftware/Reusable.git", .exactItem("4.1.2")),
        .package(url: "https://github.com/SnapKit/SnapKit", .exactItem("5.7.1")),
        .package(url: "https://github.com/onevcat/Kingfisher.git", .exactItem("7.11.0"))
    ],
    targets: [
          .target(
              name: "GetStreamActivityFeed",
              dependencies: ["Nuke", "Reusable", "SnapKit", "Kingfisher",
                .product(name: "GetStream", package: "stream-swift") ],
              path: "Sources/"),
      ]
)
