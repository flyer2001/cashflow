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
    
    // MARK: - Game Setup Methods
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
    
    func shufflePlayerProffessions() {
        let proffesions = Proffesion.allCases.shuffled()
        var proffessionIndex: Int = 0
        players.enumerated().forEach { index, player in
            if proffessionIndex == proffesions.count - 1 {
                proffessionIndex = 0
            }
            player.proffesion = proffesions[proffessionIndex]
            proffessionIndex += 1
        }
    }
    
    // MARK: - Game Move Methods
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
        chageStateForCurrentPlayer()
        return board[currentPlayer.position]
    }
    
    private func chageStateForCurrentPlayer() {
        switch board[currentPlayer.position] {
        case .dismission:
            fireCurrentPlayer()
        case .checkConflict:
            readyForConflictCurrentPlayer()
        default:
            return
        }
    }
    
    // MARK: - Conflict Logic
    private func readyForConflictCurrentPlayer() {
        currentPlayer.isConflict = true
        currentPlayer.conflictOptionsCount = 3
    }
    
    func isResolveConflict(dice: Int) -> Bool {
        currentPlayer.conflictOptionsCount -= 1
        if dice < 4 {
            return false
        } else {
            currentPlayer.conflictReminder = nil
            currentPlayer.isConflict = false
            return true
        }
    }
    
    // MARK: - Fire Logic
    func countDownFiredMissTurnForCurrentPlayer() {
        currentPlayer.firedMissTurnCount -= 1
        currentPlayer.isFired = currentPlayer.firedMissTurnCount > 0
    }
    
    private func fireCurrentPlayer() {
        currentPlayer.isFired = true
        currentPlayer.firedMissTurnCount = 2
    }
    
    
    // MARK: - Pop Card Logic
    func popDeck(cell: BoardCell) throws -> String {
        switch cell {
        case .charityAcquaintance:
            return ""
        case .child, .dismission:
            return cell.description
        case .market:
            return popCard(deck: &marketDeck, defaultDeck: Game.marketDeckDefault)
        case .luxure:
            return popCard(deck: &luxuryDeck, defaultDeck: Game.luxuryDeckDefault)
        case .possibilities:
            throw GameError.usePopSmallOrBigDealInstead
        case .checkConflict:
            let card = popCard(deck: &conflictDeck, defaultDeck: Game.conflictDeckDefault)
            currentPlayer.conflictReminder = card
            return card
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
