import Vapor
import TelegramVaporBot
import ChatGPTSwift

final class HandlerFactory {
    
    static func createPlayHandler(game: Game) -> TGHandlerPrtcl {
        TGCommandHandler(name: "playHandler", commands: ["/play"]) { update, bot in
            guard let chatId = update.message?.chat.id else { fatalError("user id not found") }
            await game.reset()
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Бросить кубик 🎲", callbackData: "dice")]
            ]
            
            try await sendMap(
                for: game.currentPlayerPosition,
                chatId: chatId,
                captionText: "Ваш ход",
                parseMode: nil,
                buttons: buttons
            )
        }
    }
    
    private static func sendMap(
        for position: Int,
        chatId: Int64,
        captionText: String?,
        parseMode: TGParseMode?,
        buttons: [[TGInlineKeyboardButton]]?) async throws {
            if let fileId = await App.cache.getValue(for: position) {
                try await App.sendPhotoFromCache(
                    chatId: chatId,
                    fileId: fileId,
                    captionText: captionText,
                    parseMode: parseMode,
                    buttons: buttons) 
                return
            }
            
            let outputImageData = try await MapDrawer.drawMap(for: position)
            
            try await App.sendPhoto(
                chatId: chatId,
                captionText: captionText,
                parseMode: parseMode,
                photoData: outputImageData,
                inlineButtons: buttons
            ) { message in
                guard let fileId = message.photo?.first?.fileId else { return }
                await App.cache.setValue(fileId, for: position)
            }
        }


    static func createButtonActionHandler(game: Game) -> TGHandlerPrtcl {
        TGCallbackQueryHandler(name: "dice", pattern: "dice") { update, bot in
            guard let chatId = update.callbackQuery?.message?.chat.id,
                  await !game.dice.isBlocked,
                  await game.turn.isTurnEnd
            else { return }
            
            await game.turn.startTurn()
            await game.dice.blockDice()
            let diceMessage = try await bot.sendDice(params: .init(chatId: .chat(chatId)))
            await App.logger.log(event: .sendDice)
            
            try await Task.sleep(nanoseconds: 3000000000)
            guard let diceResult = diceMessage.dice?.value else { return }
            
            let targetTitle = await game.move(step: diceResult)
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Завершить ход", callbackData: "endTurn")],
            ]
            
            try await sendMap(
                for: game.currentPlayerPosition,
                chatId: chatId,
                captionText: "*Выпало:* \(diceResult) \n\n*Теперь вы находитесь на*: \(targetTitle) \n\n Действуйте или завершите ход",
                parseMode: .markdownV2,
                buttons: buttons
            )
            await game.dice.resumeDice()
            try await Task.sleep(nanoseconds: 2000000000)
            try await App.deleteMessage(chatId: chatId, messageId: update.callbackQuery?.message?.messageId ?? 0)
            try await App.deleteMessage(chatId: chatId, messageId: diceMessage.messageId)
        }
    }
    
    static func createEndTurnHandler(game: Game) -> TGHandlerPrtcl {
        TGCallbackQueryHandler(pattern: "endTurn") { update, bot in
            guard let chatId = update.callbackQuery?.message?.chat.id,
                await !game.turn.isTurnEnd
            else { return }
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Бросить кубик 🎲", callbackData: "dice")]
            ]
            
            try await App.editCaption(
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

final class DefaultBotHandlers {
    
    static func addHandlers() async {
        await startHandler()
        await playHandler()
    }
    
    private static func startHandler() async {
        await App.dispatcher.add(TGMessageHandler(filters: (.command.names(["/start"]))) { update, bot in
            guard let message = update.message else { return }
            let state = DialogState()
            let params: TGSendMessageParams
            if message.from?.id == 566335622,
               message.chat.type == .private,
               await !state.isDialog
            {
                params = TGSendMessageParams(chatId: .chat(message.chat.id), text: "Добро пожаловать, создатель. Обработчики подгружены. Далее отвечать будет ChatGPTBot")
                await messageHandler(state: state)
            } else {
                params = TGSendMessageParams(chatId: .chat(message.chat.id), text: "Для начала игры наберите /play")
            }
            
            try await App.bot.sendMessage(params: params)
        })
    }
    
    private static func messageHandler(state: DialogState) async {
        await state.startDialog()
        await App.dispatcher.add(
            TGMessageHandler(filters: (.all && !.command.names(["/exit"]))) { update, bot in
                guard
                    await state.isDialog,
                    let textFromUser = update.message?.text
                else { return }
                let api = ChatGPTAPI(apiKey: "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")
                let gptAnswer = try await api.sendMessage(
                    text: textFromUser
                )
                
                let params: TGSendMessageParams = .init(chatId: .chat(update.message!.chat.id), text: gptAnswer)
                try await App.bot.sendMessage(params: params)
            }
        )
        await App.dispatcher.add(TGMessageHandler(filters: (.command.names(["/exit"]))) { update, bot in
            guard await state.isDialog else { return }
            await state.stopDialog()
            let params: TGSendMessageParams = .init(chatId: .chat(update.message!.chat.id), text: "выход")
            try await App.bot.sendMessage(params: params)
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
    }
}

