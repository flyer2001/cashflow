actor Turn {
    var isTurnEnd = true
    var isDealDeckSelectionComplete = true
    
    func startTurn() {
        isTurnEnd = false
    }
    
    func endTurn() {
        isTurnEnd = true
    }
    
    func startDeckSelection() {
        isDealDeckSelectionComplete = false
    }
    
    func stopDeckSelection() {
        isDealDeckSelectionComplete = true
    }
}
