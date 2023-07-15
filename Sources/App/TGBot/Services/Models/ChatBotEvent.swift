enum ChatBotEvent: Equatable {
    case gameReset // Сброс игры
    case sendDice
    case sendMapFromCache
    case mapIsDrawing
    case sendDrawingMap
    case saveCacheId
    case captionChanged
    
    case message(id: Int) // ID отправленного сообщения, для удаления в тестах
    case updateSession(chatId: Int64) //для сброса таймера
}

extension ChatBotEvent {
    
    var description: String {
        switch self {
        case .gameReset:
            return "Сброс игры"
        case .sendDice:
            return "Кубики брошены"
        case .captionChanged:
            return "Надпись и/или кнопки под фото изменены"
        case .sendMapFromCache:
            return "Отправлена карта из кеша"
        case .mapIsDrawing:
            return "Карта успешно отрисована"
        case .sendDrawingMap:
            return "Отрисованая карта отправлена"
        case .saveCacheId:
            return "Сохранен кеш карты"
        case .message(let id):
            return "Сообщение с id=\(id) отправлено"
        case .updateSession(let chatId):
            return "Таймер сессии чата \(chatId) обновлен"
        }
    }
    
}
