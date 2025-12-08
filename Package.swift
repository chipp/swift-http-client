// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-http-client",
    platforms: [.macOS(.v13), .iOS(.v15)],
    products: [
        .library(name: "HTTP", targets: ["HTTP"])
    ],
    dependencies: [
        .package(url: "https://github.com/chipp/SwiftFormatPlugin", .upToNextMajor(from: "0.55.6")),
        .package(url: "https://github.com/chipp/SwiftLintPlugin", .upToNextMajor(from: "0.59.1"))
    ],
    targets: [
        .target(name: "HTTP", plugins: [
            .plugin(name: "SwiftFormat", package: "SwiftFormatPlugin"),
            .plugin(name: "SwiftLint", package: "SwiftLintPlugin")
        ])
    ]
)
