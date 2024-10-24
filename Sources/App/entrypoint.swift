import Vapor
import Logging
import SwiftSentry
import NIOCore
import NIOPosix

@main
enum Entrypoint {
    static func main() async throws {
        let env = try Environment.detect()
        
        let sentry: Sentry? = try {
            if env.isRelease {
                if let sentryDsn = Environment.process.SENTRY_DSN {
                    return try Sentry(dsn: sentryDsn)
                }
            }
            return nil
        }()
        
        LoggingSystem.bootstrap { label in
            var logHandlers = [LogHandler]()
            if let sentry {
                logHandlers.append(SentryLogHandler(label: label, sentry: sentry, level: .warning))
            }
            logHandlers.append(StreamLogHandler.standardOutput(label: label))

            return MultiplexLogHandler(logHandlers)
        }
        
        let app = try await Application.make(env)
        
        do {
            try await configure(app)
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            try? await sentry?.shutdown()
            throw error
        }
        
        try await app.execute()
        try await app.asyncShutdown()
        try await sentry?.shutdown()
    }
}
