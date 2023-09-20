actor Dice {
    var isBlocked = false
    
    func blockDice() {
        isBlocked = true
    }
    
    func resumeDice() {
        isBlocked = false
    }
}
