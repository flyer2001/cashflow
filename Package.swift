// swift-tools-version:5.8
import PackageDescription
    
let package = Package(
    name: "tgbot",
    platforms: [
       .macOS(.v12)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.91.1"),
        .package(url: "https://github.com/nerzh/telegram-vapor-bot", .upToNextMajor(from: "2.3.2")),
        // ChatGPT
        .package(url: "https://github.com/flyer2001/ChatGPTSwift", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/t-ae/Swim", .upToNextMajor(from: "3.0.0")),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "TelegramVaporBot", package: "telegram-vapor-bot"),
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
