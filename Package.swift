// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DesktopBuddy",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "BuddyClaw",
            targets: ["DesktopBuddy"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "DesktopBuddy",
            dependencies: [],
            path: "Sources/DesktopBuddy",
            exclude: [
                "Resources/Sounds",
                "Resources/RuntimeSprites",
                "Resources/Spritesheets",
            ],
            resources: [
                .copy("Resources/PixelSprites"),
                .copy("Resources/ClawSprites"),
                .copy("Resources/StarterPack"),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(
            name: "DesktopBuddyTests",
            dependencies: ["DesktopBuddy"],
            path: "Tests/DesktopBuddyTests"
        ),
    ]
)
