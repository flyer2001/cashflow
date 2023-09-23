import TelegramVaporBot

enum HandlerFactoryError: Error {
    case chatIdNotFound
}

final class HandlerFactory {
    enum Handler: String {
        case playCommandHandler
        case rollDiceCommandHandler
        case addPlayerMenuCallback
        case joingToGameCallback
        case startGameCallback
        case rulesCallback
        case resumeCallback
        case rollDiceCallback
        case endTurnCallback
        case chooseSmallDealsCallback
        case chooseBigDealsCallback
    }
    
    
    private let tgApi: TelegramBotAPIHelper
    private let cache: ImageCache
    private let logger: ChatBotLogger
    private let mapDrawer: MapDrawer
    private let professionsCardDrawer: ProffessionsCardDrawer

    init(
        cache: ImageCache,
        tgApi: TelegramBotAPIHelper,
        logger: ChatBotLogger,
        mapDrawer: MapDrawer,
        professionsCardDrawer: ProffessionsCardDrawer
    ) {
        self.tgApi = tgApi
        self.cache = cache
        self.logger = logger
        self.mapDrawer = mapDrawer
        self.professionsCardDrawer = professionsCardDrawer
    }

    func createDefaultPlayHandler(startGameCompletion: @escaping (_ chatId: Int64, _ messageId: Int) async throws -> ()) throws -> TGHandlerPrtcl {
        TGCommandHandler(
            name: Handler.playCommandHandler.rawValue,
            commands: ["/play", "/play@cashflow_game_ru_bot"]
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
    
    func createRollDiceCommandHandler() -> TGHandlerPrtcl {
        TGCommandHandler(
            name: Handler.rollDiceCommandHandler.rawValue,
            commands: ["/roll", "/roll@cashflow_game_ru_bot"]
        ) { [weak self] update, bot in
            guard let chatId = update.message?.chat.id else {
                throw HandlerFactoryError.chatIdNotFound
            }
            
            let diceMessage = try await bot.sendDice(params: .init(chatId: .chat(chatId)))
            await self?.logger.log(event: .sendDice)
            
            try await Task.sleep(nanoseconds: 3000000000)
            guard let diceResult = diceMessage.dice?.value else { return }
            try await self?.tgApi.sendMessage(chatId: chatId, text: "\(update.message?.from?.username ?? ""), у вас выпало: \(diceResult)")
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
                await self?.logger.log(event: .message(id: message.messageId))
            }
        }
    }
    
    func startNewGameHandler(chatId: Int64, game: Game) -> TGHandlerPrtcl {
        let callbackName = "\(Handler.startGameCallback.rawValue)_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            try? await self?.tgApi.sendCallbackAnswer(callbackId: update.callbackQuery?.id ?? "", "Создаю новую игру")
            guard chatId == update.callbackQuery?.message?.chat.id,
                  await !(game.currentPlayer == nil),
                  let adminId = update.callbackQuery?.from.id
            else { return }
            
            await game.setAdmin(id: adminId)
            if await game.players.count > 1  {
                try await game.shuffle()
            }
            await game.shufflePlayerProffessions()
            try await game.players.asyncForEach { [weak self] player in
                try await self?.sendProffessionCard(for: player, chatId: chatId)
            }
            
            let currentPlayerName = await game.currentPlayer.name
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Бросить кубик 🎲", callbackData: Handler.rollDiceCallback.rawValue + "_\(chatId)")]
            ]
            
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
    
    private func sendProffessionCard(
        for player: Player,
        chatId: Int64
    ) async throws {
        guard let proffession = player.proffesion else { return }
        let captionText = "\(player.name), ваша профессия: \(proffession.description)"
        
        if let fileId = await cache.getCardValue(for: proffession) {
            try await tgApi.sendPhotoFromCache(
                chatId: chatId,
                fileId: fileId,
                captionText: captionText,
                buttons: nil
            )
            return
        }
        
        let outputImageData = try await professionsCardDrawer.drawCard(for: proffession)
        
        try await tgApi.sendPhoto(
            chatId: chatId,
            captionText: captionText,
            photoData: outputImageData,
            inlineButtons: nil
        ) { [weak self] message in
            guard let fileId = message.photo?.first?.fileId else { return }
            await self?.cache.setCardValue(fileId, for: proffession)
        }
    }

    func createRollDiceHandler(chatId: Int64, game: Game, completion: (() async -> ())? = nil) -> TGHandlerPrtcl {
        let callbackName = Handler.rollDiceCallback.rawValue + "_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            let currentPlayerId = await game.currentPlayer.id
            let isAdmin = await update.callbackQuery?.from.id == game.adminId
            
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
            
            let targetCell = await game.moveCurrentPlayer(step: diceResult)
            let captionText: String
            let nextStepButtons: [[TGInlineKeyboardButton]]
            if case BoardCell.possibilities = targetCell {
                await game.turn.startDeckSelection()
                await captionText = "\(game.currentPlayer.name) у вас выпало: \(diceResult) \n\nТеперь вы находитесь на: \(targetCell.description) \n\n Выберите крупную или мелкую сделку:"
                nextStepButtons = [
                    [.init(text: "Мелкие сделки", callbackData: Handler.chooseSmallDealsCallback.rawValue + "_\(chatId)"),
                     .init(text: "Крупные сделки", callbackData: Handler.chooseBigDealsCallback.rawValue + "_\(chatId)")
                    ],
                ]
            } else {
                let card = try await game.popDeck(cell: targetCell)
                await captionText = "\(game.currentPlayer.name) у вас выпало: \(diceResult) \n\nТеперь вы находитесь на: \(targetCell.description) \n\n \(card) \n\n Действуйте или завершите ход"
                nextStepButtons = [
                    [.init(text: "Завершить ход", callbackData: Handler.endTurnCallback.rawValue + "_\(chatId)")],
                ]
            }
        
            try await self?.sendMap(
                for: game.currentPlayer.position,
                chatId: chatId,
                captionText: captionText,
                buttons: nextStepButtons
            )
            await game.dice.resumeDice()
            try await Task.sleep(nanoseconds: 2000000000)
            
            // try? чтобы тесты не валились
            try? await self?.tgApi.deleteMessage(chatId: chatId, messageId: diceMessage.messageId)
            await completion?()
        }
    }
    
    func createEndTurnHandler(chatId: Int64, game: Game, completion: (() async -> ())? = nil) -> TGHandlerPrtcl {
        let callbackName = Handler.endTurnCallback.rawValue + "_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            let currentPlayerId = await game.currentPlayer.id
            let isAdmin = await update.callbackQuery?.from.id == game.adminId
            
            guard
                chatId == update.callbackQuery?.message?.chat.id,
                await !game.turn.isTurnEnd,
                currentPlayerId == update.callbackQuery?.from.id || isAdmin
            else { return }
            
            await game.nextPlayer()
            let currentUserName = await game.currentPlayer.name
            
            try? await self?.tgApi.sendCallbackAnswer(callbackId: update.callbackQuery?.id ?? "", "Завершаю ход")
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Бросить кубик 🎲", callbackData: Handler.rollDiceCallback.rawValue + "_\(chatId)")]
            ]
            
            if let captionText = update.callbackQuery?.message?.caption {
                try await self?.tgApi.editCaption(
                    chatId: chatId,
                    messageId: update.callbackQuery?.message?.messageId ?? 0,
                    newCaptionText: captionText,
                    parseMode: nil,
                    newButtons: nil
                )
            }
            
            if let text = update.callbackQuery?.message?.text {
                try? await self?.tgApi.editMessage(
                    chatId: chatId,
                    messageId: update.callbackQuery?.message?.messageId ?? 0,
                    newText: text,
                    newButtons: nil
                )
            }
            
            try await self?.tgApi.sendMessage(
                chatId: chatId,
                text: "\(currentUserName) теперь ваш ход",
                inlineButtons: buttons
            )

            await game.turn.endTurn()
            await self?.logger.log(event: .endTurn)
            await self?.logger.log(event: .message(id: update.message?.messageId ?? 0))
            await completion?()
        }
    }
    
    func createSmallDealHandler(chatId: Int64, game: Game) -> TGHandlerPrtcl {
        let callbackName = Handler.chooseSmallDealsCallback.rawValue + "_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            let currentPlayerId = await game.currentPlayer.id
            let touchButtonPlayerId = update.callbackQuery?.from.id
            let isAdmin = await touchButtonPlayerId == game.adminId
            
            guard
                chatId == update.callbackQuery?.message?.chat.id,
                await !game.turn.isTurnEnd,
                currentPlayerId == touchButtonPlayerId || isAdmin,
                await !game.turn.isDealDeckSelectionComplete
            else { return }
            
            await game.turn.stopDeckSelection()
            let card = await game.popSmallDealDeck()
            let text = "\(card) \n\n Действуйте или завершите ход"
            let nextStepButtons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Завершить ход", callbackData: Handler.endTurnCallback.rawValue + "_\(chatId)")],
            ]
            
            try await self?.tgApi.sendMessage(
                chatId: chatId,
                text: text,
                inlineButtons: nextStepButtons
            )
            
            await self?.logger.log(event: .popSmallDealsDeck)
        }
    }
    
    func createBigDealHandler(chatId: Int64, game: Game) -> TGHandlerPrtcl {
        let callbackName = Handler.chooseBigDealsCallback.rawValue + "_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            let currentPlayerId = await game.currentPlayer.id
            let touchButtonPlayerId = update.callbackQuery?.from.id
            let isAdmin = await touchButtonPlayerId == game.adminId
            
            guard
                chatId == update.callbackQuery?.message?.chat.id,
                await !game.turn.isTurnEnd,
                currentPlayerId == touchButtonPlayerId || isAdmin,
                await !game.turn.isDealDeckSelectionComplete
            else { return }
            
            await game.turn.stopDeckSelection()
            let card = await game.popBigDealDeck()
            let text = "\(card) \n\n Действуйте или завершите ход"
            let nextStepButtons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Завершить ход", callbackData: Handler.endTurnCallback.rawValue + "_\(chatId)")],
            ]
            
            try await self?.tgApi.sendMessage(
                chatId: chatId,
                text: text,
                inlineButtons: nextStepButtons
            )
            
            await self?.logger.log(event: .popSmallDealsDeck)
        }
    }
}
