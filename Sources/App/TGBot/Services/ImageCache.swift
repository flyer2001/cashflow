actor ImageCache {
    private let logger: ChatBotLogger
    
    init(logger: ChatBotLogger) {
        self.logger = logger
    }
    
    private var cache: [Int: String] = [:]
    var path = ""
    
    func getValue(for key: Int) -> String? {
        cache[key]
    }
    
    func setValue(_ value: String, for key: Int) async {
        cache[key] = value
        await logger.log(event: .saveCacheId)
    }
    
    func setImagePath(path: String) {
        self.path = path
    }
}
