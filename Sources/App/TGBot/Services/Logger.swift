import Vapor

actor ChatBotLogger {
    
    private let app: Vapor.Application
    
    init(app: Vapor.Application) {
        self.app = app
    }
    
    var observer: ((ChatBotEvent) -> ())?
    
    func log(event: ChatBotEvent) {
        app.logger.debug("\(event.description)")
        observer?(event)
    }
    
    func setObserver(_ observer: ((ChatBotEvent) -> ())?) {
        self.observer = observer
    }
}
