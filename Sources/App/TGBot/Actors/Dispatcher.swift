import SwiftTelegramSdk
import Logging

final class Dispatcher: TGDefaultDispatcher {
    
    required init(log: Logger) async throws {
        try await super.init(log: log)
    }
    
    func removeAll(by chatId: Int64) {
        guard let group = handlersGroup.first else { return }
        let filtered = group.filter { $0.name.range(of: "\(chatId)", options: .caseInsensitive) == nil }
        handlersGroup = [filtered]
    }
    
    func removeOnboardingHandler(for chatId: Int64) {
        guard let group = handlersGroup.first else { return }
        let filtered = group.filter {
            let isOnboardingHandler = $0.name.contains(HandlerFactory.Handler.nextOnboardingCallback.rawValue) && $0.name.contains("\(chatId)")
            return !isOnboardingHandler
        }
        handlersGroup = [filtered]
    }
    
    func removeChatGptHandler() {
        guard let group = handlersGroup.first else { return }
        let filtered = group.filter { $0.name != "chatGpt" }
        handlersGroup = [filtered]
    }
}
