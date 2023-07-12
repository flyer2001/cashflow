actor ImageCache {
    private var cache: [Int: String] = [:]
    var path = ""
    
    func getValue(for key: Int) -> String? {
        cache[key]
    }
    
    func setValue(_ value: String, for key: Int) async {
        cache[key] = value
        await App.logger.log(event: .saveCacheId)
    }
    
    func setImagePath(path: String) {
        self.path = path
    }
}
