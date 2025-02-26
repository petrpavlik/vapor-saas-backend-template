// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SaasTemplate",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.83.1"),
        // 🗄 An ORM for SQL and NoSQL databases.
        .package(url: "https://github.com/vapor/fluent.git", from: "4.8.0"),
        // 🐘 Fluent driver for Postgres.
        // .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.7.2"), // uncomment this line to use Postgres instead of SQLite
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.6.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "5.1.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.0.0"),
        .package(url: "https://github.com/petrpavlik/swift-sentry.git", from: "1.0.0"),
        .package(url: "https://github.com/petrpavlik/MixpanelVapor.git", from: "1.0.0"),
        .package(url: "https://github.com/IndiePitcher/indiepitcher-swift.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                // .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"), // uncomment this line to use Postgres instead of SQLite
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "SwiftSentry", package: "swift-sentry"),
                "MixpanelVapor",
                .product(name: "IndiePitcherSwift", package: "indiepitcher-swift"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "XCTVapor", package: "vapor"),
                .product(name: "Nimble", package: "Nimble"),
            ], swiftSettings: swiftSettings),
    ],
    swiftLanguageModes: [.v5]
)

var swiftSettings: [SwiftSetting] {
    [
        .enableUpcomingFeature("DisableOutwardActorInference"),
        .enableExperimentalFeature("StrictConcurrency"),
    ]
}
