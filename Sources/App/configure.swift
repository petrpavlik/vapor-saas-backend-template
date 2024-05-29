import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    // cors middleware should come before default error middleware using `at: .beginning`
    app.middleware.use(cors, at: .beginning)

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
	
    if let firebaseProjectId = Environment.process.FIREBASE_PROJECT_ID {
        app.firebaseJwt.applicationIdentifier = firebaseProjectId
    } else {
        fatalError("FIREBASE_PROJECT_ID not configured")
    }
    
    if app.environment.isRelease {
        
        if let  mixpanelToken = Environment.process.MIXPANEL_TOKEN {
            app.mixpanel.configuration = .init(token: mixpanelToken)
        } else {
            app.logger.warning("Mixpanel disabled, env variables were not provided")
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
