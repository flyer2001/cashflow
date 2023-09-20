actor DialogState {
    var isDialog = false

    func startDialog() {
        isDialog = true
    }
    
    func stopDialog() {
        isDialog = false
    }
}
