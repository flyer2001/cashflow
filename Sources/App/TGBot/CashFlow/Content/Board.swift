enum BoardCell {
    case checkConflict
    case possibilities
    case market
    case luxure
    case dismission
    case charityAcquaintance
    case child
    
    var description: String {
        switch self {
        case .checkConflict:
            return "Расчетный чек / Конфликт"
        case .possibilities:
            return "Возможности"
        case .market:
            return "Рынок"
        case .luxure:
            return "Роскошь"
        case .dismission:
            return "Увольнение"
        case .charityAcquaintance:
            return "Благотворительность / Давай познакомимся"
        case .child:
            return "Ребенок"
        }
    }
}


extension Game {
    static let defaultBoard: [BoardCell] = [
        .checkConflict,
        .possibilities,
        .market,
        .possibilities,
        .luxure,
        .possibilities,
        .dismission,
        .possibilities,
        .checkConflict,
        .possibilities,
        .market,
        .possibilities,
        .luxure,
        .possibilities,
        .charityAcquaintance,
        .possibilities,
        .checkConflict,
        .possibilities,
        .market,
        .possibilities,
        .luxure,
        .possibilities,
        .child,
        .possibilities
    ]
}


