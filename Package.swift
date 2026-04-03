// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DesktopBuddy",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "DesktopBuddy",
            targets: ["DesktopBuddy"]
        ),
        .executable(
            name: "BuddyClaw",
            targets: ["BuddyClawCLI"]
        ),
    ],
    targets: [
        .target(
            name: "DesktopBuddy",
            dependencies: [],
            path: "Sources/DesktopBuddy",
            exclude: [
                "Resources/Sounds",
                "Resources/RuntimeSprites",
                "Resources/Spritesheets",
                "Resources/process_claw.py",
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
        .executableTarget(
            name: "BuddyClawCLI",
            dependencies: ["DesktopBuddy"],
            path: "Sources/BuddyClawCLI"
        ),
        .testTarget(
            name: "DesktopBuddyTests",
            dependencies: ["DesktopBuddy"],
            path: "Tests/DesktopBuddyTests"
        ),
    ]
)
