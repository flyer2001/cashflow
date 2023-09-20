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
            return "Увольнение /n/n Упс, вы потеряли работу. Пропустите два хода и заплатите банку ваши ежемесячные расходы. Не расстраивайтесь, все к лучшему! У вас есть время остановиться и подумать"
        case .charityAcquaintance:
            return "Благотворительность / Давай познакомимся \n\n Отличная новость: у вас выпала возможность стать меценатом и  передать 10% своего дохода в благотворительный фонд на помощь другим людям. \nПраво отправки денежных средств остается за вами. \nЕсли решитесь - у вас появляется возможность ускориться: при следующем ходе кидайте кубик три раза подряд. \nЕсли отказываетесь от данной возможности - просто передайте ход следующему участнику.\n\n "
        case .child:
            return "Ребенок \n\n Поздравляем, у вас пополнение в семье! Получите материнский капитал в размере 10.000 долларов и добавьте ежемесячные дополнительные расходы на ребенка в вашу таблицу расходов и доходов"
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


