actor ImageCache {
    private let logger: ChatBotLogger
    
    init(logger: ChatBotLogger) {
        self.logger = logger
    }
    
    private var cache: [Int: String] = [:]
    var path = ""
    var proffessionsPath = ""
    private var proffessionsCardCache: [Proffesion: String] = [:]
    
    func getValue(for key: Int) -> String? {
        cache[key]
    }
    
    func setValue(_ value: String, for key: Int) async {
        cache[key] = value
        await logger.log(event: .saveCacheId)
    }
    
    func getCardValue(for proffesion: Proffesion) -> String? {
        proffessionsCardCache[proffesion]
    }
    
    func setCardValue(_ value: String, for proffession: Proffesion) async {
        proffessionsCardCache[proffession] = value
        await logger.log(event: .saveCacheId)
    }
    
    
    func setImagePath(path: String) {
        self.path = path
    }
    
    func setProffesionsPath(path: String) {
        proffessionsPath = path
    }
}
