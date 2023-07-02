import Vapor
import TelegramVaporBot
import ChatGPTSwift

actor State {
    var isDialog = true
    
    func stopDialog() {
        isDialog = false
    }
}

final class DefaultBotHandlers {

    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await startHandler(app: app, connection: connection)
    }
    
    private static func startHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGMessageHandler(filters: (.command.names(["/start"]))) { update, bot in
            guard let message = update.message,
            message.from?.id == 566335622
            else { return }
            let params: TGSendMessageParams = .init(chatId: .chat(message.chat.id), text: "Добро пожаловать, создатель. Обработчики подгружены...")
            try await connection.bot.sendMessage(params: params)
            await messageHandler(app: app, connection: connection)
        })
    }

    private static func messageHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        let state = State()
        await connection.dispatcher.add(
            TGMessageHandler(filters: (.all && !.command.names(["/exit"]))) { update, bot in
                guard await state.isDialog else { return }
                let params: TGSendMessageParams = .init(chatId: .chat(update.message!.chat.id), text: "ну что лупа")
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

    private static func commandShowButtonsHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/show_buttons"]) { update, bot in
            guard let userId = update.message?.from?.id else { fatalError("user id not found") }
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Button 1", callbackData: "press 1"), .init(text: "Button 2", callbackData: "press 2")]
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(userId),
                                                    text: "Keyboard active",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))
            try await connection.bot.sendMessage(params: params)
        })
    }

    private static func buttonsActionHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "press 1") { update, bot in
            let params: TGAnswerCallbackQueryParams = .init(callbackQueryId: update.callbackQuery?.id ?? "0",
                                                            text: update.callbackQuery?.data  ?? "data not exist",
                                                            showAlert: nil,
                                                            url: nil,
                                                            cacheTime: nil)
            try await bot.answerCallbackQuery(params: params)
        })
        
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "press 2") { update, bot in
            let params: TGAnswerCallbackQueryParams = .init(callbackQueryId: update.callbackQuery?.id ?? "0",
                                                            text: update.callbackQuery?.data  ?? "data not exist",
                                                            showAlert: nil,
                                                            url: nil,
                                                            cacheTime: nil)
            try await bot.answerCallbackQuery(params: params)
        })
    }
}

