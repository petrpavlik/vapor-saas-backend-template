import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor
import VaporSMTPKit
import SMTPKitten

extension Application {
    func sendEmail(subject: String, message: String, to email: String) async throws {
        guard try Environment.detect() != .testing else {
            return
        }
        
        guard let smtpHostName = Environment.process.SMTP_HOSTNAME else {
            throw Abort(.internalServerError, reason: "SMTP_HOSTNAME env variable not defined")
        }
        
        guard let smtpEmail = Environment.process.SMTP_EMAIL else {
            throw Abort(.internalServerError, reason: "SMTP_EMAIL env variable not defined")
        }
        
        guard let smtpPassword = Environment.process.SMTP_PASSWORD else {
            throw Abort(.internalServerError, reason: "SMTP_PASSWORD env variable not defined")
        }
        
        let credentials = SMTPCredentials(
            hostname: smtpHostName,
            ssl: .startTLS(configuration: .default),
            email: smtpEmail,
            password: smtpPassword
        )
        
        let email = Mail(
            from: .init(name: "[name] from [company]", email: smtpEmail),
            to: [
                MailUser(name: nil, email: email)
            ],
            subject: subject,
            contentType: .plain, // supports html
            text: message
        )
        
        try await sendMail(email, withCredentials: credentials).get()
    }
}

extension Request {
    func sendEmail(subject: String, message: String, to: String) async throws {
        try await self.application.sendEmail(subject: subject, message: message, to: to)
    }
}

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
        
        if let  mixpanelProjectId = Environment.process.MIXPANEL_PROJECT_ID,
              let mixpanelUsername = Environment.process.MIXPANEL_USERNAME,
              let mixpanelPassword = Environment.process.MIXPANEL_PASSWORD {
            
            app.mixpanel.configuration = .init(projectId: mixpanelProjectId,
                                               authorization: .init(username: mixpanelUsername,
                                                                    password: mixpanelPassword))
        } else {
            app.logger.warning("Mixpanel disabled, env variables were not provided")
        }
        
        
    }

    app.migrations.add(CreateProfile())
    app.migrations.add(CreateOrganization())
    app.migrations.add(CreateProfileOrganizationRole())

    if try Environment.detect() != .testing {
        try await app.autoMigrate()        
    }

    // register routes
    try routes(app)
}
