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
    case wordle = "wordle"
    case sets = "Sets"

    var displayName: String {
        switch self {
        case .shikaku: return "Shikaku"
        case .pipe: return "Pipe"
        case .wordle: return "Wordle"
        case .sets: return "Sets"
        }
    }

    var icon: String {
        switch self {
        case .shikaku: return "rectangle.grid.3x2"
        case .pipe: return "arrow.triangle.turn.up.right.diamond"
        case .wordle: return "01.circle"
        case .sets: return "staroflife.fill"
        }
    }

    var color: Color {
        switch self {
        case .shikaku: return .brown
        case .pipe: return .cyan
        case .wordle: return .orange
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

// MARK: - Practice Mode Models

@Model
final class PracticeSession {
    var id: UUID
    var gameType: GameType
    var levelDataId: String
    var completionTime: TimeInterval
    var startedAt: Date
    var completedAt: Date
    var isCompleted: Bool
    
    init(gameType: GameType, levelDataId: String) {
        self.id = UUID()
        self.gameType = gameType
        self.levelDataId = levelDataId
        self.completionTime = 0
        self.startedAt = Date()
        self.completedAt = Date()
        self.isCompleted = false
    }
    
    func markCompleted(in time: TimeInterval) {
        isCompleted = true
        completionTime = time
        completedAt = Date()
    }
}

@Model
final class PracticeProgress {
    var id: UUID
    var gameType: GameType
    var totalSessions: Int
    var completedSessions: Int
    var totalPlayTime: TimeInterval
    var bestTime: TimeInterval?
    var averageTime: TimeInterval?
    var lastPlayedDate: Date?
    
    init(gameType: GameType) {
        self.id = UUID()
        self.gameType = gameType
        self.totalSessions = 0
        self.completedSessions = 0
        self.totalPlayTime = 0
        self.bestTime = nil
        self.averageTime = nil
        self.lastPlayedDate = nil
    }
    
    func updateProgress(session: PracticeSession) {
        totalSessions += 1
        lastPlayedDate = Date()
        
        if session.isCompleted {
            completedSessions += 1
            totalPlayTime += session.completionTime
            
            // Update best time
            if bestTime == nil || session.completionTime < bestTime! {
                bestTime = session.completionTime
            }
            
            // Update average time
            if completedSessions > 0 {
                averageTime = totalPlayTime / Double(completedSessions)
            }
        }
    }
}

// MARK: - Player Profile Models

@Model
final class PlayerProfile {
    var id: UUID
    var username: String
    var level: Int
    var experience: Int
    var backgroundImageName: String
    var createdAt: Date
    var lastUpdated: Date
    
    init(username: String = "Player") {
        self.id = UUID()
        self.username = username
        self.level = 1
        self.experience = 0
        self.backgroundImageName = "dotsBackgroundWhite"
        self.createdAt = Date()
        self.lastUpdated = Date()
    }
    
    func addExperience(_ points: Int) {
        experience += points
        // Level up every 1000 XP
        let newLevel = (experience / 1000) + 1
        if newLevel > level {
            level = newLevel
        }
        lastUpdated = Date()
    }
}

// MARK: - Badge System

enum BadgeType: String, CaseIterable, Codable {
    case firstWin = "first_win"
    case weekStreak = "week_streak"
    case monthStreak = "month_streak"
    case speedDemon = "speed_demon"
    case perfectWeek = "perfect_week"
    case puzzleMaster = "puzzle_master"
    case marathonRunner = "marathon_runner"
    case sprinter = "sprinter"
    case allGamesDaily = "all_games_daily"
    case hundredPuzzles = "hundred_puzzles"
    
    var name: String {
        switch self {
        case .firstWin: return "First Victory"
        case .weekStreak: return "Week Warrior"
        case .monthStreak: return "Monthly Master"
        case .speedDemon: return "Speed Demon"
        case .perfectWeek: return "Perfect Week"
        case .puzzleMaster: return "Puzzle Master"
        case .marathonRunner: return "Marathon Runner"
        case .sprinter: return "Sprint Champion"
        case .allGamesDaily: return "Versatile Player"
        case .hundredPuzzles: return "Century Club"
        }
    }
    
    var description: String {
        switch self {
        case .firstWin: return "Complete your first puzzle"
        case .weekStreak: return "Maintain a 7-day streak"
        case .monthStreak: return "Maintain a 30-day streak"
        case .speedDemon: return "Complete any puzzle under 1 minute"
        case .perfectWeek: return "Complete all daily puzzles for 7 days"
        case .puzzleMaster: return "Reach level 10"
        case .marathonRunner: return "Complete 10 puzzles in Marathon mode"
        case .sprinter: return "Complete 5 puzzles in Sprint mode under 5 minutes"
        case .allGamesDaily: return "Complete all 4 game types in one day"
        case .hundredPuzzles: return "Complete 100 puzzles total"
        }
    }
    
    var icon: String {
        switch self {
        case .firstWin: return "star.fill"
        case .weekStreak: return "flame.fill"
        case .monthStreak: return "flame.circle.fill"
        case .speedDemon: return "bolt.fill"
        case .perfectWeek: return "crown.fill"
        case .puzzleMaster: return "brain"
        case .marathonRunner: return "figure.run"
        case .sprinter: return "hare.fill"
        case .allGamesDaily: return "square.grid.2x2.fill"
        case .hundredPuzzles: return "100.circle.fill"
        }
    }
    
    var requiredPoints: Int {
        switch self {
        case .firstWin: return 10
        case .weekStreak: return 50
        case .monthStreak: return 200
        case .speedDemon: return 30
        case .perfectWeek: return 100
        case .puzzleMaster: return 500
        case .marathonRunner: return 75
        case .sprinter: return 50
        case .allGamesDaily: return 40
        case .hundredPuzzles: return 150
        }
    }
}

@Model
final class PlayerBadge {
    var id: UUID
    var type: BadgeType
    var unlockedAt: Date
    var isNew: Bool
    
    init(type: BadgeType) {
        self.id = UUID()
        self.type = type
        self.unlockedAt = Date()
        self.isNew = true
    }
}

// MARK: - Practice Mode Types

enum PracticeMode: String, CaseIterable {
    case normal = "normal"
    case marathon = "marathon"
    case sprint = "sprint"
    
    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .marathon: return "Marathon"
        case .sprint: return "Sprint"
        }
    }
    
    var description: String {
        switch self {
        case .normal: return "Practice at your own pace"
        case .marathon: return "How many can you complete in a row?"
        case .sprint: return "Complete 5 puzzles as fast as possible"
        }
    }
    
    var icon: String {
        switch self {
        case .normal: return "play.circle"
        case .marathon: return "infinity"
        case .sprint: return "timer"
        }
    }
}
