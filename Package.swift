// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SaasTemplate",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.83.1"),
        // 🗄 An ORM for SQL and NoSQL databases.
        .package(url: "https://github.com/vapor/fluent.git", from: "4.8.0"),
        // 🐘 Fluent driver for Postgres.
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.7.2"),
        .package(url: "https://github.com/emvakar/vapor-firebase-jwt-middleware.git", branch: "master"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.0.0"),
        .package(url: "https://github.com/petrpavlik/swift-sentry.git", from: "1.0.0"),
        .package(url: "https://github.com/petrpavlik/MixpanelVapor.git", from: "1.0.0"),
        .package(url: "https://github.com/Joannis/VaporSMTPKit.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "FirebaseJWTMiddleware", package: "vapor-firebase-jwt-middleware"),
                .product(name: "SwiftSentry", package: "swift-sentry"),
                "MixpanelVapor",
                .product(name: "VaporSMTPKit", package: "VaporSMTPKit"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
            .product(name: "Nimble", package: "Nimble"),
        ], swiftSettings: swiftSettings)
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableExperimentalFeature("StrictConcurrency"),
] }
