@testable import App
import TelegramVaporBot
import XCTVapor


final class AppTests: XCTestCase {
    // TODO
    // проверить отдельными тестами отправку карты, отправку сообщения - атомарные функцие
    // а дальше уже проверять сценарии, только убедиться что моки правильно мокаются))
    func testHandlers() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        try await configure(app)
        
        // chatID захардкожен для тестирования но возможно стоит попробовать тут прокидывать .user, чтобы бот сам с собой проверял все методы или сделать разные проверки - отправка в приватный чат, в групповой чат, от callbackquery
        try await HelpersFactory.sendMessage(chatId: 566335622, connection: tgBotConnection.connection, bot: tgBot, message: "test") { message in
            XCTAssertEqual(message.text, "test")
        }
    }
}
