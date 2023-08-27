import Foundation

enum GameError: Error {
    case emptyPlayers
}

actor Game {
    private(set) var players: [Player] = []
    private(set) var adminId: Int64 = 0
    
    let board: [String] = defaultBoard
    var currentPlayer: Player!
    let dice = Dice()
    let turn = Turn()
    
    func addPlayer(_ id: Int64, name: String) {
        guard !players.contains(where: { $0.id == id }) else { return }
        let player = Player(id: id, name: name)
        players.append(player)
        currentPlayer = player
    }
    
    func shuffle() throws {
        var shufflePlayers = players
        
        guard !players.isEmpty else {
            throw GameError.emptyPlayers
        }
        
        for i in 0..<shufflePlayers.count {
            let randomIndex = Int.random(in: 0..<shufflePlayers.count)
            shufflePlayers.swapAt(i, randomIndex)
        }
        self.players = shufflePlayers
        
        guard let firstPlayer = players.first else {
            throw GameError.emptyPlayers
        }
        self.currentPlayer = firstPlayer
    }
    
    func setAdmin(id: Int64) {
        self.adminId = id
    }
    
    func nextPlayer() {
        guard let currentIndex = players.firstIndex(where: { $0.id == currentPlayer.id }) else {
            return
        }
        if currentIndex == players.count - 1 {
            currentPlayer = players[0]
        } else {
            currentPlayer = players[currentIndex + 1]
        }
    }
    
    func moveCurrentPlayer(step: Int) -> String {
        currentPlayer.position += step
        if currentPlayer.position >= board.count {
            currentPlayer.position %= board.count
        }
        return board[currentPlayer.position]
    }
}
