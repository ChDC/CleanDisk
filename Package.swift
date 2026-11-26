// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CleanDiskTrash",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CleanDiskTrashCore", targets: ["CleanDiskTrashCore"]),
        .executable(name: "CleanDiskTrash", targets: ["CleanDiskTrash"]),
    ],
    targets: [
        .target(name: "CleanDiskTrashCore"),
        .executableTarget(
            name: "CleanDiskTrash",
            dependencies: ["CleanDiskTrashCore"]
        ),
        .testTarget(
            name: "CleanDiskTrashCoreTests",
            dependencies: ["CleanDiskTrashCore"]
        ),
    ]
)
