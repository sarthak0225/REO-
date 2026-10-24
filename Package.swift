// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "REO",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "REOCore", targets: ["REOCore"]),
        .executable(name: "REO", targets: ["REO"]),
        .executable(name: "REOTestsRunner", targets: ["REOTestsRunner"])
    ],
    targets: [
        .target(
            name: "REOCore",
            dependencies: [],
            path: "Sources/REOCore"
        ),
        .executableTarget(
            name: "REO",
            dependencies: ["REOCore"],
            path: "Sources/REO"
        ),
        .executableTarget(
            name: "REOTestsRunner",
            dependencies: ["REOCore"],
            path: "Tests/REOTestsRunner"
        )
    ]
)
