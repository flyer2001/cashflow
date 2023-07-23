import Vapor
import TelegramVaporBot

// configures your application
func configure(_ app: Application, completion: ((App) -> ())? = nil) async throws {
    let tgApi: String = "6173467253:AAEaImjv6mkqSJh3XxmBwQzuoJbyH9Su2Mo"
    TGBot.log.logLevel = app.logger.logLevel
    let tgBotConnection = TGBotConnection()
    let bot: TGBot = .init(app: app, botId: tgApi)
    let logger = ChatBotLogger(app: app)
    let imageCache = ImageCache(logger: logger)
    let mapDrawer = MapDrawer(cache: imageCache, logger: logger)
    
    let tgApiHelper = TelegramBotAPIHelper(bot: bot, logger: logger)
    let handlerFactory = HandlerFactory(
        cache: imageCache,
        tgApi: tgApiHelper,
        logger: logger,
        mapDrawer: mapDrawer
    )

    let tgBotApp = App(
        cache: imageCache,
        logger: logger,
        tgBotConnection: tgBotConnection,
        tgApiHelper: tgApiHelper,
        handlerFactory: handlerFactory
    )
    
     #if os(Linux)
    await tgBotApp.setConnection(try await TGWebHookConnection(bot: bot, webHookURL: "https://cashflow-game.ru/telegramWebHook", dispatcher: Dispatcher.self))

    #elseif os(macOS)
    // LongPolling использовать только для дебага
    await tgBotApp.setConnection(try await TGLongPollingConnection(bot: bot, dispatcher: Dispatcher.self))
    #endif
    
    var imagePath = ""
    #if os(Linux)
        imagePath = app.directory.publicDirectory + "rat_ring.png"
    #elseif os(macOS)
        // Путь для дебага
        imagePath = "/Users/sgpopyvanov/tgbot/Public/rat_ring.png"
    #endif
    await tgBotApp.cache.setImagePath(path: imagePath)
    
    try await tgBotApp.startConnection()
    
    if app.environment == .development {
        try await tgBotApp.handlerManager.addDefaultPlayHandler()
    }
    
    #if os(Linux)
    try app.register(collection: tgBotApp)
    #endif
    completion?(tgBotApp)
}
