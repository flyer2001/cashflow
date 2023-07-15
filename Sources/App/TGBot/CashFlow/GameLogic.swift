//
//  File.swift
//  
//
//  Created by sgpopyvanov on 09.07.2023.
//

import Foundation

actor Game {
    let board: [String] = defaultBoard
    var currentPlayerPosition: Int = 9
    let dice = Dice()
    let turn = Turn()
    
    static func rollDice(numberOfDice: Int = 1) -> Int {
        var result = 0
        
        for _ in 1...numberOfDice {
            let diceRoll = Int.random(in: 1...6)
            result += diceRoll
        }
        
        return result
    }
    
    func move(step: Int) -> String {
        currentPlayerPosition += step
        if currentPlayerPosition >= board.count {
            currentPlayerPosition %= board.count
        }
        return board[currentPlayerPosition]
    }
    
    func reset() async {
        currentPlayerPosition = 9
        await turn.endTurn()
        await dice.resumeDice()
    }
}
