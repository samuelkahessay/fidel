// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SyncKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SyncKit", targets: ["SyncKit"])
    ],
    targets: [
        .target(
            name: "SyncKit",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(name: "SyncKitTests", dependencies: ["SyncKit"])
    ]
)
