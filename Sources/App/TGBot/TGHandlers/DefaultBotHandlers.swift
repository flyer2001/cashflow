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

actor ImageCache {
    private var cache: [Int: String] = [:]
    
    func getValue(for key: Int) -> String? {
        cache[key]
    }
    
    func setValue(_ value: String, for key: Int) {
        cache[key] = value
    }
}

let cache = ImageCache()

let defaultBoard: [String] = [
    "Расчетный чек / Конфликт",
    "Возможности",
    "Рынок",
    "Возможности",
    "Роскошь",
    "Возможности",
    "Увольнение",
    "Возможности",
    "Расчетный чек / Конфликт",
    "Возможности",
    "Рынок",
    "Возможности",
    "Роскошь",
    "Возможности",
    "Благотворительность / Давай познакомимся",
    "Возможности",
    "Расчетный чек / Конфликт",
    "Возможности",
    "Рынок",
    "Возможности",
    "Роскошь",
    "Возможности",
    "Ребенок",
    "Возможности",
]

actor Game {
    let board: [String] = defaultBoard
    var currentPlayerPosition: Int = 9
    let dice = Dice()
    let turn = Turn()
    
    static func rollDice(numberOfDice: Int = 1) -> Int {
        var result = 0
        
        for _ in 1...numberOfDice {
            let diceRoll = Int.random(in: 1...6)
            result += diceRoll
        }
        
        return result
    }
    
    func move(step: Int) -> String {
        currentPlayerPosition += step
        if currentPlayerPosition >= board.count {
            currentPlayerPosition %= board.count
        }
        return board[currentPlayerPosition]
    }
    
    func reset() {
        currentPlayerPosition = 9
    }
}

actor Dice {
    var isBlocked = false
    
    func blockDice() {
        isBlocked = true
    }
    
    func resumeDice() {
        isBlocked = false
    }
}

actor Turn {
    var isTurnEnd = true
    
    func startTurn() {
        isTurnEnd = false
    }
    
    func endTurn() {
        isTurnEnd = true
    }
}

final class HandlerFactory {
    
    static func createPlayHandler(app: Vapor.Application, connection: TGConnectionPrtcl, game: Game, completion: ((String) -> ())? = nil) -> TGHandlerPrtcl {
        TGCommandHandler(name: "playHandler", commands: ["/play"]) { update, bot in
            guard let userId = update.message?.from?.id else { fatalError("user id not found") }
            await game.reset()
            
            await sendMapFromCache(for: game.currentPlayerPosition, chatId: update.message?.chat.id ?? 0,app: app, connection: connection, completion: completion)
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Бросить кубик 🎲", callbackData: "dice")]
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(userId),
                                                    text: "Ваш ход",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))
            completion?("Сообщение пользователю")
            try await connection.bot.sendMessage(params: params)
        }
    }
    
    static func createButtonActionHandler(app: Vapor.Application, connection: TGConnectionPrtcl, game: Game, completion: ((String) -> ())? = nil) -> TGHandlerPrtcl {
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
            await sendMapFromCache(for: game.currentPlayerPosition, chatId: chatId, app: app, connection: connection, completion: completion)
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Завершить ход", callbackData: "endTurn")],
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(update.callbackQuery?.from.id ?? 0),
                                                    text: "Действуйте или завершите ход",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))
            

            completion?("Сообщение пользователю")
            try await connection.bot.sendMessage(params: params)
            await game.dice.resumeDice()
        }
    }
    
    static func createEndTurnHandler(app: Vapor.Application, connection: TGConnectionPrtcl, game: Game, completion: ((String) -> ())? = nil) -> TGHandlerPrtcl{
        TGCallbackQueryHandler(pattern: "endTurn") { update, bot in
            
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Бросить кубик 🎲", callbackData: "dice")]
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(update.callbackQuery?.from.id ?? 0),
                                                    text: "Ваш ход:",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))

            completion?("Сообщение пользователю")
            try await connection.bot.sendMessage(params: params)
            
            await game.turn.endTurn()
        }
    }
    
    private static func sendMapFromCache(for position: Int, chatId: Int64, app: Vapor.Application, connection: TGConnectionPrtcl, completion: ((String) -> ())?) async {
        completion?("Карта отправлена")
        guard let fileId = await cache.getValue(for: position) else {
            await sendMap(for: position, chatId: chatId, app: app, connection: connection)
            return
        }
        let photo = TGFileInfo.fileId(fileId)
        
        do {
            try await connection.bot.sendPhoto(params: TGSendPhotoParams(chatId: .chat(chatId), photo: photo))
        } catch {
            await sendMap(for: position, chatId: chatId, app: app, connection: connection)
        }
    }
    
    private static func sendMap(for position: Int, chatId: Int64, app: Vapor.Application, connection: TGConnectionPrtcl) async {
        // app.directory.publicDirectory + "rat_ring.png"
        guard let imageData = FileManager.default.contents(atPath: app.directory.publicDirectory + "rat_ring.png")  // для локального теста "/Users/sgpopyvanov/tgbot/Public/rat_ring.png"
        else { return }
        
        // Создаем Image из Data
        guard var sourceImage = try? Image<RGBA, UInt8>(fileData: imageData) else { return }
        let sectorCount = 24
        let circleRadius = 30
        
        // Определяем размеры изображения
        let imageWidth = sourceImage.width
        let imageHeight = sourceImage.height
        
        // Определяем размеры сектора на вписанной окружности
        let sectorAngle = 2.0 * .pi / Double(sectorCount)
        let radius = Double(min(imageWidth, imageHeight) / 2)
        let offsetAngle = sectorAngle / 2.0
  
        let angle = sectorAngle * Double(position) + offsetAngle
        let sectorX = Int((cos(angle) * radius ) / 1.5) + (imageWidth / 2)
        let sectorY = Int((sin(angle) * radius ) / 1.5) + (imageHeight / 2)
        sourceImage.drawCircle(center: (x: sectorX, y: sectorY), radius: circleRadius, color: Color<RGBA, UInt8>(r: 255, g: 0, b: 0, a: 255))
        
        guard let outputImageData = try? sourceImage.fileData() else { return }
           
        let photo = TGFileInfo.file(.init(filename: "rat_ring", data: outputImageData))
        
        let params = TGSendPhotoParams(chatId: .chat(chatId), photo: photo)
        if let message = try? await connection.bot.sendPhoto(params: params),
           let fileId = message.photo?.first?.fileId {
            await cache.setValue(fileId, for: position)
        }
        
    }
}

final class DefaultBotHandlers {
    
    
    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await startHandler(app: app, connection: connection)
        await playHandler(app: app, connection: connection)
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
        let game = Game()
        await buttonsActionHandler(app: app, connection: connection, game: game)
        
        await connection.dispatcher.add(HandlerFactory.createPlayHandler(app: app, connection: connection, game: game))
    }
    
    
    private static func buttonsActionHandler(app: Vapor.Application, connection: TGConnectionPrtcl, game: Game) async {
        await connection.dispatcher.add(HandlerFactory.createButtonActionHandler(app: app, connection: connection, game: game))
        
        await connection.dispatcher.add(HandlerFactory.createEndTurnHandler(app: app, connection: connection, game: game))
        
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

