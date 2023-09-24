final class Player {
    // MARK: - Information Data
    let id: Int64
    let name: String
    var proffesion: Proffesion?
    
    // MARK: - Game State
    var position: Int = 8
    
    // MARK: - Fire
    var isFired = false
    var firedMissTurnCount: Int = 0
    
    // MARK: - Conflict
    var isConflict = false
    var conflictOptionsCount: Int = 0
    var conflictReminder: String?
    
    // MARK: - Charity
    var isCharityBoost = false
    var charityBoostCount: Int = 0
    
    init(id: Int64, name: String) {
        self.id = id
        self.name = name
    }
}
