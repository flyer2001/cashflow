import Vapor
import TelegramVaporBot

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    let tgApi: String = "6173467253:AAEaImjv6mkqSJh3XxmBwQzuoJbyH9Su2Mo"
    TGBot.log.logLevel = app.logger.logLevel
    let bot: TGBot = .init(app: app, botId: tgApi)
    await App.setConnection(try await TGLongPollingConnection(bot: bot))
    
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
}
