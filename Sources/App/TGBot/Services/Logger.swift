actor ChatBotLogger {
    
    var observer: ((ChatBotEvent) -> ())?
    
    func log(event: ChatBotEvent) async {
        await App.bot.app.logger.debug("\(event.description)")
        observer?(event)
    }
    
    func setObserver(_ observer: ((ChatBotEvent) -> ())?) {
        self.observer = observer
    }
}
