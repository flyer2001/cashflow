@testable import App
import TelegramVaporBot
import XCTVapor


final class AppTests: XCTestCase {
    
    // chatID захардкожен для тестирования
    // chatID - 566335622 чат лички
    // -806476563 - тестовый чат игры для проверки взаимодействия с группой
    let chatId: Int64 = -806476563
    // id файла, который уже был загружен через апи
    let fileID = "AgACAgIAAxkDAAIF6GSpjMEcr34AAeQ4ToCeDYpLNio8mgAC7c4xGxrMUUkaEaPxpt35SwEAAwIAA3MAAy8E"
    
    func testHandlers() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try await configure(app)

        try await sendMessage()
        try await editTextAndButtons()
        try await sendPhotoWithInlineButtonsAndRemoveButtons()
        try await sendPhotoFromCacheWithCaptionAndRemoveCaption()
        try await sendMessageAndEditKeyboardOnly()
        try await playHandlerTest()
        
    }
    
    // Обработчик команды /play
    private func playHandlerTest() async throws {
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
        var events: [ChatBotEvent] = []
        var messageId: Int = 0
        let handler = HandlerFactory.createPlayHandler(game: Game()) { event in
            if case .message(let id) = event {
                messageId = id
            } else {
                events.append(event)
            }
        }
        try await Task.sleep(nanoseconds: 2_000_000_000) // нужно подождать, пока прокидает все update сам бот
        try await handler.handle(update: update, bot: App.bot)
        XCTAssertEqual(events, [.gameReset, .mapIsDrawing, .saveCacheId, .sendDrawingMap])
        
        try await App.deleteMessage(chatId: chatId, messageId: messageId)
        events = []
        
        // Запрашиваем повторный запрос update старта игры, чтобы проверить отправку из кеша
        
        try await handler.handle(update: update, bot: App.bot)
        XCTAssertEqual(events, [.gameReset, .sendMapFromCache])
        try await App.deleteMessage(chatId: chatId, messageId: messageId)
    }
    
    // Проверка отправки сообщения
    private func sendMessage() async throws {
        
        let chatId = chatId
        
        let buttons: [[TGInlineKeyboardButton]] = [
            [.init(text: "Кнопка", callbackData: "button")],
        ]
        
        try await App.sendMessage(
            chatId: chatId,
            text: "*test*",
            parseMode: .markdownV2,
            inlineButtons: buttons
        ) { message in
            XCTAssertEqual(message.text, "test")
            XCTAssertEqual(message.replyMarkup?.inlineKeyboard.first?.first?.text, "Кнопка")
            XCTAssertEqual(message.replyMarkup?.inlineKeyboard.first?.first?.callbackData, "button")
            
            try? await App.deleteMessage(chatId: chatId, messageId: message.messageId)
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

        
        let completion: ((TGMessage) async -> ()) = { result in
            expectation.fulfill()
            XCTAssertEqual(result.text, "textWithot markdown")
            XCTAssertEqual(result.replyMarkup?.inlineKeyboard.first?.first?.text, "Другая Кнопка")
            XCTAssertEqual(result.replyMarkup?.inlineKeyboard.first?.first?.callbackData, "newButton")
            try? await App.deleteMessage(chatId: chatId, messageId: result.messageId)
        }
        
        try await App.sendMessage(
            chatId: chatId,
            text: "*test*",
            parseMode: .markdownV2,
            inlineButtons: buttons
        ) { message in
            
            try? await App.editMessage(
                chatId: chatId,
                messageId: message.messageId,
                newText: "textWithot markdown",
                newButtons: newButtons,
                completion: completion
            )
        }
        await waitForExpectations(timeout: 1, handler: nil)
    }
    
    // Отправка фото с кнопками, удаление кнопок под фотками
    private func sendPhotoWithInlineButtonsAndRemoveButtons() async throws {
        let chatId = chatId
        
        let buttons: [[TGInlineKeyboardButton]] = [
            [.init(text: "Кнопка", callbackData: "button")],
        ]
        let expectation = self.expectation(description: "Редактирование прошло успешно")
        
        let imageData = try XCTUnwrap(FileManager.default.contents(atPath: "/Users/sgpopyvanov/tgbot/Public/rat_ring.png"))
        
        let editInlineButtonCompletion: ((TGMessage) async -> ())? = { result in
            expectation.fulfill()
            XCTAssertEqual(result.caption, "caption text")
            XCTAssertNil(result.replyMarkup)
            
            try? await App.deleteMessage(chatId: chatId, messageId: result.messageId)
        }
        
        try await App.sendPhoto(
            chatId: chatId,
            captionText: "*caption* text",
            parseMode: .markdownV2,
            photoData: imageData,
            inlineButtons: buttons) { message in
                XCTAssertEqual(message.caption, "caption text")
                XCTAssertNotNil(message.photo)
                XCTAssertEqual(message.replyMarkup?.inlineKeyboard.first?.first?.text, "Кнопка")
                XCTAssertEqual(message.replyMarkup?.inlineKeyboard.first?.first?.callbackData, "button")
                
                try? await App.editInlineButtons(
                    chatId: chatId, messageId:
                        message.messageId,
                    newButtons: nil,
                    completion: editInlineButtonCompletion
                )
        }
        await waitForExpectations(timeout: 1, handler: nil)
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
        
        
        let editCaptionCompletion: ((TGMessage) async -> ())? = { result in
            expectation.fulfill()
            XCTAssertNil(result.caption)
            XCTAssertEqual(result.replyMarkup?.inlineKeyboard.first?.first?.text, "Кнопка1")
            XCTAssertEqual(result.replyMarkup?.inlineKeyboard.first?.first?.callbackData, "button1")
            
            try? await App.deleteMessage(chatId: chatId, messageId: result.messageId)
        }
        
        try await App.sendPhotoFromCache(
            chatId: chatId,
            fileId: fileID,
            captionText: "caption text without parsing",
            buttons: buttons) { message in
                XCTAssertEqual(message.caption, "caption text without parsing")
                XCTAssertNotNil(message.photo)
                XCTAssertEqual(message.replyMarkup?.inlineKeyboard.first?.first?.text, "Кнопка")
                XCTAssertEqual(message.replyMarkup?.inlineKeyboard.first?.first?.callbackData, "button")
                
                try? await App.editCaption(
                    chatId: chatId,
                    messageId: message.messageId,
                    newCaptionText: nil,
                    parseMode: nil,
                    newButtons: newButtons,
                    completion: editCaptionCompletion
                )
        }
        await waitForExpectations(timeout: 1, handler: nil)
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
        let editKeyboardCompletion: ((TGMessage) async -> ())? = { result in
            expectation.fulfill()
            XCTAssertNil(result.caption)
            XCTAssertEqual(result.replyMarkup?.inlineKeyboard.first?.first?.text, "Кнопка1")
            XCTAssertEqual(result.replyMarkup?.inlineKeyboard.first?.first?.callbackData, "button1")
            
            try? await App.deleteMessage(chatId: chatId, messageId: result.messageId)
        }
        
        try await App.sendMessage(
            chatId: chatId,
            text: "*test*",
            parseMode: .markdownV2,
            inlineButtons: buttons
        ) { message in
            try? await App.editInlineButtons(
                chatId: chatId,
                messageId: message.messageId,
                newButtons: newButtons,
                completion: editKeyboardCompletion
            )
            
        }
        
        await waitForExpectations(timeout: 1, handler: nil)
    }
}
