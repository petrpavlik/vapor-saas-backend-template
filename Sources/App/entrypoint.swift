import Vapor
import Dispatch
import Logging
import SwiftSentry

/// This extension is temporary and can be removed once Vapor gets this support.
private extension Vapor.Application {
    static let baseExecutionQueue = DispatchQueue(label: "vapor.codes.entrypoint")
    
    func runFromAsyncMainEntrypoint() async throws {
        try await withCheckedThrowingContinuation { continuation in
            Vapor.Application.baseExecutionQueue.async { [self] in
                do {
                    try self.run()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

@main
enum Entrypoint {
    static func main() async throws {
        let env = try Environment.detect()
        
        var sentry: Sentry?
        if env.isRelease {
            if let sentryDsn = Environment.process.SENTRY_DSN {
                sentry = try Sentry(dsn: sentryDsn)
            }
        }
                
        LoggingSystem.bootstrap { label in
            var logHandlers = [LogHandler]()
            if let sentry {
                logHandlers.append(SentryLogHandler(label: label, sentry: sentry, level: .warning))
            }
            logHandlers.append(StreamLogHandler.standardOutput(label: label))

            return MultiplexLogHandler(logHandlers)
        }
        
        let app = Application(env)
        defer {
            app.shutdown()
            try? sentry?.shutdown()
        }
        
        do {
            try await configure(app)
        } catch {
            app.logger.report(error: error)
            throw error
        }
        try await app.runFromAsyncMainEntrypoint()
    }
}
