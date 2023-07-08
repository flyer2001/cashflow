actor Turn {
    var isTurnEnd = true
    
    func startTurn() {
        isTurnEnd = false
    }
    
    func endTurn() {
        isTurnEnd = true
    }
}
