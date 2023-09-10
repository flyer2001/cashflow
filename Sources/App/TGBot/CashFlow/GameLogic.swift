import Foundation

enum GameError: Error {
    case emptyPlayers
    case usePopSmallOrBigDealInstead
}

actor Game {
    private(set) var players: [Player] = []
    private(set) var adminId: Int64 = 0
    
    let board: [BoardCell] = defaultBoard
    var marketDeck: [String] = marketDeckDefault.shuffled()
    var luxuryDeck: [String] = luxuryDeckDefault.shuffled()
    var smallDealsDeck: [String] = smallDealsDefault.shuffled()
    var bigDealsDeck: [String] = bigDealsDefault.shuffled()
    var conflictDeck: [String] = conflictDeckDefault.shuffled()
    
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
        self.players = players.shuffled()
        
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
    
    func moveCurrentPlayer(step: Int) -> BoardCell {
        currentPlayer.position += step
        if currentPlayer.position >= board.count {
            currentPlayer.position %= board.count
        }
        return board[currentPlayer.position]
       
    }
    
    func popDeck(cell: BoardCell) throws -> String {
        switch cell {
        case .child, .charityAcquaintance, .dismission:
            return cell.description
        case .market:
            return popCard(deck: &marketDeck, defaultDeck: Game.marketDeckDefault)
        case .luxure:
            return popCard(deck: &luxuryDeck, defaultDeck: Game.luxuryDeckDefault)
        case .possibilities:
            throw GameError.usePopSmallOrBigDealInstead
        case .checkConflict:
            return popCard(deck: &conflictDeck, defaultDeck: Game.conflictDeckDefault)
        }
    }
    
    func popSmallDealDeck() -> String {
        popCard(deck: &smallDealsDeck, defaultDeck: Game.smallDealsDefault)
    }
    
    func popBigDealDeck() -> String {
        popCard(deck: &bigDealsDeck, defaultDeck: Game.bigDealsDefault)
    }
    
    private func popCard(deck: inout [String], defaultDeck: [String]) -> String {
        if let lastCard = deck.popLast() {
            return lastCard
        } else {
            deck = defaultDeck.shuffled()
            return deck.popLast() ?? ""
        }
    }
}
