actor Turn {
    var isTurnEnd = true
    var isDealDeckSelectionComplete = true
    var isCharitySelectionComplete = true
    
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
    
    func startCharitySelection() {
        isCharitySelectionComplete = false
    }
    
    func stopCharitySelection() {
        isCharitySelectionComplete = true
    }
}
