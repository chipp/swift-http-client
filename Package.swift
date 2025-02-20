// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-http-client",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(name: "HTTP", targets: ["HTTPClient"])
    ],
    targets: [
        .target(name: "HTTPClient")
    ]
)
