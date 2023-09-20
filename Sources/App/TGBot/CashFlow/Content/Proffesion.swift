enum Proffesion: String, CaseIterable {
    case dentist, figureSkatingCoach, architecture, accountant, furnitureProductionTechnologist, lawer, coach, realtor, headIT, artist, astrolog, fireFighter
    
    var description: String {
        switch self {
        case .dentist:
            return "Стоматолог"
        case .figureSkatingCoach:
            return "Тренер по фигурному катанию"
        case .architecture:
            return "Архитектор"
        case .accountant:
            return "Бухгалтер"
        case .furnitureProductionTechnologist:
            return "Главный технолог по производству мебели"
        case .lawer:
            return "Юрист"
        case .coach:
            return "Коуч"
        case .realtor:
            return "Риэлтор"
        case .headIT:
            return "Руководитель IT"
        case .artist:
            return "Художник"
        case .astrolog:
            return "Астролог"
        case .fireFighter:
            return "Пожарный"
        }
    }
}
