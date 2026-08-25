// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TopDown",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TopDown", targets: ["TopDown"]),
    ],
    targets: [
        .executableTarget(name: "TopDown"),
    ],
    swiftLanguageModes: [.v5]
)
