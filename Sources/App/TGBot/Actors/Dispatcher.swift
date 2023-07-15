import TelegramVaporBot

final class Dispatcher: TGDefaultDispatcher {
    
    required init(bot: TGBot) async throws {
        try await super.init(bot: bot)
    }
    
    func removeAll(by chatId: Int64) async {
        guard let group = handlersGroup.first else { return }
        let filtered = group.filter { $0.name.range(of: "\(chatId)", options: .caseInsensitive) == nil }
        handlersGroup = [filtered]
    }
    
    func removeChatGptHandler() async {
        guard let group = handlersGroup.first else { return }
        let filtered = group.filter { $0.name != "chatGpt" }
        handlersGroup = [filtered]
    }
}
