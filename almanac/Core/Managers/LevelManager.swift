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
                    gridSize: max(level.gridRows, level.gridCols),
                    pipes: [] // Convert clues to pipes if needed
                )
                return try AnyGameLevel(pipeLevel)

            case .wordle:
                let wordleLevel = WordleLevelData(
                    id: level.id,
                    targetWord: generateWordFromId(level.id),
                    maxAttempts: 6
                )
                return try AnyGameLevel(wordleLevel)

            case .sets:
                let setsLevel = SetsLevelData(
                    id: level.id
                )
                return try AnyGameLevel(setsLevel)
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
                        gridRows: 6 ,
                        gridCols: 4,
                        clues: generateMockClues(gridRows: 6 + difficulty, gridCols: 4 + difficulty)
                    )
                case .pipe:
                    levelData = PipeLevelData(
                        id: "pipe_\(i)",
                        gridSize: 4,
                        pipes: []
                    )
                case .wordle:
                    levelData = WordleLevelData(
                        id: "wordle_\(i)",
                        targetWord: generateRandomWord(difficulty: difficulty),
                        maxAttempts: 6
                    )
                case .sets:
                    levelData = SetsLevelData(
                        id: "sets_\(i)"
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

    // Helper function to generate word from level ID for deterministic daily words
    private func generateWordFromId(_ id: String) -> String {
        // Get valid 5-letter words from the dictionary
        let fiveLetterWords = DictionaryManager.shared.getFiveLetterWords()

        guard !fiveLetterWords.isEmpty else {
            return "SWIFT"
        }

        // Create a deterministic hash from the level ID
        var hash: UInt32 = 5381
        for char in id.utf8 {
            hash = hash &* 33 &+ UInt32(char)
        }

        let index = Int(hash) % fiveLetterWords.count
        return fiveLetterWords[index]
    }

    // Helper function to generate random word based on difficulty
    private func generateRandomWord(difficulty: Int) -> String {
        let wordsByDifficulty = [
            1: ["APPLE", "HAPPY", "LIGHT", "MUSIC", "PEACE"],
            2: ["SWIFT", "BRAVE", "GRACE", "TRUST", "DANCE"],
            3: ["WORLD", "DREAM", "MAGIC", "POWER", "YOUTH"],
            4: ["PHONE", "SMILE", "HEART", "HONOR", "SHINE"],
            5: ["QUEST", "BLEND", "FROST", "SPARK", "STORM"]
        ]

        let words = wordsByDifficulty[difficulty] ?? wordsByDifficulty[3]!
        return words.randomElement() ?? "SWIFT"
    }

    // MARK: - Daily Level Distribution

    func getLevelForDate(_ date: Date, gameType: GameType) -> AnyGameLevel? {
        guard let levels = gameLevels[gameType], !levels.isEmpty else {
            print("❌ No levels available for \(gameType.displayName)")
            return nil
        }

        // For Wordle, create a special deterministic daily level based on date
        if gameType == .wordle {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)

            // Create deterministic level ID based on date
            let levelId = "wordle_daily_\(dateString)"

            // Generate deterministic word for this specific date
            let dailyWord = generateDeterministicWordForDate(date)

            do {
                let wordleLevel = WordleLevelData(
                    id: levelId,
                    targetWord: dailyWord,
                    maxAttempts: 5
                )
                return try AnyGameLevel(wordleLevel)
            } catch {
                print("❌ Failed to create daily Wordle level: \(error)")
            }
        }

        // Calculate deterministic index based on date for other games
        let dayOffset = calendar.dateComponents([.day], from: referenceDate, to: date).day ?? 0
        let adjustedOffset = dayOffset + 100
        let levelIndex = ((adjustedOffset % levels.count) + levels.count) % levels.count

        return levels[levelIndex]
    }

    // Generate a deterministic word based on the specific date
    private func generateDeterministicWordForDate(_ date: Date) -> String {
        // Get valid 5-letter words from the dictionary
        let fiveLetterWords = DictionaryManager.shared.getFiveLetterWords()

        guard !fiveLetterWords.isEmpty else {
            // Fallback if dictionary loading fails
            return "SWIFT"
        }

        // Use days since reference date as seed for deterministic selection
        let referenceDate = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let daysSinceReference = Calendar.current.dateComponents([.day], from: referenceDate, to: date).day ?? 0

        // Use a prime number multiplier for better distribution
        let index = abs(daysSinceReference * 37) % fiveLetterWords.count
        return fiveLetterWords[index]
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
    let gridSize: Int
    let initialGrid: [[Int?]]

    init(id: String, difficulty: Int, gridSize: Int, initialGrid: [[Int?]]) {
        self.id = id
        self.gridSize = gridSize
        self.initialGrid = initialGrid.isEmpty ? Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize) : initialGrid
    }
}

// MARK: - Sets Level Data Structure

struct SetsLevelData: GameLevelData {
    let id: String
    init(id: String) {
        self.id = id
    }
}

// MARK: - Legacy WordleLevelData (Remove this later)

struct WordleLevelData: GameLevelData {
    let id: String
    let targetWord: String
    let maxAttempts: Int
}
