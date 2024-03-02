import TelegramVaporBot

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

enum OnboardingContent {
    case text(text: String)
    case video(uri: String, captionText: String?)
    case image(uri: String, captionText: String?)
}

struct OnboardingContentItem {
    struct Next {
        struct Button {
            let key: String
            let buttonName: String
            
            init(key: String, buttonName: String = "Далее") {
                self.key = key
                self.buttonName = buttonName
            }
        }
        
        let buttons: [Button]
        
        init(buttons: [Button]) {
            self.buttons = buttons
        }
        
        init(button: Button) {
            self.buttons = [button]
        }
        
        init(key: String, buttonName: String = "Далее") {
            self.buttons = [Button(key: key, buttonName: buttonName)]
        }
    }
    
    let key: String
    let content: OnboardingContent 
    let next: Next?
}

actor Onboarding {
    typealias Button = OnboardingContentItem.Next.Button
    private let items: [String: OnboardingContentItem]
    private var currentKey = ""
    var currentMessage: TGMessage?
    let endCompletion: (() async -> ())?
    
    init(items: [OnboardingContentItem], startKey: String, endCompletion: (() async -> ())?) {
        self.items = items.reduce([String: OnboardingContentItem]()) { (dict, content) -> [String: OnboardingContentItem] in
            var dict = dict
            dict[content.key] = content
            return dict
        }
        currentKey = startKey
        self.endCompletion = endCompletion
    }
    
    func show() -> OnboardingContentItem? {
        items[currentKey]
    }
    
    // Полученное от ТГ сообщение с контентом
    func setCurrentMessage(_ message: TGMessage) {
        currentMessage = message
    }
    
    func nextStepsButtons() -> [Button] {
        items[currentKey]?.next?.buttons ?? []
    }
    
    func moveTo(key: String) {
        currentKey = key
    }
    
    func isNextLast() -> Bool {
        items[currentKey]?.next == nil
    }
}
