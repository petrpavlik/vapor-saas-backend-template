import Logging
import MixpanelVapor
import SwiftSentry
import Vapor

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()

        let sentry: Sentry? = try {
            if env.isRelease {
                if let sentryDsn = Environment.process.SENTRY_DSN {
                    return try Sentry(dsn: sentryDsn)
                }
            }
            return nil
        }()

        let loggerLevel = try Logger.Level.detect(from: &env)

        LoggingSystem.bootstrap { label in
            var logHandlers = [LogHandler]()

            if let sentry {
                logHandlers.append(SentryLogHandler(label: label, sentry: sentry, level: .warning))
            }

            let console = Terminal()
            logHandlers.append(ConsoleLogger(label: label, console: console, level: loggerLevel))

            return MultiplexLogHandler(logHandlers)
        }

        let app = try await Application.make(env)

        do {
            try await configure(app)
            try await app.execute()
            await app.mixpanel.shutdown()
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            try? await sentry?.shutdown()
            throw error
        }

        try await app.asyncShutdown()
        try await sentry?.shutdown()
    }
}
