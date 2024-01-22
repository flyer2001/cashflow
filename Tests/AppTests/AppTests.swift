@testable import App
import TelegramVaporBot
import XCTVapor


final class AppTests: XCTestCase {
    
    private var vaporApp: Application!
    private var app: App!
    private var events: [ChatBotEvent] = []
    var messageId: Int = 0
    
    // chatID захардкожен для тестирования
    // -984387887 - тестовый чат игры для проверки взаимодействия с группой
    let chatId: Int64 = -984387887
    // id файла, который уже был загружен через апи
    let fileID = "AgACAgIAAxkDAAIF6GSpjMEcr34AAeQ4ToCeDYpLNio8mgAC7c4xGxrMUUkaEaPxpt35SwEAAwIAA3MAAy8E"
    
    override func setUp() async throws {
        vaporApp = Application(.testing)
        try await configure(vaporApp) { [weak self] tgApp in
            self?.app = tgApp
        }
        messageId = 0
        events = []
        await app.logger.setObserver { [weak self] event in
            if case .message(let id) = event {
                // сохраняем id сообщения для теста, чтобы удалить его из чата
                self?.messageId = id
            } else {
                self?.events.append(event)
            }
        }
        // нужно подождать, пока прокидает все update сам бот
        try await Task.sleep(nanoseconds: 2_000_000_000)
    }
    
    override func tearDown() async throws {
        vaporApp.shutdown()
        vaporApp = nil
        app = nil
    }
    
    func testTgApiMethods() async throws {
        try await sendMessage()
        try await editTextAndButtons()
        try await sendPhotoWithInlineButtonsAndRemoveButtons()
        try await sendPhotoFromCacheWithCaptionAndRemoveCaption()
        try await sendMessageAndEditKeyboardOnly()
    }
    
    // Обработчик команды /play - вызов меню
    // Нужен отдельный тест на activeHandlers + session с завершением сессии
    func testPlayCommandHandler() async throws {
        // имитируем отправку сообщения пользователем
        let update = TGUpdate(
            updateId: 12345,
            message: TGMessage(
                messageId: 1234,
                date: 0,
                chat: TGChat(
                    id: chatId,
                    type: .group
                ),
                text: "/play",
                entities: [TGMessageEntity(type: .botCommand, offset: 0, length: 5)]
            )
        )
        let expectation = XCTestExpectation(description: "Ожидание получения chatID начала сессии")
        
        let handler = try await app.handlerManager.handlerFactory.createDefaultPlayHandler { [weak self] startGameChatId, messageId in
            expectation.fulfill()
            // TODO - починить тетсы
            //self?.messageId = messageId
            XCTAssertEqual(startGameChatId, self?.chatId)
        }
        XCTAssertEqual(handler.name, HandlerFactory.Handler.playCommandHandler.rawValue)
        
        try await handler.handle(update: update, bot: app.bot)
        
        XCTAssertEqual(events, [.startGameMenuSent])
        await fulfillment(of: [expectation], timeout: 1.0)
        
        try await app.tgApi.deleteMessage(chatId: chatId, messageId: messageId)
    }
    
    func testJoinToGameCallbackHandler() async throws {
        // имитируем нажати кнопки
        let update = TGUpdate(
            updateId: 12345,
            callbackQuery: TGCallbackQuery(
                id: "1234",
                from: TGUser(id: chatId, isBot: false, firstName: "isTest", username: "istest"),
                message: TGMessage(
                    messageId: 1234,
                    date: 0,
                    chat: TGChat(
                        id: chatId,
                        type: .group
                    ),
                    text: "/play",
                    entities: [TGMessageEntity(type: .botCommand, offset: 0, length: 5)]

                ),
                chatInstance: "123",
                data: HandlerFactory.Handler.startGameCallback.rawValue + "_\(chatId)"
            )
        )
        let game = Game()

        let handler = await app.handlerManager.handlerFactory.joinToGameHandler(chatId: chatId, game: game)
        XCTAssertEqual(handler.name, HandlerFactory.Handler.joingToGameCallback.rawValue + "_\(chatId)")
        try await handler.handle(update: update, bot: app.bot)
        let userName = await game.players[0].name
        XCTAssertEqual(userName, "istest")
        
        XCTAssertEqual(events, [.joinToGame])
        
        try await app.tgApi.deleteMessage(chatId: chatId, messageId: messageId)
    }
    
    // Обработчик callback Новая игра после нажатия кнопки
    func testAddPlayerMenuCallbackHandler() async throws {
        // имитируем нажати кнопки
        let update = TGUpdate(
            updateId: 12345,
            callbackQuery: TGCallbackQuery(
                id: "1234",
                from: TGUser(id: chatId, isBot: false, firstName: "isTest"),
                message: TGMessage(
                    messageId: 1234,
                    date: 0,
                    chat: TGChat(
                        id: chatId,
                        type: .group
                    ),
                    text: "/play",
                    entities: [TGMessageEntity(type: .botCommand, offset: 0, length: 5)]

                ),
                chatInstance: "123",
                data: HandlerFactory.Handler.startGameCallback.rawValue + "_\(chatId)"
            )
        )
        let game = Game()
        await game.addPlayer(0, name: "john")
        let handler = await app.handlerManager.handlerFactory.addPlayerMenuHandler(chatId: chatId, game: game)
        XCTAssertEqual(handler.name, HandlerFactory.Handler.addPlayerMenuCallback.rawValue + "_\(chatId)")
        try await handler.handle(update: update, bot: app.bot)
        XCTAssertEqual(events, [.addPlayersMenuSent])
        
        try await app.tgApi.deleteMessage(chatId: chatId, messageId: messageId)
    }
    
    func testRollDiceCallbackHandler() async throws {
        // имитируем нажати кнопки
        let update = TGUpdate(
            updateId: 12345,
            callbackQuery: TGCallbackQuery(
                id: "1234",
                from: TGUser(id: chatId, isBot: false, firstName: "isTest"),
                message: TGMessage(
                    messageId: 0,
                    date: 0,
                    chat: TGChat(
                        id: chatId,
                        type: .group
                    ),
                    text: "/play",
                    entities: [TGMessageEntity(type: .botCommand, offset: 0, length: 5)]

                ),
                chatInstance: "123",
                data: HandlerFactory.Handler.rollDiceCallback.rawValue + "_\(chatId)"
            )
        )
        let game = Game()
        await game.addPlayer(0, name: "john")
        let handler = await app.handlerManager.handlerFactory.createRollDiceHandler(chatId: chatId, game: game) { [weak self] in
            guard let self = self else { return }
            // Тут ждем пока бросят кубик, и изменится оправленное сообщение
            
            XCTAssertEqual(self.events, [.sendDice, .mapIsDrawing, .saveCacheId, .sendDrawingMap])
            try? await self.app.tgApi.deleteMessage(chatId: self.chatId, messageId: self.messageId)
        }
        XCTAssertEqual(handler.name, HandlerFactory.Handler.rollDiceCallback.rawValue + "_\(chatId)")
        try await handler.handle(update: update, bot: app.bot)
    }
    
    func testEndGameCallbackHandler() async throws {
        let chatId = chatId
        let fileID = fileID

        let game = Game()
        await game.addPlayer(0, name: "john")
        await game.turn.startTurn()
        
        let buttons: [[TGInlineKeyboardButton]] = [
            [.init(text: "Кнопка", callbackData: "button")],
        ]
        let expectation = self.expectation(description: "Хэндлер отработал")
        
        let handlerCompletion = {
            [weak self] in
            guard let self = self else { return }
            expectation.fulfill()
            XCTAssertEqual(self.events, [.endTurn])
        }
        
        try await app.tgApi.sendPhotoFromCache(
            chatId: chatId,
            fileId: fileID,
            captionText: "caption text without parsing",
            buttons: buttons) { message in
                let update = TGUpdate(
                    updateId: 1234,
                    callbackQuery: TGCallbackQuery(
                        id: "1234",
                        from: TGUser(id: chatId, isBot: false, firstName: "isTest"),
                        message: TGMessage(
                            messageId: message.messageId,
                            date: 0,
                            chat: TGChat(
                                id: chatId,
                                type: .group
                            ),
                            text: "/play",
                            entities: [TGMessageEntity(type: .botCommand, offset: 0, length: 5)]
                        ),
                        chatInstance: "123",
                        data: HandlerFactory.Handler.endTurnCallback.rawValue + "_\(chatId)"
                    )
                )
                
                let handler = await self.app.handlerManager.handlerFactory.createEndTurnHandler(chatId: chatId, game: game, completion: handlerCompletion)
                XCTAssertEqual(handler.name, HandlerFactory.Handler.endTurnCallback.rawValue + "_\(chatId)")
                try? await handler.handle(update: update, bot: self.app.bot)
            }
        await fulfillment(of: [expectation], timeout: 1.0)
        try? await self.app.tgApi.deleteMessage(chatId: self.chatId, messageId: self.messageId)
    }
    
    // Проверка отправки сообщения
    private func sendMessage() async throws {
        
        let chatId = chatId
        
        let buttons: [[TGInlineKeyboardButton]] = [
            [.init(text: "Кнопка", callbackData: "button")],
        ]
        
        try await app.tgApi.sendMessage(
            chatId: chatId,
            text: "*test*",
            parseMode: .markdownV2,
            inlineButtons: buttons
        ) { [weak self] message in
            XCTAssertEqual(message.text, "test")
            XCTAssertEqual(message.replyMarkup?.inlineKeyboard.first?.first?.text, "Кнопка")
            XCTAssertEqual(message.replyMarkup?.inlineKeyboard.first?.first?.callbackData, "button")
            
            try? await self?.app.tgApi.deleteMessage(chatId: chatId, messageId: message.messageId)
        }
    }
    
    // замена текста и кнопок под сообщением
    private func editTextAndButtons() async throws {
        let chatId = chatId
        
        let buttons: [[TGInlineKeyboardButton]] = [
            [.init(text: "Кнопка", callbackData: "button")],
        ]
        let newButtons:[[TGInlineKeyboardButton]] = [
            [.init(text: "Другая Кнопка", callbackData: "newButton")],
        ]
        let expectation = self.expectation(description: "Редактирование прошло успешно")

        
        let completion: ((TGMessage) async -> ()) = { [weak self] result in
            expectation.fulfill()
            XCTAssertEqual(result.text, "textWithout markdown")
            XCTAssertEqual(result.replyMarkup?.inlineKeyboard.first?.first?.text, "Другая Кнопка")
            XCTAssertEqual(result.replyMarkup?.inlineKeyboard.first?.first?.callbackData, "newButton")
            try? await self?.app.tgApi.deleteMessage(chatId: chatId, messageId: result.messageId)
        }
        
        try await app.tgApi.sendMessage(
            chatId: chatId,
            text: "*test*",
            parseMode: .markdownV2,
            inlineButtons: buttons
        ) { [weak self] message in
            
            try? await self?.app.tgApi.editMessage(
                chatId: chatId,
                messageId: message.messageId,
                newText: "textWithout markdown",
                newButtons: newButtons,
                completion: completion
            )
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // Отправка фото с кнопками, удаление кнопок под фотками
    private func sendPhotoWithInlineButtonsAndRemoveButtons() async throws {
        let chatId = chatId
        
        let buttons: [[TGInlineKeyboardButton]] = [
            [.init(text: "Кнопка", callbackData: "button")],
        ]
        let expectation = self.expectation(description: "Редактирование прошло успешно")
        
        let imageData = try XCTUnwrap(FileManager.default.contents(atPath: "/Users/sgpopyvanov/tgbot/Public/rat_ring.png"))
        
        let editInlineButtonCompletion: ((TGMessage) async -> ())? = { [weak self] result in
            expectation.fulfill()
            XCTAssertEqual(result.caption, "caption text")
            XCTAssertNil(result.replyMarkup)
            
            try? await self?.app.tgApi.deleteMessage(chatId: chatId, messageId: result.messageId)
        }
        
        try await app.tgApi.sendPhoto(
            chatId: chatId,
            captionText: "*caption* text",
            parseMode: .markdownV2,
            photoData: imageData,
            inlineButtons: buttons) { [weak self] message in
                XCTAssertEqual(message.caption, "caption text")
                XCTAssertNotNil(message.photo)
                XCTAssertEqual(message.replyMarkup?.inlineKeyboard.first?.first?.text, "Кнопка")
                XCTAssertEqual(message.replyMarkup?.inlineKeyboard.first?.first?.callbackData, "button")
                
                try? await self?.app.tgApi.editInlineButtons(
                    chatId: chatId, messageId:
                        message.messageId,
                    newButtons: nil,
                    completion: editInlineButtonCompletion
                )
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // Отправка фото из кеша с caption, удаление caption, изменение кнопок
    private func sendPhotoFromCacheWithCaptionAndRemoveCaption() async throws {
        let chatId = chatId
        let fileID = fileID
        
        let buttons: [[TGInlineKeyboardButton]] = [
            [.init(text: "Кнопка", callbackData: "button")],
        ]
        let newButtons: [[TGInlineKeyboardButton]] = [
            [.init(text: "Кнопка1", callbackData: "button1")],
        ]
        let expectation = self.expectation(description: "Редактирование прошло успешно")
        
        
        let editCaptionCompletion: ((TGMessage) async -> ())? = { [weak self] result in
            expectation.fulfill()
            XCTAssertNil(result.caption)
            XCTAssertEqual(result.replyMarkup?.inlineKeyboard.first?.first?.text, "Кнопка1")
            XCTAssertEqual(result.replyMarkup?.inlineKeyboard.first?.first?.callbackData, "button1")
            
            try? await self?.app.tgApi.deleteMessage(chatId: chatId, messageId: result.messageId)
        }
        
        try await app.tgApi.sendPhotoFromCache(
            chatId: chatId,
            fileId: fileID,
            captionText: "caption text without parsing",
            buttons: buttons) { [weak self] message in
                XCTAssertEqual(message.caption, "caption text without parsing")
                XCTAssertNotNil(message.photo)
                XCTAssertEqual(message.replyMarkup?.inlineKeyboard.first?.first?.text, "Кнопка")
                XCTAssertEqual(message.replyMarkup?.inlineKeyboard.first?.first?.callbackData, "button")
                
                try? await self?.app.tgApi.editCaption(
                    chatId: chatId,
                    messageId: message.messageId,
                    newCaptionText: nil,
                    parseMode: nil,
                    newButtons: newButtons,
                    completion: editCaptionCompletion
                )
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // Проверка отправки сообщения
    private func sendMessageAndEditKeyboardOnly() async throws {
        
        let chatId = chatId
        
        let buttons: [[TGInlineKeyboardButton]] = [
            [.init(text: "Кнопка", callbackData: "button")],
        ]
        let newButtons: [[TGInlineKeyboardButton]] = [
            [.init(text: "Кнопка1", callbackData: "button1")],
        ]
        
        let expectation = self.expectation(description: "Редактирование прошло успешно")
        let editKeyboardCompletion: ((TGMessage) async -> ())? = { [weak self] result in
            expectation.fulfill()
            XCTAssertNil(result.caption)
            XCTAssertEqual(result.replyMarkup?.inlineKeyboard.first?.first?.text, "Кнопка1")
            XCTAssertEqual(result.replyMarkup?.inlineKeyboard.first?.first?.callbackData, "button1")
            
            try? await self?.app.tgApi.deleteMessage(chatId: chatId, messageId: result.messageId)
        }
        
        try await app.tgApi.sendMessage(
            chatId: chatId,
            text: "*test*",
            parseMode: .markdownV2,
            inlineButtons: buttons
        ) { [weak self] message in
            try? await self?.app.tgApi.editInlineButtons(
                chatId: chatId,
                messageId: message.messageId,
                newButtons: newButtons,
                completion: editKeyboardCompletion
            )
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
