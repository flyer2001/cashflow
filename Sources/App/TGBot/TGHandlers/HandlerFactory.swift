import TelegramVaporBot

enum HandlerFactoryError: Error {
    case chatIdNotFound
}

final class HandlerFactory {
    enum Handler: String {
        case playCommandHandler
        case restartPlayCommandHandler
        case rollDiceCommandHandler
        case kickCommandHandler
        case addPlayerMenuCallback
        case joingToGameCallback
        case startGameCallback
        case rulesCallback
        case resumeCallback
        case rollDiceCallback
        case rollDiceCheckConflictCallback
        case passTurnCallback
        case endTurnCallback
        case chooseSmallDealsCallback
        case chooseBigDealsCallback
        case acceptCharityCallback
        case declineCharityCallback
        // Onboarding
        case onboardingCommandHandler
        case nextOnboardingCallback
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
    
    func createOnboardingHandler(_ completion: @escaping (_ chatId: Int64) async throws -> ()) -> TGHandlerPrtcl {
        TGCommandHandler(
            name: Handler.onboardingCommandHandler.rawValue,
            commands: ["/onboarding", "/onboarding@cashflow_game_ru_bot"]
        ) { update, bot in
            guard
                let chatId = update.message?.chat.id
            else {
                throw HandlerFactoryError.chatIdNotFound
            }
            
            try await completion(chatId)
        }
    }
    
    func createNextStepHandler(
        chatId: Int64,
        onboarding: Onboarding,
        key: String,
        nextStepPrepareCompletion: ((_ keys: [String]) async -> ())?
    ) -> TGHandlerPrtcl {
        let callbackName = "\(Handler.nextOnboardingCallback.rawValue)_\(chatId)_\(key)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            guard
                let self = self,
                chatId == update.callbackQuery?.message?.chat.id
            else { return }
            
            if let previousMessage = await onboarding.currentMessage {
                try? await self.removeButtonFromCaptionOrTextMessage(in: previousMessage, chatId: chatId)
            }
            
            await onboarding.moveTo(key: key)
            await self.sendOnboardingMessage(chatId: chatId, onboarding: onboarding, key: key, nextStepPrepareCompletion: nextStepPrepareCompletion)
        }
    }
    
    func sendOnboardingMessage(
        chatId: Int64,
        onboarding: Onboarding,
        key: String,
        nextStepPrepareCompletion: ((_ keys: [String]) async -> ())?
    ) async {
        let nextStepsButtons = await onboarding.nextStepsButtons()
        let nextButtons: [[TGInlineKeyboardButton]]? = nextStepsButtons.isEmpty
        ? nil
        : [nextStepsButtons.map {
            .init(
                text: $0.buttonName,
                callbackData: "\(Handler.nextOnboardingCallback.rawValue)_\(chatId)_\($0.key)")
        }]
        
        let keys = nextStepsButtons.map { $0.key }
        
        let isNextLast = await onboarding.isNextLast()
        
        if let item = await onboarding.show() {
            var nextButton: [[TGInlineKeyboardButton]]? {
                isNextLast
                ? nil
                : nextButtons
            }
            
            let onboardingShowMessageCompletion: (TGMessage) async -> () = { message in
                await onboarding.setCurrentMessage(message)
                if isNextLast {
                    await onboarding.endCompletion?()
                }
            }
            
            switch item.content {
            case .text(let text):
                try? await tgApi.sendMessage(
                    chatId: chatId,
                    text: text,
                    inlineButtons: nextButtons,
                    completion:onboardingShowMessageCompletion
                )
            case .video(let url, let captionText):
                try? await tgApi.sendVideo(
                    chatId: chatId,
                    captionText: captionText,
                    inlineButtons: nextButtons,
                    videoUrl: url,
                    completion: onboardingShowMessageCompletion
                )
            case .image(let url, let captionText):
                try? await tgApi.sendPhoto(
                    chatId: chatId,
                    captionText: captionText,
                    photoUrl: url,
                    inlineButtons: nextButtons,
                    completion: onboardingShowMessageCompletion
                )
            }
        }
        await nextStepPrepareCompletion?(keys)
    }

    func createDefaultPlayHandler(startGameCompletion: @escaping (_ chatId: Int64, _ userId: Int64) async throws -> ()) throws -> TGHandlerPrtcl {
        TGCommandHandler(
            name: Handler.playCommandHandler.rawValue,
            commands: ["/play", "/play@cashflow_game_ru_bot"]
        ) { update, bot in
            guard
                let chatId = update.message?.chat.id,
                let userId = update.message?.from?.id
            else {
                throw HandlerFactoryError.chatIdNotFound
            }
            try await startGameCompletion(chatId, userId)
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
    
    func createKickCommandHandler(game: Game, chatId: Int64) -> TGHandlerPrtcl {
        TGCommandHandler(
            name: Handler.kickCommandHandler.rawValue,
            commands: ["/kick", "/kick@cashflow_game_ru_bot"]
        ) { [weak self] update, bot in
            let adminId = await game.adminId
            let isAdmin = update.message?.from?.id == adminId
            let isStarted = await game.isStarted
            
            let kickUserName = (update.message?.text ?? "").split(separator: " ").map{ String($0) }.first { $0.hasPrefix("@")}
            let toKickUserPlayer = await game.players.first { $0.name == (kickUserName ?? "@").dropFirst() }
            guard
                isAdmin,
                isStarted,
                chatId == update.message?.chat.id,
                let toKickUserPlayer,
                toKickUserPlayer.id != adminId
            else { return }
            await game.deletePlayer(player: toKickUserPlayer)
            try await self?.tgApi.sendMessage(chatId: chatId, text: "Игрок \(toKickUserPlayer.name) удален из игры")
        }
    }
    
    func addPlayerMenuHandler(chatId: Int64, game: Game) -> TGHandlerPrtcl {
        let callbackName = "\(Handler.addPlayerMenuCallback.rawValue)_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            guard chatId == update.callbackQuery?.message?.chat.id else { return }
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [
                    .init(text: "Присоединиться к игре", callbackData: "\(Handler.joingToGameCallback.rawValue)_\(chatId)"),
                    .init(text: "Начать игру", callbackData: "\(Handler.startGameCallback.rawValue)_\(chatId)")
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
            await game.start()
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
            
            try await self?.removeButtonFromCaptionOrTextMessage(in: update.callbackQuery?.message, chatId: chatId)
            
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
                await captionText = "\(game.currentPlayer.name) у вас выпало: \(diceResult) \n\nТеперь вы находитесь на: \(targetCell.rawValue) \n\nВыберите крупную или мелкую сделку:"
                nextStepButtons = [
                    [.init(text: "Мелкие сделки", callbackData: Handler.chooseSmallDealsCallback.rawValue + "_\(chatId)"),
                     .init(text: "Крупные сделки", callbackData: Handler.chooseBigDealsCallback.rawValue + "_\(chatId)")
                    ],
                ]
            } else if case BoardCell.charityAcquaintance = targetCell {
                await game.turn.startCharitySelection()
                await captionText = "\(game.currentPlayer.name) у вас выпало: \(diceResult) \n\n\(targetCell.description)"
                nextStepButtons = [
                    [.init(text: "Участвовать", callbackData: Handler.acceptCharityCallback.rawValue + "_\(chatId)"),
                     .init(text: "Отказаться", callbackData: Handler.declineCharityCallback.rawValue + "_\(chatId)")
                    ],
                ]
            } else {
                let card = try await game.popDeck(cell: targetCell)
                let cardText = card.isEmpty ? "" : "\n\n\(card)"
                let descriptionText = targetCell.description.isEmpty ? "" : "\n\n\(targetCell.description)"
                await captionText = "\(game.currentPlayer.name) у вас выпало: \(diceResult) \n\nТеперь вы находитесь на: \(targetCell.rawValue) \(descriptionText) \(cardText) \n\nДействуйте или завершите ход"
                
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
            guard let self = self else { return }
            let currentPlayerId = await game.currentPlayer.id
            let isAdmin = await update.callbackQuery?.from.id == game.adminId
            
            guard
                chatId == update.callbackQuery?.message?.chat.id,
                await !game.turn.isTurnEnd,
                currentPlayerId == update.callbackQuery?.from.id || isAdmin
            else { return }
            
            if await game.charityBoostIfAvailable() {
                try await tgApi.sendMessage(chatId: chatId, text: "Благодаря вашей щедрости, у вас есть возможность ускориться и сделать дополнительный ход. Вы можете бросить кубик еще \(game.currentPlayer.charityBoostCount) раз")
            } else {
                await game.nextPlayer()
            }
            
            guard try await self.checkStatePlayer(game: game, chatId: chatId) else { return }
                
            let currentUserName = await game.currentPlayer.name
            
            try? await self.tgApi.sendCallbackAnswer(callbackId: update.callbackQuery?.id ?? "", "Завершаю ход")
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(
                    text: "Пропустить ход",
                    callbackData: Handler.passTurnCallback.rawValue + "_\(chatId)"
                )],
                [.init(
                    text: "Бросить кубик 🎲",
                    callbackData: Handler.rollDiceCallback.rawValue + "_\(chatId)"
                 )]
            ]
            
            try await self.removeButtonFromCaptionOrTextMessage(in: update.callbackQuery?.message, chatId: chatId)
            
            try await sendMap(
                for: game.currentPlayer.position,
                chatId: chatId,
                captionText: "\(currentUserName), вы находитесь тут",
                buttons: nil
            )
            
            try await self.tgApi.sendMessage(
                chatId: chatId,
                text: "\(currentUserName) теперь ваш ход",
                inlineButtons: buttons
            )

            await game.turn.endTurn()
            await self.logger.log(event: .endTurn)
            await self.logger.log(event: .message(id: update.message?.messageId ?? 0))
            await completion?()
        }
    }
    
    func createRollDiceCheckConflictHandler(chatId: Int64, game: Game) -> TGHandlerPrtcl {
        let callbackName = Handler.rollDiceCheckConflictCallback.rawValue + "_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            let currentPlayerId = await game.currentPlayer.id
            let isAdmin = await update.callbackQuery?.from.id == game.adminId
            
            guard chatId == update.callbackQuery?.message?.chat.id,
                  await !game.dice.isBlocked,
                  currentPlayerId == update.callbackQuery?.from.id || isAdmin
            else { return }
            
            try await self?.removeButtonFromCaptionOrTextMessage(in: update.callbackQuery?.message, chatId: chatId)
            
            try? await self?.tgApi.sendCallbackAnswer(callbackId: update.callbackQuery?.id ?? "", "Бросаю кубик")
            
            await game.dice.blockDice()
            let diceMessage = try await bot.sendDice(params: .init(chatId: .chat(chatId)))
            await self?.logger.log(event: .sendDice)
            
            try await Task.sleep(nanoseconds: 3000000000)
            guard let diceResult = diceMessage.dice?.value else { return }

            let currentVariant = 4 - (await game.currentPlayer.conflictOptionsCount)
            let message: String
            let isResumeGame: Bool
            if await game.isResolveConflict(dice: diceResult) {
                message = "Поздравляем! Вы разрешили конфликт, с помощью варианта \(currentVariant)! Внесите в свою таблицу удвоенный доход! И продолжайте игру."
                isResumeGame = true
            } else if await game.currentPlayer.conflictOptionsCount > 0 {
                message = "Увы, ваш партнер не согласен с вами. Конфликт не разрешен. Попробуйте вариант \(currentVariant + 1)"
                isResumeGame = false
            } else {
                message = "Увы...конфликт не разрешен. Вы не получаете доход. Продолжайте ход."
                isResumeGame = true
            }
            let buttons: [[TGInlineKeyboardButton]] = isResumeGame
            ? [
                [.init(
                    text: "Пропустить ход",
                    callbackData: Handler.passTurnCallback.rawValue + "_\(chatId)"
                )],
                [.init(
                    text: "Бросить кубик 🎲",
                    callbackData: Handler.rollDiceCallback.rawValue + "_\(chatId)"
                 )]
            ]
            : [[.init(
                text: "Разрешить конфликт 🎲",
                callbackData: Handler.rollDiceCheckConflictCallback.rawValue + "_\(chatId)"
            )]]
            if isResumeGame { await game.turn.endTurn() }
            try await self?.tgApi.sendMessage(chatId: chatId, text: message, inlineButtons: buttons)
            await game.dice.resumeDice()
        }
    }
    func acceptCharityHandler(chatId: Int64, game: Game) -> TGHandlerPrtcl {
        let callbackName = Handler.acceptCharityCallback.rawValue + "_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            let currentPlayerId = await game.currentPlayer.id
            let touchButtonPlayerId = update.callbackQuery?.from.id
            let isAdmin = await touchButtonPlayerId == game.adminId
            
            guard
                chatId == update.callbackQuery?.message?.chat.id,
                await !game.turn.isTurnEnd,
                currentPlayerId == touchButtonPlayerId || isAdmin,
                await !game.turn.isCharitySelectionComplete
            else { return }
            try await self?.removeButtonFromCaptionOrTextMessage(in: update.callbackQuery?.message, chatId: chatId)
            await game.takeCharityBoost()
            await game.turn.stopCharitySelection()
            
            let card = await game.popMeetingDeck()
            let text = "Отлично! Передайте 10% своего дохода в фонд, кидайте кубик 3 раза при следующем ходе. \n\nА так же у вас выпала уникальная возможность поближе познакомиться с партнером, уделите 3-5 минут времени, чтобы совместно обсудить ответ на вопрос ниже. \n\n\(card)"
            let nextStepButtons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Завершить ход", callbackData: Handler.endTurnCallback.rawValue + "_\(chatId)")],
            ]
            
            try await self?.tgApi.sendMessage(
                chatId: chatId,
                text: text,
                inlineButtons: nextStepButtons
            )
            
            await self?.logger.log(event: .popMeetingDeck)
        }
    }
    
    func declineCharityHandler(chatId: Int64, game: Game) -> TGHandlerPrtcl {
        let callbackName = Handler.declineCharityCallback.rawValue + "_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            let currentPlayerId = await game.currentPlayer.id
            let touchButtonPlayerId = update.callbackQuery?.from.id
            let isAdmin = await touchButtonPlayerId == game.adminId
            
            guard
                chatId == update.callbackQuery?.message?.chat.id,
                await !game.turn.isTurnEnd,
                currentPlayerId == touchButtonPlayerId || isAdmin,
                await !game.turn.isCharitySelectionComplete
            else { return }
            try await self?.removeButtonFromCaptionOrTextMessage(in: update.callbackQuery?.message, chatId: chatId)
            await game.declineCharityBoost()
            await game.turn.stopCharitySelection()
            
            let card = await game.popMeetingDeck()
            let text = "Возможно, в другой раз! У вас выпала уникальная возможность поближе познакомиться с партнером, уделите 3-5 минут времени, чтобы совместно обсудить ответ на вопрос на карточке ниже. \n\n\(card)"
            let nextStepButtons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Завершить ход", callbackData: Handler.endTurnCallback.rawValue + "_\(chatId)")],
            ]
            
            try await self?.tgApi.sendMessage(
                chatId: chatId,
                text: text,
                inlineButtons: nextStepButtons
            )
            
            await self?.logger.log(event: .popMeetingDeck)
        }
    }
    
    private func checkStatePlayer(game: Game, chatId: Int64) async throws -> Bool {
        while await game.currentPlayer.isFired {
            await game.countDownFiredMissTurnForCurrentPlayer()
            let additionText = await game.currentPlayer.firedMissTurnCount == 1 ? ". Осталось пропустить еще 1 ход" : ""
            try await tgApi.sendMessage(chatId: chatId, text: "\(game.currentPlayer.name) пропускает ход" + additionText)
            await game.nextPlayer()
        }
        
        if await game.currentPlayer.isConflict {
            let text = "\(await game.currentPlayer.name) напомним ваш конфликт \n\n\(await game.currentPlayer.conflictReminder ?? "") \n\nПроверим первый вариант. Бросайте кубик"
            
            let buttons: [[TGInlineKeyboardButton]] = [[.init(
                text: "Разрешить конфликт 🎲",
                callbackData: Handler.rollDiceCheckConflictCallback.rawValue + "_\(chatId)"
            )]]
            try await tgApi.sendMessage(chatId: chatId, text: text, inlineButtons: buttons)
            return false
        }
        return true
    }
    
    private func removeButtonFromCaptionOrTextMessage(in message: TGMessage?, chatId: Int64) async throws {
        if let captionText = message?.caption {
            try await tgApi.editCaption(
                chatId: chatId,
                messageId: message?.messageId ?? 0,
                newCaptionText: captionText,
                parseMode: nil,
                newButtons: nil
            )
        }
        
        if let text = message?.text {
            try? await tgApi.editMessage(
                chatId: chatId,
                messageId: message?.messageId ?? 0,
                newText: text,
                newButtons: nil
            )
        }
    }
    
    func createPassTurnCallbackHandler(chatId: Int64, game: Game) -> TGHandlerPrtcl {
        let callbackName = Handler.passTurnCallback.rawValue + "_\(chatId)"
        return TGCallbackQueryHandler(name: callbackName, pattern: callbackName) { [weak self] update, bot in
            guard let self = self else { return }
            let currentPlayerId = await game.currentPlayer.id
            let touchButtonPlayerId = update.callbackQuery?.from.id
            let isAdmin = await touchButtonPlayerId == game.adminId
            
            guard
                chatId == update.callbackQuery?.message?.chat.id,
                //await !game.turn.isTurnEnd,
                currentPlayerId == update.callbackQuery?.from.id || isAdmin
            else { return }
            
            await game.nextPlayer()
            guard try await self.checkStatePlayer(game: game, chatId: chatId) else { return }
            let currentUserName = await game.currentPlayer.name
            
            try? await self.tgApi.sendCallbackAnswer(callbackId: update.callbackQuery?.id ?? "", "Завершаю ход")
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(
                    text: "Пропустить ход",
                    callbackData: Handler.passTurnCallback.rawValue + "_\(chatId)"
                )],
                [.init(
                    text: "Бросить кубик 🎲",
                    callbackData: Handler.rollDiceCallback.rawValue + "_\(chatId)"
                 )]
            ]
            try await self.removeButtonFromCaptionOrTextMessage(in: update.callbackQuery?.message, chatId: chatId)
            
            try await self.tgApi.sendMessage(
                chatId: chatId,
                text: "\(currentUserName) теперь ваш ход",
                inlineButtons: buttons
            )
            
            await game.turn.endTurn()
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
            let text = "\(card) \n\nДействуйте или завершите ход"
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
