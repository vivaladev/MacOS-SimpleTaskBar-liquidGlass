// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TaskBar",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "TaskBar", targets: ["TaskBar"]),
    ],
    targets: [
        .executableTarget(
            name: "TaskBar",
            path: "Sources/TaskBar",
            exclude: ["Resources"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("UniformTypeIdentifiers"),
            ]
        ),
    ]
)
