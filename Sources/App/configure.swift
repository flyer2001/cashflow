import Vapor
import TelegramVaporBot

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    let tgApi: String = "6173467253:AAEaImjv6mkqSJh3XxmBwQzuoJbyH9Su2Mo"
    TGBot.log.logLevel = app.logger.logLevel
    let bot: TGBot = .init(app: app, botId: tgApi)
    await tgBotConnection.setConnection(try await TGLongPollingConnection(bot: bot))
    
    await DefaultBotHandlers.addHandlers(app: app, connection: tgBotConnection.connection)
    try await tgBotConnection.connection.start()
    
    
    // register routes
    try routes(app)
}
