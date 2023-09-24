import Vapor
import TelegramVaporBot
import ChatGPTSwift

enum HandlerManagerError: Error {
    case notFoundHandlerToRemove
}

actor HandlerManager {
    
    private struct Const {
        static let minutesToEndSession: UInt64 = 60
    }
    
    private let app: App
    private(set) var handlerFactory: HandlerFactory
    private(set) var activeHandlers: [Int64 : [TGHandlerPrtcl]] = [:]
    private(set) var activeSessions: [Int64: Task<(), Error>] = [:]
    
    init(app: App, handlerFactory: HandlerFactory) {
        self.app = app
        self.handlerFactory = handlerFactory
    }

    private func add(handler: TGHandlerPrtcl, for chatId: Int64) async {
        await app.dispatcher.add(handler)
        var handlers = activeHandlers[chatId] ?? []
        handlers.append(handler)
        activeHandlers[chatId] = handlers
    }
    
    private func remove(handlerName: HandlerFactory.Handler, in chatId: Int64) async throws {
        guard let handlerToRemove = activeHandlers[chatId]?.first(where: {$0.name == handlerName.rawValue + "_\(chatId)"})
        else {
            throw HandlerManagerError.notFoundHandlerToRemove
        }
        await app.dispatcher.remove(handlerToRemove, from: 0)
        let filteredHandlers = activeHandlers[chatId]?.filter({ $0.name != handlerToRemove.name })
        activeHandlers[chatId] = filteredHandlers
    }
   
    private func removeAllHandlers(for chatId: Int64) async throws {
        guard let dispatcher = await app.dispatcher as? Dispatcher else { return }
        await dispatcher.removeAll(by: chatId)
        
        activeHandlers[chatId] = nil
    }
    
    func addDefaultPlayHandler() async throws {
        let defaultHandler = try handlerFactory.createDefaultPlayHandler { [weak self] newGameChatId, _ in
            try await self?.removeAllHandlers(for: newGameChatId)
            await self?.removeChatGptHandler()

            await self?.createNewGameHandlers(for: newGameChatId)
        }
        await app.dispatcher.add(defaultHandler)
        let rollDiceCommandHandler =  handlerFactory.createRollDiceCommandHandler()
        await app.dispatcher.add(rollDiceCommandHandler)
        await observeSessionActivity()
        
        await startHandler()
    }
    
    private func createNewGameHandlers(for chatId: Int64) async {
        let newGame = Game()
        await add(handler: handlerFactory.addPlayerMenuHandler(chatId: chatId, game: newGame), for: chatId)
        await add(handler: handlerFactory.createPassTurnCallbackHandler(chatId: chatId, game: newGame), for: chatId)
        await add(handler: handlerFactory.joinToGameHandler(chatId: chatId, game: newGame), for: chatId)
        await add(handler: handlerFactory.startNewGameHandler(chatId: chatId, game: newGame), for: chatId)
        await add(handler: handlerFactory.createRollDiceHandler(chatId: chatId, game: newGame), for: chatId)
        await add(handler: handlerFactory.createRollDiceCheckConflictHandler(chatId: chatId, game: newGame), for: chatId)
        await add(handler: handlerFactory.createEndTurnHandler(chatId: chatId, game: newGame), for: chatId)
        await add(handler: handlerFactory.createSmallDealHandler(chatId: chatId, game: newGame), for: chatId)
        await add(handler: handlerFactory.createBigDealHandler(chatId: chatId, game: newGame), for: chatId)
        await add(handler: handlerFactory.acceptCharityHandler(chatId: chatId, game: newGame), for: chatId)
        await add(handler: handlerFactory.declineCharityHandler(chatId: chatId, game: newGame), for: chatId)
    }
    
    private func observeSessionActivity() async {
        await app.dispatcher.addBeforeAllCallback { [weak self] update in
            guard let update = update.first else { return true }
            let chatId = update.message?.chat.id ?? update.callbackQuery?.message?.chat.id
            
            guard let chatId = chatId else { return true }
            await self?.startOrUpdateTimer(for: chatId)

            return true
        }
    }
    
    private func startOrUpdateTimer(for sessionChatId: Int64) async {
        if let startedTimer = activeSessions[sessionChatId] {
            startedTimer.cancel()
        }
        
        let task = Task {
            try await Task.sleep(nanoseconds: Const.minutesToEndSession * 60 * 1000 * 1000 * 1000)
            try await endSession(for: sessionChatId)
        }
        await app.logger.log(event: .updateSession(chatId: sessionChatId))
        activeSessions[sessionChatId] = task
    }
    
    private func endSession(for chatId: Int64) async throws {
        if let endedTimer = activeSessions[chatId] {
            endedTimer.cancel()
        }
        activeSessions[chatId] = nil
        try await removeAllHandlers(for: chatId)
        await removeChatGptHandler()
        try await app.tgApi.sendMessage(chatId: chatId, text: "Сессия прекращена. Наберите снова /play чтобы начать игру заново или возобновить игру")
        await app.logger.log(event: .stopSession(chatId: chatId))
    }
    
    // Ниже поддержка чат бота
    private func startHandler() async {
        await app.dispatcher.add(TGMessageHandler(filters: (.command.names(["/start"]))) { [weak self] update, bot in
            guard let message = update.message else { return }
            await self?.removeChatGptHandler()
            let state = DialogState()
            let params: TGSendMessageParams
            if message.from?.id == 566335622,
               message.chat.type == .private,
               await !state.isDialog
            {
                params = TGSendMessageParams(chatId: .chat(message.chat.id), text: "Добро пожаловать, создатель. Обработчики подгружены. Далее отвечать будет ChatGPTBot")
                await self?.messageHandler(state: state)
            } else {
                params = TGSendMessageParams(chatId: .chat(message.chat.id), text: "Для начала игры наберите /play")
            }

            try await self?.app.bot.sendMessage(params: params)
        })
    }
    
    private func messageHandler(state: DialogState) async {
        await state.startDialog()
        await app.dispatcher.add(
            TGMessageHandler(name: "chatGpt", filters: (.all && !.command.names(["/exit"]))) { [weak self] update, bot in
                guard
                    await state.isDialog,
                    let textFromUser = update.message?.text
                else { return }
                
                var apiKey: String = ""
                #if os(Linux)
                if let keyApi = Environment.get("CHATPGPT_API_KEY") {
                    apiKey = keyApi
                } else {
                    await self?.app.bot.app.logger.log(level: .critical, "Ключ chatgpt не получен")
                }
                #elseif os(macOS)
                if let keyApi = ProcessInfo.processInfo.environment["CHATPGPT_API_KEY"] {
                    apiKey = keyApi
                } else {
                    await self?.app.bot.app.logger.log(level: .critical, "Ключ chatgpt не получен")
                }
                #endif
                
                let api = ChatGPTAPI(apiKey: apiKey)
                let gptAnswer = try await api.sendMessage(
                    text: textFromUser
                )

                let params: TGSendMessageParams = .init(chatId: .chat(update.message!.chat.id), text: gptAnswer)
                try await self?.app.bot.sendMessage(params: params)
            }
        )
        await app.dispatcher.add(TGMessageHandler(filters: (.command.names(["/exit"]))) { [weak self] update, bot in
            guard await state.isDialog else { return }
            await state.stopDialog()
            let params: TGSendMessageParams = .init(chatId: .chat(update.message!.chat.id), text: "выход")
            try await self?.app.bot.sendMessage(params: params)
            await self?.removeChatGptHandler()
        })
        
    }
    
    private func removeChatGptHandler() async {
        guard let dispatcher = await app.dispatcher as? Dispatcher else { return }
        await dispatcher.removeChatGptHandler()
    }
}
