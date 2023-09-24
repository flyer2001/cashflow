enum BoardCell: String {
    case checkConflict = "Расчетный чек / Конфликт"
    case possibilities = "Возможности"
    case market = "Рынок"
    case luxure = "Роскошь"
    case dismission = "Увольнение"
    case charityAcquaintance = "Благотворительность / Давай познакомимся"
    case child = "Ребенок"
    
    var description: String {
        switch self {
        case .checkConflict:
            return "Чтобы получить свой доход, необходимо совместно с партнером найти 3 варианта решения на предложенный конфликт ниже. Подготовьте ваш ответ и пришлите его в этот чат в таком формате. \n\n1 вариант = 1 предложение - в порядке приоритетности \n\nПеред началом следующего хода мы проверим ваши варианты \n\nВаша ситуация:"
        case .possibilities:
            return ""
        case .market:
            return ""
        case .luxure:
            return ""
        case .dismission:
            return "Упс, вы потеряли работу. Пропустите два хода и заплатите банку ваши ежемесячные расходы. Не расстраивайтесь, все к лучшему! У вас есть время остановиться и подумать"
        case .charityAcquaintance:
            return "Отличная новость: у вас выпала возможность стать меценатом и  передать 10% своего дохода в благотворительный фонд на помощь другим людям. \nПраво отправки денежных средств остается за вами. \nЕсли решитесь - у вас появляется возможность ускориться: при следующем ходе кидайте кубик три раза подряд. \nЕсли отказываетесь от данной возможности - просто передайте ход следующему участнику.\n\n "
        case .child:
            return "Поздравляем, у вас пополнение в семье! Получите материнский капитал в размере 10.000 долларов и добавьте ежемесячные дополнительные расходы на ребенка в вашу таблицу расходов и доходов"
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


