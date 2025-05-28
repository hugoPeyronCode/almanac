//
//  LevelManager.swift
//  Multi-Game Puzzle App
//
//  Manages loading and distribution of game levels from JSON files
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
            let container = try JSONDecoder().decode(GameLevelsContainer.self, from: data)
            gameLevels[gameType] = container.levels
            print("✅ Loaded \(container.levels.count) levels for \(gameType.displayName)")
        } catch {
            print("❌ Failed to decode \(gameType.displayName) levels: \(error)")
            print("🔄 Creating mock data for \(gameType.displayName)")
            gameLevels[gameType] = createMockLevels(for: gameType)
        }
    }

    // MARK: - Mock Level Creation

    private func createMockLevels(for gameType: GameType) -> [AnyGameLevel] {
        var levels: [AnyGameLevel] = []

        for i in 1...100 {
            let difficulty = ((i - 1) / 20) + 1 // 20 levels per difficulty
            let estimatedTime = TimeInterval(30 + (difficulty * 20) + Int.random(in: -10...30))

            do {
                let levelData: any GameLevelData

                switch gameType {
                case .shikaku:
                    levelData = ShikakuLevelData(
                        id: "shikaku_\(i)",
                        difficulty: difficulty,
                        estimatedTime: estimatedTime,
                        gridRows: 6 + difficulty,
                        gridCols: 4 + difficulty,
                        clues: generateMockClues(gridRows: 6 + difficulty, gridCols: 4 + difficulty)
                    )
                case .pipe:
                    levelData = PipeLevelData(
                        id: "pipe_\(i)",
                        difficulty: difficulty,
                        estimatedTime: estimatedTime,
                        gridSize: 4 + difficulty,
                        pipes: []
                    )
                case .binario:
                    levelData = BinarioLevelData(
                        id: "binario_\(i)",
                        difficulty: difficulty,
                        estimatedTime: estimatedTime,
                        gridSize: 6 + (difficulty * 2),
                        initialGrid: []
                    )
                case .wordle:
                    levelData = WordleLevelData(
                        id: "wordle_\(i)",
                        difficulty: difficulty,
                        estimatedTime: estimatedTime,
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
        let adjustedOffset = dayOffset + 100 // Add offset to avoid negative numbers
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

    func getAverageEstimatedTime(for gameType: GameType, difficulty: Int? = nil) -> TimeInterval {
        guard let levels = gameLevels[gameType] else { return 0 }

        let filteredLevels = difficulty != nil
            ? levels.filter { $0.difficulty == difficulty }
            : levels

        guard !filteredLevels.isEmpty else { return 0 }

        let totalTime = filteredLevels.reduce(0) { $0 + $1.estimatedTime }
        return totalTime / Double(filteredLevels.count)
    }
}

// MARK: - Game Level Data Structures

struct ShikakuLevelData: GameLevelData {
    let id: String
    let difficulty: Int
    let estimatedTime: TimeInterval
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
    let estimatedTime: TimeInterval
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
    let estimatedTime: TimeInterval
    let gridSize: Int
    let initialGrid: [[Int?]] // nil = empty, 0 = zero, 1 = one

    init(id: String, difficulty: Int, estimatedTime: TimeInterval, gridSize: Int, initialGrid: [[Int?]]) {
        self.id = id
        self.difficulty = difficulty
        self.estimatedTime = estimatedTime
        self.gridSize = gridSize
        self.initialGrid = initialGrid.isEmpty ? Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize) : initialGrid
    }
}

struct WordleLevelData: GameLevelData {
    let id: String
    let difficulty: Int
    let estimatedTime: TimeInterval
    let targetWord: String
    let maxAttempts: Int
}
