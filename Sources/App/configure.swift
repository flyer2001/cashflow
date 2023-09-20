import Vapor
import TelegramVaporBot

// configures your application
func configure(_ app: Application, completion: ((App) -> ())? = nil) async throws {
    TGBot.log.logLevel = app.logger.logLevel
    
    // TODO - сервис припилить который получает ключи
    // Получаем ключ бота
    var tgApi: String = ""
    #if os(Linux)
    // файлик .env.development на хостинге
    if let keyApi = Environment.get("TG_API_KEY") {
        tgApi = keyApi
    } else {
        app.logger.log(level: .critical, "Ключ не получен")
    }
    #elseif os(macOS)
    // Переменные окружения прямо в XCode
    // Внимание для дебага и прода используются разные ключи и соотвественно боты
    if let keyApi = ProcessInfo.processInfo.environment["TG_API_KEY"] {
        tgApi = keyApi
    } else {
        app.logger.log(level: .critical, "Ключ не получен")
    }
    #endif
    
    let tgBotConnection = TGBotConnection()
    let bot: TGBot = .init(app: app, botId: tgApi)
    let logger = ChatBotLogger(app: app)
    let imageCache = ImageCache(logger: logger)
    let mapDrawer = MapDrawer(cache: imageCache, logger: logger)
    let professionsCardDrawer = ProffessionsCardDrawer(cache: imageCache)
    
    let tgApiHelper = TelegramBotAPIHelper(bot: bot, logger: logger)
    let handlerFactory = HandlerFactory(
        cache: imageCache,
        tgApi: tgApiHelper,
        logger: logger,
        mapDrawer: mapDrawer,
        professionsCardDrawer: professionsCardDrawer
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
    var proffesionsPath = ""
    #if os(Linux)
        imagePath = app.directory.publicDirectory + "rat_ring.png"
        proffesionsPath = app.directory.publicDirectory
    #elseif os(macOS)
        // Путь для дебага
        imagePath = "/Users/sgpopyvanov/tgbot/Public/rat_ring.png"
        proffesionsPath = "/Users/sgpopyvanov/tgbot/Public/"
    #endif
    await tgBotApp.cache.setImagePath(path: imagePath)
    await tgBotApp.cache.setProffesionsPath(path: proffesionsPath)
    
    try await tgBotApp.startConnection()
    
    if app.environment != .testing  {
        app.logger.log(level: .critical, "Основные обработчики добавлены")
        try await tgBotApp.handlerManager.addDefaultPlayHandler()
    }
    
    #if os(Linux)
    try app.register(collection: tgBotApp)
    #endif
    completion?(tgBotApp)
}
