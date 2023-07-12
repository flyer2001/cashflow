import Vapor
import TelegramVaporBot

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    let tgApi: String = "6173467253:AAEaImjv6mkqSJh3XxmBwQzuoJbyH9Su2Mo"
    TGBot.log.logLevel = app.logger.logLevel
    let bot: TGBot = .init(app: app, botId: tgApi)
    #if os(Linux)
    await App.setConnection(try await TGWebHookConnection(bot: bot, webHookURL: "https://cashflow-game.ru/telegramWebHook"))

    #elseif os(macOS)
    // LongPolling использовать только для дебага
    await App.setConnection(try await TGLongPollingConnection(bot: bot))
    #endif
    
    var imagePath = ""
    #if os(Linux)
        imagePath = app.directory.publicDirectory + "rat_ring.png"
    #elseif os(macOS)
        // Путь для дебага
        imagePath = "/Users/sgpopyvanov/tgbot/Public/rat_ring.png"
    #endif
    await App.cache.setImagePath(path: imagePath)
    
    await DefaultBotHandlers.addHandlers()
    try await App.startConnection()
    
    #if os(Linux)
    await App.bot.app.logger.debug("register controller")
    try routes(app)
    #endif
}

func routes(_ app: Application) throws {
    try app.register(collection: TelegramController())
}

final class TelegramController: RouteCollection {
    
    func boot(routes: Vapor.RoutesBuilder) throws {
        routes.post("telegramWebHook", use: telegramWebHook)
    }
}

extension TelegramController {
    
    func telegramWebHook(_ req: Request) async throws -> Bool {
        await App.bot.app.logger.debug("get telegram request")
        let update: TGUpdate = try req.content.decode(TGUpdate.self)
        
        return try await App.dispatcher.process([update])
    }
}
