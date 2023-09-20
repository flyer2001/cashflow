final class Player {
    let id: Int64
    let name: String
    var position: Int = 8
    var proffesion: Proffesion?
    
    init(id: Int64, name: String) {
        self.id = id
        self.name = name
    }
}
