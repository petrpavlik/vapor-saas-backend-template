import Vapor
import Logging
import SwiftSentry
import NIOCore
import NIOPosix

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
        
        let app = try await Application.make(env)
        
        // This attempts to install NIO as the Swift Concurrency global executor.
        // You should not call any async functions before this point.
        let executorTakeoverSuccess = NIOSingletons.unsafeTryInstallSingletonPosixEventLoopGroupAsConcurrencyGlobalExecutor()
        app.logger.debug("Running with \(executorTakeoverSuccess ? "SwiftNIO" : "standard") Swift Concurrency default executor")
        
        do {
            try await configure(app)
        } catch {
            app.logger.report(error: error)
            throw error
        }
        try await app.execute()
        try await app.asyncShutdown()
        try await sentry?.shutdown()
    }
}
