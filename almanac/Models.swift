//
//  CoreModels.swift
//  Multi-Game Puzzle App
//
//  Core data models for the multi-game shell
//

import SwiftUI
import SwiftData
import Foundation

// MARK: - Game Types

enum GameType: String, CaseIterable, Codable {
    case shikaku = "shikaku"
    case pipe = "pipe"
    case binario = "binario"
    case sets = "Sets"

    var displayName: String {
        switch self {
        case .shikaku: return "Shikaku"
        case .pipe: return "Pipe"
        case .binario: return "Binario"
        case .sets: return "Sets"
        }
    }

    var icon: String {
        switch self {
        case .shikaku: return "rectangle.grid.3x2"
        case .pipe: return "arrow.triangle.turn.up.right.diamond"
        case .binario: return "01.circle"
        case .sets: return "staroflife.fill"
        }
    }

    var color: Color {
        switch self {
        case .shikaku: return .brown
        case .pipe: return .cyan
        case .binario: return .orange
        case .sets: return .purple
        }
    }

    var jsonFileName: String {
        return "\(rawValue)_levels.json"
    }
}

// MARK: - JSON Level Structure

protocol GameLevelData: Codable {
    var id: String { get }
    var difficulty: Int { get }
}

// Generic container for all game levels
struct GameLevelsContainer: Codable {
    let gameType: GameType
    let levels: [AnyGameLevel]
}

// Type-erased wrapper for different game level types
struct AnyGameLevel: Codable {
    let id: String
    let difficulty: Int
    let gameData: Data

    init<T: GameLevelData>(_ level: T) throws {
        self.id = level.id
        self.difficulty = level.difficulty
        self.gameData = try JSONEncoder().encode(level)
    }

    func decode<T: GameLevelData>(as type: T.Type) throws -> T {
        return try JSONDecoder().decode(type, from: gameData)
    }
}

// MARK: - SwiftData Models

@Model
final class GameLevel {
    var id: UUID
    var gameType: GameType
    var date: Date
    var levelDataId: String
    var difficulty: Int
    var isCompleted: Bool
    var completionTime: TimeInterval?
    var completedAt: Date?

    init(gameType: GameType, date: Date, levelDataId: String, difficulty: Int, estimatedTime: TimeInterval) {
        self.id = UUID()
        self.gameType = gameType
        self.date = date
        self.levelDataId = levelDataId
        self.difficulty = difficulty
        self.isCompleted = false
        self.completionTime = nil
        self.completedAt = nil
    }

    func markCompleted(in time: TimeInterval) {
        isCompleted = true
        completionTime = time
        completedAt = Date()
    }
}

@Model
final class GameProgress {
    var id: UUID
    var gameType: GameType
    var totalCompleted: Int
    var currentStreak: Int
    var maxStreak: Int
    var bestTime: TimeInterval?
    var averageTime: TimeInterval?
    var lastPlayedDate: Date?

    init(gameType: GameType) {
        self.id = UUID()
        self.gameType = gameType
        self.totalCompleted = 0
        self.currentStreak = 0
        self.maxStreak = 0
        self.bestTime = nil
        self.averageTime = nil
        self.lastPlayedDate = nil
    }

    func updateProgress(completionTime: TimeInterval) {
        totalCompleted += 1
        lastPlayedDate = Date()

        // Update best time
        if bestTime == nil || completionTime < bestTime! {
            bestTime = completionTime
        }

        // Update average time (simple running average)
        if averageTime == nil {
            averageTime = completionTime
        } else {
            averageTime = ((averageTime! * Double(totalCompleted - 1)) + completionTime) / Double(totalCompleted)
        }
    }
}

@Model
final class DailyCompletion {
    var id: UUID
    var date: Date
    var gameType: GameType
    var levelDataId: String
    var completionTime: TimeInterval
    var completedAt: Date

    init(date: Date, gameType: GameType, levelDataId: String, completionTime: TimeInterval) {
        self.id = UUID()
        self.date = date
        self.gameType = gameType
        self.levelDataId = levelDataId
        self.completionTime = completionTime
        self.completedAt = Date()
    }
}
