import Vapor
import TelegramVaporBot
import ChatGPTSwift
import Swim

actor State {
    var isDialog = true
    
    func stopDialog() {
        isDialog = false
    }
}

actor Game {
    
    static func rollDice(numberOfDice: Int = 1) -> Int {
        var result = 0
        
        for _ in 1...numberOfDice {
            let diceRoll = Int.random(in: 1...6)
            result += diceRoll
        }
        
        return result
    }
}

final class DefaultBotHandlers {
    
    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await startHandler(app: app, connection: connection)
        await playHandler(app: app, connection: connection)
        await photoHandler(app: app, connection: connection)
    }
    
    private static func startHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGMessageHandler(filters: (.command.names(["/start"]))) { update, bot in
            guard let message = update.message else { return }
            
            let params: TGSendMessageParams
            if message.from?.id == 566335622 {
                params = TGSendMessageParams(chatId: .chat(message.chat.id), text: "Добро пожаловать, создатель. Обработчики подгружены. Далее отвечать будет ChatGPTBot")
            } else {
                params = TGSendMessageParams(chatId: .chat(message.chat.id), text: "Для начала игры наберите /play")
            }
            
            try await connection.bot.sendMessage(params: params)
            await messageHandler(app: app, connection: connection)
        })
    }
    
    private static func messageHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        let state = State()
        await connection.dispatcher.add(
            TGMessageHandler(filters: (.all && !.command.names(["/exit"]))) { update, bot in
                guard
                    await state.isDialog,
                    let textFromUser = update.message?.text
                else { return }
                let api = ChatGPTAPI(apiKey: "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")
                let gptAnswer = try await api.sendMessage(text: textFromUser)
                
                let params: TGSendMessageParams = .init(chatId: .chat(update.message!.chat.id), text: gptAnswer)
                try await connection.bot.sendMessage(params: params)
            }
        )
        await connection.dispatcher.add(TGMessageHandler(filters: (.command.names(["/exit"]))) { update, bot in
            await state.stopDialog()
            let params: TGSendMessageParams = .init(chatId: .chat(update.message!.chat.id), text: "выход")
            try await connection.bot.sendMessage(params: params)
        })
        
    }
    
    private static func commandPingHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/ping"]) { update, bot in
            try await update.message?.reply(text: "pong", bot: bot)
        })
    }
    
    private static func playHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await buttonsActionHandler(app: app, connection: connection)
        await connection.dispatcher.add(TGCommandHandler(commands: ["/play"]) { update, bot in
            guard let userId = update.message?.from?.id else { fatalError("user id not found") }
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Бросить кубик 🎲", callbackData: "dice")],
                [.init(text: "Вернуть долг 💸", callbackData: "borrow")],
                [.init(text: "Взять кредит 💸", callbackData: "repay")]
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(userId),
                                                    text: "Ваш ход",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))
            try await connection.bot.sendMessage(params: params)
        })
    }
    
    private static func photoHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await buttonsActionHandler(app: app, connection: connection)
        await connection.dispatcher.add(TGCommandHandler(commands: ["/photo"]) { update, bot in
            
            let messParams = TGSendMessageParams(chatId: .chat(update.message?.chat.id ?? 0), text: app.directory.publicDirectory + "rat_ring.png")
            try await connection.bot.sendMessage(params: params)
            
            guard let chatId = update.message?.chat.id,
                  let imageData = FileManager.default.contents(atPath: app.directory.publicDirectory + "rat_ring.png")  // для локального теста "/Users/sgpopyvanov/tgbot/Public/rat_ring.png"
            else { return }

            let photo = TGFileInfo.file(.init(filename: "rat_ring", data: imageData))
            
            let params = TGSendPhotoParams(chatId: .chat(chatId), photo: photo)
            try await connection.bot.sendPhoto(params: params)
        })
    }
    
    private static func buttonsActionHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "dice") { update, bot in
            guard let chatId = update.callbackQuery?.message?.chat.id else { return }
            
            let result = Game.rollDice()
            try await bot.sendDice(params: .init(chatId: .chat(chatId)))
            try await bot.sendMessage(params: .init(
                chatId: .chat(chatId),
                text: "*Выпало:* \(result)",
                parseMode: .markdownV2)
            )
        })
        
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "borrow") { update, bot in
            let params: TGAnswerCallbackQueryParams = .init(callbackQueryId: update.callbackQuery?.id ?? "0",
                                                            text: "Menu",
                                                            showAlert: nil,
                                                            url: nil,
                                                            cacheTime: nil)
            try await bot.answerCallbackQuery(params: params)
        })
        
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "repay") { update, bot in
            let params: TGAnswerCallbackQueryParams = .init(callbackQueryId: update.callbackQuery?.id ?? "0",
                                                            text: "Menu",
                                                            showAlert: nil,
                                                            url: nil,
                                                            cacheTime: nil)
            try await bot.answerCallbackQuery(params: params)
        })
    }
    
}

