// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TaskLock",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "TaskLock",
            targets: ["TaskLockApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "TaskLockApp",
            path: "Sources",
            sources: ["TaskLockApp"],
            resources: [
                .process("sound_effects")
            ]
        )
    ]
)
