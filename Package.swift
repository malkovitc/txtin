// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "txtin",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "txtin", targets: ["txtin"])
    ],
    targets: [
        .executableTarget(
            name: "txtin",
            path: "Sources/txtin"
        )
    ]
)
