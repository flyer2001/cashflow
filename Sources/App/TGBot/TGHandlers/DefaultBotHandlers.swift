import Vapor
import TelegramVaporBot
import ChatGPTSwift

final class HandlerFactory {
    
    static func createPlayHandler(game: Game, completion: ((String) -> ())? = nil) -> TGHandlerPrtcl {
        TGCommandHandler(name: "playHandler", commands: ["/play"]) { update, bot in
            guard let chatId = update.message?.chat.id else { fatalError("user id not found") }
            await game.reset()
            
            await sendMapFromCache(
                for: game.currentPlayerPosition,
                chatId: update.message?.chat.id ?? 0,
                completion: completion
            )
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Бросить кубик 🎲", callbackData: "dice")]
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(chatId),
                                                    text: "Ваш ход",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))

            try await App.bot.sendMessage(params: params)
        }
    }
    
    static func createButtonActionHandler(game: Game, completion: ((String) -> ())? = nil) -> TGHandlerPrtcl {
        TGCallbackQueryHandler(name: "dice", pattern: "dice") { update, bot in
            guard let chatId = update.callbackQuery?.message?.chat.id,
                  await !game.dice.isBlocked,
                  await game.turn.isTurnEnd
            else { return }
            
            await game.turn.startTurn()
            await game.dice.blockDice()
            let diceMessage = try await bot.sendDice(params: .init(chatId: .chat(chatId)))
            completion?("Жребий брошен")
            try await Task.sleep(nanoseconds: 3000000000)
            guard let diceResult = diceMessage.dice?.value else { return }
            let targetTitle = await game.move(step: diceResult)
            try await bot.sendMessage(params: .init(
                chatId: .chat(chatId),
                text: "*Выпало:* \(diceResult) \n*Теперь вы находитесь на*: \(targetTitle)",
                parseMode: .markdownV2)
            )
            await sendMapFromCache(for: game.currentPlayerPosition, chatId: chatId, completion: completion)
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Завершить ход", callbackData: "endTurn")],
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(chatId),
                                                    text: "Действуйте или завершите ход",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))
            

            completion?("Сообщение пользователю")
            let message = try await App.bot.sendMessage(params: params)
            await game.dice.resumeDice()
        }
    }
    
    static func createEndTurnHandler(game: Game, completion: ((String) -> ())? = nil) -> TGHandlerPrtcl {
        TGCallbackQueryHandler(pattern: "endTurn") { update, bot in
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Бросить кубик 🎲", callbackData: "dice")]
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let editParams: TGEditMessageTextParams = .init(chatId: .chat(update.callbackQuery?.message?.chat.id ?? 0), messageId: update.callbackQuery?.message?.messageId, text: "Ваш ход", replyMarkup: keyboard)
            try await App.bot.editMessageText(params: editParams)
            completion?("Сообщение пользователю")
            
            await game.turn.endTurn()
        }
    }
    
    private static func sendMapFromCache(for position: Int, chatId: Int64, completion: ((String) -> ())?) async {
        completion?("Карта отправлена")
        guard let fileId = await App.cache.getValue(for: position) else {
            try? await sendMap(for: position, chatId: chatId)
            return
        }
        let photo = TGFileInfo.fileId(fileId)
        
        do {
            try await App.bot.sendPhoto(params: TGSendPhotoParams(chatId: .chat(chatId), photo: photo))
        } catch {
            try? await sendMap(for: position, chatId: chatId)
        }
    }
    
    private static func sendMap(for position: Int, chatId: Int64) async throws {
    
        let outputImageData = try await MapDrawer.drawMap(for: position)
           
        let photo = TGFileInfo.file(.init(filename: "rat_ring", data: outputImageData))
        
        let params = TGSendPhotoParams(chatId: .chat(chatId), photo: photo)
        if let message = try? await App.bot.sendPhoto(params: params),
           let fileId = message.photo?.first?.fileId {
            await App.cache.setValue(fileId, for: position)
        }
    }
}

final class DefaultBotHandlers {
    
    static func addHandlers() async {
        await startHandler()
        await playHandler()
    }
    
    private static func startHandler() async {
        await App.dispatcher.add(TGMessageHandler(filters: (.command.names(["/start"]))) { update, bot in
            guard let message = update.message else { return }
            
            let params: TGSendMessageParams
            if message.from?.id == 566335622, message.chat.type == .private {
                params = TGSendMessageParams(chatId: .chat(message.chat.id), text: "Добро пожаловать, создатель. Обработчики подгружены. Далее отвечать будет ChatGPTBot")
                await messageHandler()
            } else {
                params = TGSendMessageParams(chatId: .chat(message.chat.id), text: "Для начала игры наберите /play")
            }
            
            try await App.bot.sendMessage(params: params)
        })
    }
    
    private static func messageHandler() async {
        let state = DialogState()
        await App.dispatcher.add(
            TGMessageHandler(filters: (.all && !.command.names(["/exit"]))) { update, bot in
                guard
                    await state.isDialog,
                    let textFromUser = update.message?.text
                else { return }
                let api = ChatGPTAPI(apiKey: "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")
                let gptAnswer = try await api.sendMessage(text: textFromUser)
                
                let params: TGSendMessageParams = .init(chatId: .chat(update.message!.chat.id), text: gptAnswer, parseMode: .markdownV2)
                try await App.bot.sendMessage(params: params)
            }
        )
        await App.dispatcher.add(TGMessageHandler(filters: (.command.names(["/exit"]))) { update, bot in
            await state.stopDialog()
            let params: TGSendMessageParams = .init(chatId: .chat(update.message!.chat.id), text: "выход")
            try await App.bot.sendMessage(params: params)
        })
        
    }
    
    private static func commandPingHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/ping"]) { update, bot in
            try await update.message?.reply(text: "pong", bot: bot)
        })
    }
    
    private static func playHandler() async {
        let game = Game()
        await buttonsActionHandler(game: game)
        
        await App.dispatcher.add(HandlerFactory.createPlayHandler(game: game))
    }
    
    
    private static func buttonsActionHandler(game: Game) async {
        await App.dispatcher.add(HandlerFactory.createButtonActionHandler(game: game))
        
        await App.dispatcher.add(HandlerFactory.createEndTurnHandler(game: game))
        
        await App.dispatcher.add(TGCallbackQueryHandler(pattern: "repay") { update, bot in
            let params: TGAnswerCallbackQueryParams = .init(callbackQueryId: update.callbackQuery?.id ?? "0",
                                                            text: "Menu",
                                                            showAlert: nil,
                                                            url: nil,
                                                            cacheTime: nil)
            try await bot.answerCallbackQuery(params: params)
        })
    }
}

