//
//  MockModels.swift
//  almanac
//
//  Created by Hugo Peyron on 09/06/2025.
//

import Foundation

struct MockShikakuLevel: GameLevelData {
    let id: String
    let difficulty: Int
    let estimatedTime: TimeInterval
    let gridRows: Int
    let gridCols: Int
    let clues: [String]
}

struct MockPipeLevel: GameLevelData {
    let id: String
    let difficulty: Int
    let estimatedTime: TimeInterval
    let gridSize: Int
    let pipes: [String]
}

struct MockBinarioLevel: GameLevelData {
    let id: String
    let difficulty: Int
    let estimatedTime: TimeInterval
    let gridSize: Int
    let initialGrid: [[Int?]]

    init(id: String, difficulty: Int, estimatedTime: TimeInterval, gridSize: Int, initialGrid: [[Int?]]) {
        self.id = id
        self.difficulty = difficulty
        self.estimatedTime = estimatedTime
        self.gridSize = gridSize
        self.initialGrid = initialGrid.isEmpty ? Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize) : initialGrid
    }
}

struct MockWordleLevel: GameLevelData {
    let id: String
    let difficulty: Int
    let estimatedTime: TimeInterval
    let targetWord: String
    let maxAttempts: Int
}
