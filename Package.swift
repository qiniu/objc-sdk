// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Qiniu",
    platforms: [
        .macOS(.v10_10),
        .iOS(.v8)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Qiniu",
            targets: ["QiniuSDK"]),
    ],
    dependencies: [
        .package(name:"HappyDNS", url: "https://github.com/YangSen-qn/happy-dns-objc", "1.0.1"..<"1.1.0"),
    ],
    targets: [
        .target(
            name: "QiniuSDK",
            dependencies: ["HappyDNS"],
            path: "QiniuSDK",
            sources: ["BigData", "Collect", "Common", "Http", "Recorder", "Storage", "Transaction", "Utils"],
            cSettings: [
                .headerSearchPath("BigData"),
                .headerSearchPath("Collect"),
                .headerSearchPath("Common"),
                .headerSearchPath("Http"),
                .headerSearchPath("Recorder"),
                .headerSearchPath("Storage"),
                .headerSearchPath("Transaction"),
                .headerSearchPath("Utils"),
            ]),
    ]
)
