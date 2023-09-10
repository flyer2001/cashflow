enum ChatBotEvent: Equatable {

    case startGameMenuSent
    case addPlayersMenuSent
    case joinToGame
    case sendDice
    case sendMapFromCache
    case mapIsDrawing
    case sendDrawingMap
    case saveCacheId
    case endTurn
    case popSmallDealsDeck
    case popBigDealsDeck
    case captionChanged
    case updateSession(chatId: Int64)
    case stopSession(chatId: Int64)
    
    case message(id: Int) // ID отправленного сообщения, для удаления в тестах
}

extension ChatBotEvent {
    
    var description: String {
        switch self {
        case .startGameMenuSent:
            return "Приветственное меню отправлено"
        case .addPlayersMenuSent:
            return "Отправлено меню добавления игроков"
        case .joinToGame:
            return "Игрок присоединился к игре"
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
        case .endTurn:
            return "Ход окончен"
        case .message(let id):
            return "Сообщение с id=\(id) отправлено"
        case .popSmallDealsDeck:
            return "Пользователь выбрал маленькие сделки"
        case .popBigDealsDeck:
            return "Пользователь выбрал большие сделки"
        case .updateSession(let chatId):
            return "Таймер сессии чата \(chatId) обновлен"
        case .stopSession(let chatId):
            return "Сессия для чата \(chatId) остановлена"
        }
    }
    
}
