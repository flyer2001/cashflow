@testable import App
import XCTest

final class GameLogicTests: XCTestCase {
    var game: Game!

    override func tearDownWithError() throws {
        game = nil
    }

    func testNextPlayerMethod() async {
        game = Game()
        await game.addPlayer(1, name: "john")
        await game.addPlayer(2, name: "scott")
        await game.addPlayer(3, name: "mike")
        
        let currentId = await game.currentPlayer.id
        
        await game.nextPlayer()
        await game.nextPlayer()
        await game.nextPlayer()
        
        let lastId = await game.currentPlayer.id
        
        XCTAssertEqual(currentId, lastId)
    }
    
    func testAdmin() async {
        game = Game()
        await game.setAdmin(id: 0)
        
        let adminId = await game.adminId
        XCTAssertEqual(adminId, 0)
    }
}
