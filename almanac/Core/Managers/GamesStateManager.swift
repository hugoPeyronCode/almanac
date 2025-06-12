//
//  GamesStateManager.swift
//  almanac
//
//  Created by Hugo Peyron on 12/06/2025.
//

import SwiftUI
import SwiftData

// MARK: - Generic Game State Protocol
protocol PersistableGameState {
    associatedtype GameData: Codable

    var sessionId: String { get }
    var gameType: GameType { get }
    var dateString: String { get }
    var isCompleted: Bool { get }
    var lastUpdated: Date { get }

    func getGameData() -> GameData?
    func setGameData(_ data: GameData)
}

// MARK: - Wordle State Models

@Model
final class WordleGameState {
    var id: UUID
    var sessionId: String
    var gameType: GameType
    var dateString: String

    // Game state
    var guessesData: Data // Encoded [String]
    var currentAttempt: String
    var isCompleted: Bool
    var isWon: Bool
    var lastUpdated: Date

    // For deterministic daily puzzles
    var targetWord: String

    init(sessionId: String, gameType: GameType, dateString: String = "", targetWord: String = "") {
        self.id = UUID()
        self.sessionId = sessionId
        self.gameType = gameType
        self.dateString = dateString
        self.targetWord = targetWord
        self.guessesData = Data()
        self.currentAttempt = ""
        self.isCompleted = false
        self.isWon = false
        self.lastUpdated = Date()
    }

    func setGuesses(_ guesses: [String]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(guesses) {
            guessesData = encoded
            lastUpdated = Date()
        }
    }

    func getGuesses() -> [String] {
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode([String].self, from: guessesData) else {
            return []
        }
        return decoded
    }
}

// MARK: - Shikaku State Models

@Model
final class ShikakuGameState {
    var id: UUID
    var sessionId: String
    var gameType: GameType
    var dateString: String

    // Game state
    var rectanglesData: Data // Encoded [SavedRectangle]
    var isCompleted: Bool
    var lastUpdated: Date

    // Level configuration for daily consistency
    var gridRows: Int
    var gridCols: Int
    var cluesData: Data // Encoded [SavedClue]

    init(sessionId: String, gameType: GameType, dateString: String = "") {
        self.id = UUID()
        self.sessionId = sessionId
        self.gameType = gameType
        self.dateString = dateString
        self.rectanglesData = Data()
        self.cluesData = Data()
        self.isCompleted = false
        self.lastUpdated = Date()
        self.gridRows = 5
        self.gridCols = 5
    }

    func setRectangles(_ rectangles: [SavedRectangle]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(rectangles) {
            rectanglesData = encoded
            lastUpdated = Date()
        }
    }

    func getRectangles() -> [SavedRectangle] {
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode([SavedRectangle].self, from: rectanglesData) else {
            return []
        }
        return decoded
    }

    func setClues(_ clues: [SavedClue]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(clues) {
            cluesData = encoded
        }
    }

    func getClues() -> [SavedClue] {
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode([SavedClue].self, from: cluesData) else {
            return []
        }
        return decoded
    }
}

// Codable representations for Shikaku
struct SavedRectangle: Codable {
    let topLeftRow: Int
    let topLeftCol: Int
    let bottomRightRow: Int
    let bottomRightCol: Int
    let colorIndex: Int

    init(from rect: GameRectangle, colorIndex: Int) {
        self.topLeftRow = rect.topLeft.row
        self.topLeftCol = rect.topLeft.col
        self.bottomRightRow = rect.bottomRight.row
        self.bottomRightCol = rect.bottomRight.col
        self.colorIndex = colorIndex
    }

    func toGameRectangle(with colorPalette: [Color]) -> GameRectangle {
        var rect = GameRectangle(
            topLeft: GridPosition(row: topLeftRow, col: topLeftCol),
            bottomRight: GridPosition(row: bottomRightRow, col: bottomRightCol)
        )
        rect.color = colorPalette[colorIndex % colorPalette.count]
        return rect
    }
}

struct SavedClue: Codable {
    let row: Int
    let col: Int
    let value: Int

    init(from clue: NumberClue) {
        self.row = clue.position.row
        self.col = clue.position.col
        self.value = clue.value
    }

    func toNumberClue() -> NumberClue {
        return NumberClue(
            position: GridPosition(row: row, col: col),
            value: value
        )
    }
}

// MARK: - Generic State Manager

class GameStateManager<T> {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func generateStateId(for session: GameSession) -> String {
        switch session.context {
        case .daily(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return "\(session.gameType.rawValue)_daily_\(formatter.string(from: date))"
        case .practice:
            return "\(session.gameType.rawValue)_practice_\(session.id.uuidString)"
        case .random:
            return "\(session.gameType.rawValue)_random_\(session.id.uuidString)"
        }
    }

    func generateDailySeed(for date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let seed = (components.year ?? 2024) * 10000 +
                   (components.month ?? 1) * 100 +
                   (components.day ?? 1)
        return seed
    }
}


@Model
final class SetsGameState {
    var id: UUID
    var sessionId: String
    var gameType: GameType
    var dateString: String // For daily challenges

    // Game state
    var foundSetsData: Data // Encoded [[SetCard]]
    var hintsUsed: Int
    var lifes: Int
    var lastUpdated: Date
    var isCompleted: Bool

    // For deterministic daily puzzles
    var randomSeed: Int?

    init(sessionId: String, gameType: GameType, dateString: String = "") {
        self.id = UUID()
        self.sessionId = sessionId
        self.gameType = gameType
        self.dateString = dateString
        self.foundSetsData = Data()
        self.hintsUsed = 0
        self.lifes = 3
        self.lastUpdated = Date()
        self.isCompleted = false
        self.randomSeed = nil
    }

    // Helper methods for encoding/decoding found sets
    func setFoundSets(_ sets: [[SetCard]]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(sets.map { $0.map { CardData(from: $0) } }) {
            foundSetsData = encoded
            lastUpdated = Date()
        }
    }

    func getFoundSets() -> [[SetCard]] {
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode([[CardData]].self, from: foundSetsData) else {
            return []
        }
        return decoded.map { $0.map { $0.toSetCard() } }
    }
}

// Codable representation of SetCard for persistence
struct CardData: Codable {
    let color: SetColor
    let shape: SetShape
    let shading: SetShading
    let count: SetCount

    init(from card: SetCard) {
        self.color = card.color
        self.shape = card.shape
        self.shading = card.shading
        self.count = card.count
    }

    func toSetCard() -> SetCard {
        return SetCard(
            color: color,
            shape: shape,
            shading: shading,
            count: count
        )
    }
}

// Extension to make SetCard comparable for deterministic generation
extension SetCard: Comparable {
    static func < (lhs: SetCard, rhs: SetCard) -> Bool {
        if lhs.color.rawValue != rhs.color.rawValue {
            return lhs.color.rawValue < rhs.color.rawValue
        }
        if lhs.shape.rawValue != rhs.shape.rawValue {
            return lhs.shape.rawValue < rhs.shape.rawValue
        }
        if lhs.shading.rawValue != rhs.shading.rawValue {
            return lhs.shading.rawValue < rhs.shading.rawValue
        }
        return lhs.count.rawValue < rhs.count.rawValue
    }
}

// Manager for Sets game state persistence
class SetsGameStateManager {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func saveState(for session: GameSession, game: SetsGame) {
        let stateId = generateStateId(for: session)

        // Try to fetch existing state
        let descriptor = FetchDescriptor<SetsGameState>(
            predicate: #Predicate { state in
                state.sessionId == stateId
            }
        )

        let state: SetsGameState
        if let existingState = try? modelContext.fetch(descriptor).first {
            state = existingState
        } else {
            state = SetsGameState(
                sessionId: stateId,
                gameType: session.gameType,
                dateString: session.context.date?.ISO8601Format() ?? ""
            )
            modelContext.insert(state)
        }

        // Update state
        state.setFoundSets(game.foundSets)
        state.hintsUsed = game.hintsUsed
        state.lifes = game.lifes
        state.isCompleted = game.isGameComplete
        state.lastUpdated = Date()

        // Save random seed for daily challenges
        if case .daily(let date) = session.context {
            state.randomSeed = generateDailySeed(for: date)
        }

        try? modelContext.save()
    }

    func loadState(for session: GameSession, into game: SetsGame) -> Bool {
        let stateId = generateStateId(for: session)

        let descriptor = FetchDescriptor<SetsGameState>(
            predicate: #Predicate { state in
                state.sessionId == stateId
            }
        )

        guard let state = try? modelContext.fetch(descriptor).first else {
            return false
        }

        // Restore game state
        game.foundSets = state.getFoundSets()
        game.hintsUsed = state.hintsUsed
        game.lifes = state.lifes
        game.isGameComplete = state.isCompleted
        game.isGameOver = state.lifes <= 0
        game.setsFound = game.foundSets.count

        return true
    }

    func clearState(for session: GameSession) {
        let stateId = generateStateId(for: session)

        let descriptor = FetchDescriptor<SetsGameState>(
            predicate: #Predicate { state in
                state.sessionId == stateId
            }
        )

        if let state = try? modelContext.fetch(descriptor).first {
            modelContext.delete(state)
            try? modelContext.save()
        }
    }

    func getDailySeed(for date: Date) -> Int {
        return generateDailySeed(for: date)
    }

    private func generateStateId(for session: GameSession) -> String {
        switch session.context {
        case .daily(let date):
            // For daily challenges, use date as identifier
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return "sets_daily_\(formatter.string(from: date))"
        case .practice:
            // For practice, use session ID
            return "sets_practice_\(session.id.uuidString)"
        case .random:
            return "sets_random_\(session.id.uuidString)"
        }
    }

    private func generateDailySeed(for date: Date) -> Int {
        // Generate consistent seed based on date
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let seed = (components.year ?? 2024) * 10000 +
                   (components.month ?? 1) * 100 +
                   (components.day ?? 1)
        return seed
    }
}

// Seeded random number generator for deterministic deck generation
struct SeededRandomGenerator {
    private var seed: UInt64

    init(seed: Int) {
        self.seed = UInt64(abs(seed))
    }

    mutating func next() -> UInt64 {
        // Linear congruential generator
        seed = (seed &* 1664525 &+ 1013904223) & 0xFFFFFFFF
        return seed
    }

    mutating func nextDouble() -> Double {
        return Double(next()) / Double(UInt64.max)
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        let width = range.upperBound - range.lowerBound
        return range.lowerBound + Int(next() % UInt64(width))
    }
}
