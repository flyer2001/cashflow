import TelegramVaporBot

enum HandlerFactoryError: Error {
    case chatIdNotFound
}

final class HandlerFactory {
    enum Handler: String {
        case playHandler
        case newGameCallback
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

    func createDefaultPlayHandler(startGameCompletion: @escaping (_ chatId: Int64) async -> ()) throws -> TGHandlerPrtcl {
        TGCommandHandler(
            name: Handler.playHandler.rawValue,
            commands: ["/play"]
        ) { [weak self] update, bot in
            guard let chatId = update.message?.chat.id else {
                throw HandlerFactoryError.chatIdNotFound
            }
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [
                    .init(text: "Новая игра", callbackData: "\(Handler.newGameCallback.rawValue)_\(chatId)"),
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
            )
            
            await startGameCompletion(chatId) 
        }
    }
    
    func createNewGameHandler(chatId: Int64, game: Game) -> TGHandlerPrtcl {
        let callbackName = "\(Handler.newGameCallback.rawValue)_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            guard chatId == update.callbackQuery?.message?.chat.id else { return }
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Бросить кубик 🎲", callbackData: Handler.rollDiceCallback.rawValue + "_\(chatId)")]
            ]
            
            try await self?.sendMap(
                for: game.currentPlayerPosition,
                chatId: chatId,
                captionText: "Ваш ход",
                parseMode: nil,
                buttons: buttons
            )
        }
    }
    
    private func sendMap(
        for position: Int,
        chatId: Int64,
        captionText: String?,
        parseMode: TGParseMode?,
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

    func createRollDiceHandler(chatId: Int64, game: Game) -> TGHandlerPrtcl {
        let callbackName = Handler.rollDiceCallback.rawValue + "_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            guard chatId == update.callbackQuery?.message?.chat.id,
                  await !game.dice.isBlocked,
                  await game.turn.isTurnEnd
            else { return }
            
            await game.turn.startTurn()
            await game.dice.blockDice()
            let diceMessage = try await bot.sendDice(params: .init(chatId: .chat(chatId)))
            await self?.logger.log(event: .sendDice)
            
            try await Task.sleep(nanoseconds: 3000000000)
            guard let diceResult = diceMessage.dice?.value else { return }
            
            let targetTitle = await game.move(step: diceResult)
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Завершить ход", callbackData: Handler.endTurnCallback.rawValue + "_\(chatId)")],
            ]
            
            try await self?.sendMap(
                for: game.currentPlayerPosition,
                chatId: chatId,
                captionText: "*Выпало:* \(diceResult) \n\n*Теперь вы находитесь на*: \(targetTitle) \n\n Действуйте или завершите ход",
                parseMode: .markdownV2,
                buttons: buttons
            )
            await game.dice.resumeDice()
            try await Task.sleep(nanoseconds: 2000000000)
            try await self?.tgApi.deleteMessage(chatId: chatId, messageId: update.callbackQuery?.message?.messageId ?? 0)
            try await self?.tgApi.deleteMessage(chatId: chatId, messageId: diceMessage.messageId)
        }
    }
    
    func createEndTurnHandler(chatId: Int64, game: Game) -> TGHandlerPrtcl {
        let callbackName = Handler.endTurnCallback.rawValue + "_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            guard chatId == update.callbackQuery?.message?.chat.id,
                await !game.turn.isTurnEnd
            else { return }
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Бросить кубик 🎲", callbackData: Handler.rollDiceCallback.rawValue + "_\(chatId)")]
            ]
            
            try await self?.tgApi.editCaption(
                chatId: chatId,
                messageId: update.callbackQuery?.message?.messageId ?? 0,
                newCaptionText: "Ваш ход",
                parseMode: nil,
                newButtons: buttons
            )

            await game.turn.endTurn()
        }
    }
}
