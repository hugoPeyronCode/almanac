//
//  LevelManager.swift
//  Multi-Game Puzzle App
//
//  Updated to work with simple JSON structure without gameType wrapper
//

import SwiftUI
import Foundation

@Observable
class LevelManager {
    static let shared = LevelManager()

    private var gameLevels: [GameType: [AnyGameLevel]] = [:]
    private let calendar = Calendar.current
    private let referenceDate = Date() // Today as reference point
    private var isLoaded = false

    private init() {
        loadAllGameLevels()
    }

    // MARK: - Level Loading

    private func loadAllGameLevels() {
        guard !isLoaded else { return }

        for gameType in GameType.allCases {
            loadLevelsForGame(gameType)
        }

        isLoaded = true
        print("✅ All game levels loaded successfully")
    }

    private func loadLevelsForGame(_ gameType: GameType) {
        guard let url = Bundle.main.url(forResource: gameType.rawValue + "_levels", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ No JSON file found for \(gameType.displayName), creating mock data")
            gameLevels[gameType] = createMockLevels(for: gameType)
            return
        }

        do {
            // Decode the simple JSON structure
            let levelsContainer = try JSONDecoder().decode(LevelsContainer.self, from: data)

            // Convert to AnyGameLevel based on game type
            let anyLevels = try convertToAnyGameLevels(levelsContainer.levels, for: gameType)
            gameLevels[gameType] = anyLevels

            print("✅ Loaded \(anyLevels.count) levels for \(gameType.displayName)")
        } catch {
            print("❌ Failed to decode \(gameType.displayName) levels: \(error)")
            print("🔄 Creating mock data for \(gameType.displayName)")
            gameLevels[gameType] = createMockLevels(for: gameType)
        }
    }

    // MARK: - JSON Conversion

    private func convertToAnyGameLevels(_ levels: [LevelData], for gameType: GameType) throws -> [AnyGameLevel] {
        return try levels.map { level in
            switch gameType {
            case .shikaku:
                let shikakuLevel = ShikakuLevelData(
                    id: level.id,
                    difficulty: level.difficulty,
                    gridRows: level.gridRows,
                    gridCols: level.gridCols,
                    clues: level.clues.map { clue in
                        ShikakuLevelData.ClueData(
                            row: clue.row,
                            col: clue.col,
                            value: clue.value
                        )
                    }
                )
                return try AnyGameLevel(shikakuLevel)

            case .pipe:
                let pipeLevel = PipeLevelData(
                    id: level.id,
                    difficulty: level.difficulty,
                    gridSize: max(level.gridRows, level.gridCols),
                    pipes: [] // Convert clues to pipes if needed
                )
                return try AnyGameLevel(pipeLevel)

            case .binario:
                let binarioLevel = BinarioLevelData(
                    id: level.id,
                    difficulty: level.difficulty,
                    gridSize: max(level.gridRows, level.gridCols),
                    initialGrid: []
                )
                return try AnyGameLevel(binarioLevel)

            case .wordle:
                let wordleLevel = WordleLevelData(
                    id: level.id,
                    difficulty: level.difficulty,
                    targetWord: "SWIFT", // You'll need to add this to your JSON
                    maxAttempts: 6
                )
                return try AnyGameLevel(wordleLevel)
            }
        }
    }

    // MARK: - Mock Level Creation

    private func createMockLevels(for gameType: GameType) -> [AnyGameLevel] {
        var levels: [AnyGameLevel] = []

        for i in 1...100 {
            let difficulty = ((i - 1) / 20) + 1 // 20 levels per difficulty
            do {
                let levelData: any GameLevelData

                switch gameType {
                case .shikaku:
                    levelData = ShikakuLevelData(
                        id: "shikaku_\(i)",
                        difficulty: difficulty,
                        gridRows: 6 + difficulty,
                        gridCols: 4 + difficulty,
                        clues: generateMockClues(gridRows: 6 + difficulty, gridCols: 4 + difficulty)
                    )
                case .pipe:
                    levelData = PipeLevelData(
                        id: "pipe_\(i)",
                        difficulty: difficulty,
                        gridSize: 4 + difficulty,
                        pipes: []
                    )
                case .binario:
                    levelData = BinarioLevelData(
                        id: "binario_\(i)",
                        difficulty: difficulty,
                        gridSize: 6 + (difficulty * 2),
                        initialGrid: []
                    )
                case .wordle:
                    levelData = WordleLevelData(
                        id: "wordle_\(i)",
                        difficulty: difficulty,
                        targetWord: "SWIFT",
                        maxAttempts: 6
                    )
                }

                let anyLevel = try AnyGameLevel(levelData)
                levels.append(anyLevel)
            } catch {
                print("❌ Failed to create mock level for \(gameType.displayName): \(error)")
            }
        }

        print("✅ Created \(levels.count) mock levels for \(gameType.displayName)")
        return levels
    }

    // Helper function to generate mock clues for Shikaku
    private func generateMockClues(gridRows: Int, gridCols: Int) -> [ShikakuLevelData.ClueData] {
        var clues: [ShikakuLevelData.ClueData] = []
        let numberOfClues = max(3, (gridRows * gridCols) / 8) // Roughly 1 clue per 8 cells

        for _ in 0..<numberOfClues {
            let row = Int.random(in: 0..<gridRows)
            let col = Int.random(in: 0..<gridCols)
            let value = Int.random(in: 2...8) // Rectangle sizes from 2 to 8

            clues.append(ShikakuLevelData.ClueData(row: row, col: col, value: value))
        }

        return clues
    }

    // MARK: - Daily Level Distribution

    func getLevelForDate(_ date: Date, gameType: GameType) -> AnyGameLevel? {
        guard let levels = gameLevels[gameType], !levels.isEmpty else {
            print("❌ No levels available for \(gameType.displayName)")
            return nil
        }

        // Calculate deterministic index based on date
        let dayOffset = calendar.dateComponents([.day], from: referenceDate, to: date).day ?? 0
        let adjustedOffset = dayOffset + 100
        let levelIndex = ((adjustedOffset % levels.count) + levels.count) % levels.count

        return levels[levelIndex]
    }

    func getAllLevelsForGame(_ gameType: GameType) -> [AnyGameLevel] {
        return gameLevels[gameType] ?? []
    }

    func getRandomLevelForGame(_ gameType: GameType, excluding excludedIds: Set<String> = []) -> AnyGameLevel? {
        guard let levels = gameLevels[gameType], !levels.isEmpty else { return nil }

        let availableLevels = levels.filter { !excludedIds.contains($0.id) }

        if availableLevels.isEmpty {
            // If all levels completed, return random from all levels
            return levels.randomElement()
        }

        return availableLevels.randomElement()
    }

    func getLevelById(_ id: String, gameType: GameType) -> AnyGameLevel? {
        return gameLevels[gameType]?.first { $0.id == id }
    }

    // MARK: - Statistics

    func getTotalLevelsCount(for gameType: GameType) -> Int {
        return gameLevels[gameType]?.count ?? 0
    }

    func getDifficultyDistribution(for gameType: GameType) -> [Int: Int] {
        guard let levels = gameLevels[gameType] else { return [:] }

        var distribution: [Int: Int] = [:]
        for level in levels {
            distribution[level.difficulty, default: 0] += 1
        }
        return distribution
    }
}

// MARK: - JSON Data Structures for Parsing

struct LevelsContainer: Codable {
    let levels: [LevelData]
}

struct LevelData: Codable {
    let id: String
    let gridRows: Int
    let gridCols: Int
    let difficulty: Int
    let clues: [ClueData]
}

struct ClueData: Codable {
    let row: Int
    let col: Int
    let value: Int
}

// MARK: - Game Level Data Structures (Keep your existing ones, just remove estimatedTime)

struct ShikakuLevelData: GameLevelData {
    let id: String
    let difficulty: Int
    let gridRows: Int
    let gridCols: Int
    let clues: [ClueData]

    struct ClueData: Codable {
        let row: Int
        let col: Int
        let value: Int
    }
}

struct PipeLevelData: GameLevelData {
    let id: String
    let difficulty: Int
    let gridSize: Int
    let pipes: [PipeData]

    struct PipeData: Codable {
        let row: Int
        let col: Int
        let connections: [Direction]
    }

    enum Direction: String, Codable {
        case up, down, left, right
    }
}

struct BinarioLevelData: GameLevelData {
    let id: String
    let difficulty: Int
    let gridSize: Int
    let initialGrid: [[Int?]]

    init(id: String, difficulty: Int, gridSize: Int, initialGrid: [[Int?]]) {
        self.id = id
        self.difficulty = difficulty
        self.gridSize = gridSize
        self.initialGrid = initialGrid.isEmpty ? Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize) : initialGrid
    }
}

struct WordleLevelData: GameLevelData {
    let id: String
    let difficulty: Int
    let targetWord: String
    let maxAttempts: Int
}
