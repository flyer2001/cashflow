// swift-tools-version:5.8
import PackageDescription
    
let package = Package(
    name: "tgbot",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", .upToNextMajor(from: "4.105.2")),
        .package(url: "https://github.com/nerzh/swift-telegram-sdk", .upToNextMajor(from: "3.5.2")),
        // ChatGPT
        .package(url: "https://github.com/alfianlosari/ChatGPTSwift.git", .upToNextMajor(from: "2.3.3")),
        .package(url: "https://github.com/t-ae/Swim", .upToNextMajor(from: "3.9.0")),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SwiftTelegramSdk", package: "swift-telegram-sdk"),
                .product(name: "ChatGPTSwift", package: "ChatGPTSwift"),
                .product(name: "Swim", package: "Swim")
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://www.swift.org/server/guides/building.html#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ]
)
