import Fluent
// import FluentPostgresDriver // uncomment this line to use Postgres instead of SQLite
import FluentSQLiteDriver
import NIOSSL
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,  // or .custom("https://app.example.com") to allowe browser (React, ...) requests only from this domain
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [
            .accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent,
        ]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    // cors middleware should come before default error middleware using `at: .beginning`
    app.middleware.use(cors, at: .beginning)

    // use sqlite for testing and development
    // look bellow how to use Postgres instead of SQLite. MySQL is also supported.
    if app.environment == .testing {
        app.databases.use(DatabaseConfigurationFactory.sqlite(.file("db.sqlite")), as: .sqlite)
    } else {
        app.databases.use(DatabaseConfigurationFactory.sqlite(.file("db-test.sqlite")), as: .sqlite)
    }

    /*
    // uncomment this block to use Postgres instead of SQLite

	var tlsConfig: TLSConfiguration = .makeClientConfiguration()
	// Check if you can increase the security by performing a certificate verification based on your database setup
	tlsConfig.certificateVerification = .none
	let nioSSLContext = try NIOSSLContext(configuration: tlsConfig)

	let config = SQLPostgresConfiguration(
		hostname: Environment.get("DATABASE_HOST") ?? "localhost",
		port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? (app.environment == .testing ? 5433 : 5432),
		username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
		password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
		database: Environment.get("DATABASE_NAME") ?? "vapor_database",
		tls: app.environment == .production ? .require(nioSSLContext) : .disable
	)
	let postgres = DatabaseConfigurationFactory.postgres(configuration: config)
	app.databases.use(postgres, as: .psql)
    */

    if app.environment != .testing {
        app.services.analyticsService.use { app in
            MixpanelAnalyticsService(mixpanel: app.mixpanel)
        }
    } else {
        app.services.analyticsService.use { app in
            NoOpAnalyticsService()
        }
    }

    if let firebaseProjectId = Environment.process.FIREBASE_PROJECT_ID {
        app.jwt.firebaseAuth.applicationIdentifier = firebaseProjectId
    } else {
        fatalError("FIREBASE_PROJECT_ID not configured")
    }

    if app.environment.isRelease {

        if let mixpanelToken = Environment.process.MIXPANEL_TOKEN {
            app.mixpanel.configuration = .init(token: mixpanelToken)
        } else {
            app.logger.warning("Mixpanel disabled, env variables were not provided")
        }
    }

    if app.environment == .testing {
        // inject mock services
        app.services.emailService.use { app in
            MockEmailService()
        }
    } else {
        // inject real services
        app.services.emailService.use { app in
            IndiePitcherEmailService(application: app)  // requires IP_SECRET_API_KEY env value
            // MockEmailService() // disable emails
        }
    }

    app.migrations.add(CreateProfile())
    app.migrations.add(CreateOrganization())
    app.migrations.add(CreateProfileOrganizationRole())
    app.migrations.add(CreateOrganizationInvite())

    // You probably want to remove this and run migrations manually if
    // you're running more than 1 instance of your backend behind a load balancer
    if try Environment.detect() != .testing {
        try await app.autoMigrate()
    }

    // register routes
    try routes(app)
}
