@testable import App
import TelegramVaporBot
import XCTVapor


final class AppTests: XCTestCase {
    // TODO
    // проверить отдельными тестами отправку карты, отправку сообщения - атомарные функцие
    // а дальше уже проверять сценарии, только убедить
    func testHandlers() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        try await configure(app)
        
        var outputMessage: [String] = []
        
        let message = TGMessage(messageId: 0,from: TGUser(id: 0, isBot: false, firstName: "test"), date: 0, chat: TGChat(id: 0, type: .private),text: "/play", entities: [.init(type: .botCommand, offset: 0, length: 5)])
        let update = TGUpdate(updateId: 0, message: message)
        
        let playHandler = await HandlerFactory.createPlayHandler(app: app, connection: tgBotConnection.connection, game: Game()) { message in
            outputMessage.append(message)
        }
        try? await playHandler.handle(update: update, bot: tgBot)
        XCTAssertEqual(outputMessage, ["Карта отправлена", "Сообщение пользователю"])

        try app.test(.GET, "hello", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Hello, world!")
        })
    }
}
