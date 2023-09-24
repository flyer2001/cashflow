final class Player {
    // MARK: - Information Data
    let id: Int64
    let name: String
    var proffesion: Proffesion?
    
    // MARK: - Game State
    var position: Int = 8
    
    var isFired = false
    var firedMissTurnCount: Int = 0
    
    var isConflict = false
    var conflictOptionsCount: Int = 0
    var conflictReminder: String?
    
    init(id: Int64, name: String) {
        self.id = id
        self.name = name
    }
}
