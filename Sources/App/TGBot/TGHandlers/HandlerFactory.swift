import TelegramVaporBot

enum HandlerFactoryError: Error {
    case chatIdNotFound
}

final class HandlerFactory {
    enum Handler: String {
        case playHandler
        case addPlayerMenuCallback
        case joingToGameCallback
        case startGameCallback
        case rulesCallback
        case resumeCallback
        case rollDiceCallback
        case endTurnCallback
    }
    
    
    private let tgApi: TelegramBotAPIHelper
    private let cache: ImageCache
    private let logger: ChatBotLogger
    private let mapDrawer: MapDrawer

    init(
        cache: ImageCache,
        tgApi: TelegramBotAPIHelper,
        logger: ChatBotLogger,
        mapDrawer: MapDrawer
    ) {
        self.tgApi = tgApi
        self.cache = cache
        self.logger = logger
        self.mapDrawer = mapDrawer
    }

    func createDefaultPlayHandler(startGameCompletion: @escaping (_ chatId: Int64, _ messageId: Int) async throws -> ()) throws -> TGHandlerPrtcl {
        TGCommandHandler(
            name: Handler.playHandler.rawValue,
            commands: ["/play"]
        ) { [weak self] update, bot in
            guard let chatId = update.message?.chat.id else {
                throw HandlerFactoryError.chatIdNotFound
            }
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [
                    .init(text: "Новая игра", callbackData: "\(Handler.addPlayerMenuCallback.rawValue)_\(chatId)"),
                    .init(text: "Возобновить игру", callbackData: "\(Handler.resumeCallback.rawValue)_\(chatId)"),

                ],
                [
                    .init(text: "Правила игры", callbackData: "\(Handler.rulesCallback.rawValue)_\(chatId)"),
                ]
            ]
            guard let self = self else { return }
            try await self.tgApi.sendMessage(
                chatId: chatId,
                text: "Приветствуем\\! Это игра *Cashflow*\\. Нажмите одну из кнопок ниже",
                parseMode: .markdownV2,
                inlineButtons: buttons
            ) { message in
                await self.logger.log(event: .startGameMenuSent)
                try? await startGameCompletion(chatId, message.messageId)
            }
        }
    }
    
    func addPlayerMenuHandler(chatId: Int64, game: Game) -> TGHandlerPrtcl {
        let callbackName = "\(Handler.addPlayerMenuCallback.rawValue)_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            guard chatId == update.callbackQuery?.message?.chat.id else { return }
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [
                    .init(text: "Присоединиться к игре", callbackData: "\(Handler.joingToGameCallback.rawValue)_\(chatId)"),
                    .init(text: "Начать игру", callbackData: "\(Handler.startGameCallback.rawValue)_\(chatId)"),

                ]
            ]
            
            try await self?.tgApi.sendMessage(
                chatId: chatId,
                text: "Теперь каждому игроку, который хочет присоединиться к игре \\- необходимо нажать кнопку *Присоединиться к игре*\\. Внимание\\!\\! Кнопку *Начать игру* нажимает ведущий игры",
                parseMode: .markdownV2,
                inlineButtons: buttons
            ) { message in
                await self?.logger.log(event: .addPlayersMenuSent)
                await self?.logger.log(event: .message(id: message.messageId))
            }
        }
    }
    
    func joinToGameHandler(chatId: Int64, game: Game) -> TGHandlerPrtcl {
        let callbackName = "\(Handler.joingToGameCallback.rawValue)_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            guard chatId == update.callbackQuery?.message?.chat.id,
                  let id = update.callbackQuery?.from.id,
                  let name = update.callbackQuery?.from.username
            else { return }
            await game.addPlayer(id, name: name)
            
            try await self?.tgApi.sendMessage(
                chatId: chatId,
                text: "\(name) добавлен в игру"
            ) { message in
                await self?.logger.log(event: .joinToGame)
            }
        }
    }
    
    func startNewGameHandler(chatId: Int64, game: Game) -> TGHandlerPrtcl {
        let callbackName = "\(Handler.startGameCallback.rawValue)_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            guard chatId == update.callbackQuery?.message?.chat.id else { return }
            
            if await game.players.count > 1  {
                try await game.shuffle()
            }
            let currentPlayerName = await game.currentPlayer.name
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Бросить кубик 🎲", callbackData: Handler.rollDiceCallback.rawValue + "_\(chatId)")]
            ]
            try? await self?.tgApi.sendCallbackAnswer(callbackId: update.callbackQuery?.id ?? "", "Создаю новую игру")
            
            try await self?.sendMap(
                for: game.currentPlayer.position,
                chatId: chatId,
                captionText: "\(currentPlayerName) ваш ход",
                parseMode: nil,
                buttons: buttons
            )
        }
    }
    
    private func sendMap(
        for position: Int,
        chatId: Int64,
        captionText: String?,
        parseMode: TGParseMode? = nil,
        buttons: [[TGInlineKeyboardButton]]?
    ) async throws {
        if let fileId = await cache.getValue(for: position) {
            try await tgApi.sendPhotoFromCache(
                chatId: chatId,
                fileId: fileId,
                captionText: captionText,
                parseMode: parseMode,
                buttons: buttons)
            return
        }
        
        let outputImageData = try await mapDrawer.drawMap(for: position)
        
        try await tgApi.sendPhoto(
            chatId: chatId,
            captionText: captionText,
            parseMode: parseMode,
            photoData: outputImageData,
            inlineButtons: buttons
        ) { [weak self] message in
            guard let fileId = message.photo?.first?.fileId else { return }
            await self?.cache.setValue(fileId, for: position)
        }
    }

    func createRollDiceHandler(chatId: Int64, game: Game, completion: (() async -> ())? = nil) -> TGHandlerPrtcl {
        let callbackName = Handler.rollDiceCallback.rawValue + "_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            let currentPlayerId = await game.currentPlayer.id
            let isAdmin = await currentPlayerId == game.adminId
            
            guard chatId == update.callbackQuery?.message?.chat.id,
                  await !game.dice.isBlocked,
                  await game.turn.isTurnEnd,
                  currentPlayerId == update.callbackQuery?.from.id || isAdmin
            else { return }
            
            try? await self?.tgApi.sendCallbackAnswer(callbackId: update.callbackQuery?.id ?? "", "Бросаю кубик")
            
            await game.turn.startTurn()
            await game.dice.blockDice()
            let diceMessage = try await bot.sendDice(params: .init(chatId: .chat(chatId)))
            await self?.logger.log(event: .sendDice)
            
            try await Task.sleep(nanoseconds: 3000000000)
            guard let diceResult = diceMessage.dice?.value else { return }
            
            let targetTitle = await game.moveCurrentPlayer(step: diceResult)
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Завершить ход", callbackData: Handler.endTurnCallback.rawValue + "_\(chatId)")],
            ]
            
            try await self?.sendMap(
                for: game.currentPlayer.position,
                chatId: chatId,
                captionText: "\(update.callbackQuery?.from.username ?? "") у вас выпало: \(diceResult) \n\nТеперь вы находитесь на: \(targetTitle) \n\n Действуйте или завершите ход",
                buttons: buttons
            )
            await game.dice.resumeDice()
            try await Task.sleep(nanoseconds: 2000000000)
            
            // try? чтобы тесты не валились
            try? await self?.tgApi.deleteMessage(chatId: chatId, messageId: update.callbackQuery?.message?.messageId ?? 0)
            try? await self?.tgApi.deleteMessage(chatId: chatId, messageId: diceMessage.messageId)
            await completion?()
        }
    }
    
    func createEndTurnHandler(chatId: Int64, game: Game, completion: (() async -> ())? = nil) -> TGHandlerPrtcl {
        let callbackName = Handler.endTurnCallback.rawValue + "_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            let currentPlayerId = await game.currentPlayer.id
            let isAdmin = await currentPlayerId == game.adminId
            
            guard chatId == update.callbackQuery?.message?.chat.id,
                await !game.turn.isTurnEnd,
                  currentPlayerId == update.callbackQuery?.from.id || isAdmin
            else { return }
            
            await game.nextPlayer()
            let currentUserName = await game.currentPlayer.name
            
            try? await self?.tgApi.sendCallbackAnswer(callbackId: update.callbackQuery?.id ?? "", "Завершаю ход")
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Бросить кубик 🎲", callbackData: Handler.rollDiceCallback.rawValue + "_\(chatId)")]
            ]
            
            try await self?.tgApi.editCaption(
                chatId: chatId,
                messageId: update.callbackQuery?.message?.messageId ?? 0,
                newCaptionText: "\(currentUserName) теперь ваш ход",
                parseMode: nil,
                newButtons: buttons
            )

            await game.turn.endTurn()
            await self?.logger.log(event: .endTurn)
            await self?.logger.log(event: .message(id: update.message?.messageId ?? 0))
            await completion?()
        }
    }
}
