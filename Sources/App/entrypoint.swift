import Vapor
import Dispatch
import Logging
import SwiftTelegramSdk

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

actor App: RouteCollection {
    let cache: ImageCache
    let logger: ChatBotLogger
    let tgApi: TelegramBotAPIHelper
    lazy var handlerManager = HandlerManager(
        app: self,
        handlerFactory: handlerFactory
    )
    
    //private let tgBotConnection: TGBotConnection
    private let handlerFactory: HandlerFactory
    
    var bot: TGBot {
        get async {
            tgApi.bot
        }
    }
    
    var dispatcher: TGDispatcherPrtcl {
        get async {
            tgApi.bot.dispatcher
        }
    }
    
    init(
        cache: ImageCache,
        logger: ChatBotLogger,
        tgApiHelper: TelegramBotAPIHelper,
        handlerFactory: HandlerFactory
    ) {
        self.cache = cache
        self.logger = logger
        self.tgApi = tgApiHelper
        self.handlerFactory = handlerFactory
    }
    
    // RouteCollection
    nonisolated func boot(routes: Vapor.RoutesBuilder) throws {
        routes.post("telegramWebHook", use: telegramWebHook)
    }
    @Sendable
    func telegramWebHook(_ req: Request) async throws -> Bool {
            let update: TGUpdate = try req.content.decode(TGUpdate.self)
            Task { await bot.dispatcher.process([update]) }
            return true
        }
    
//    @Sendable
//    private func telegramWebHook(_ req: Request) async throws {
//        let update: TGUpdate = try req.content.decode(TGUpdate.self)
//        try await dispatcher.process([update])
//    }
    
    // Настройка бота
//    func setConnection(_ connection: TGConnectionPrtcl) async {
//        await tgBotConnection.setConnection(connection)
//    }
    func startConnection() async throws {
        try await bot.start()
    }
}

// пока не пидумал ничего умнее вот так захватывать ссылку с аппой
var tgBotApp: App!

@main
enum Entrypoint {
    
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let eventLoop: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount * 4)
        
        let app = Application(env, Application.EventLoopGroupProvider.shared(eventLoop))
        defer {
            app.shutdown()
            tgBotApp = nil
        }
        
        do {
            try await configure(app) { tgApp in
                tgBotApp = tgApp
            }
        } catch {
            app.logger.report(error: error)
            throw error
        }
        try await app.runFromAsyncMainEntrypoint()
    }
}
