//
//  StatisticsManager.swift
//  almanac
//
//  Comprehensive statistics and streak management
//

import SwiftUI
import SwiftData
import Foundation

// MARK: - Statistics Models

struct GameStatistics {
    let gameType: GameType
    let totalCompletions: Int
    let totalPlayTime: TimeInterval
    let averageTime: TimeInterval
    let bestTime: TimeInterval?
    let currentStreak: Int
    let maxStreak: Int
    let completionRate: Double // Over selected period
    let lastPlayedDate: Date?
}

struct AllGamesStatistics {
    let totalPlayTime: TimeInterval
    let totalCompletions: Int
    let completedDays: Int
    let currentAllGamesStreak: Int
    let maxAllGamesStreak: Int
    let averageCompletionsPerDay: Double
    let gamesStatistics: [GameStatistics]
}

enum StatisticsPeriod: String, CaseIterable {
    case today = "today"
    case thisWeek = "thisWeek"
    case thisMonth = "thisMonth"
    case allTime = "allTime"
    
    var displayName: String {
        switch self {
        case .today: return "Aujourd'hui"
        case .thisWeek: return "Cette semaine"
        case .thisMonth: return "Ce mois"
        case .allTime: return "Tout temps"
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
            
        case .thisWeek:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!
            return (start, end)
            
        case .thisMonth:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
            
        case .allTime:
            let start = calendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!
            let end = calendar.date(byAdding: .year, value: 10, to: now)!
            return (start, end)
        }
    }
}

// MARK: - Statistics Manager

@Observable
class StatisticsManager {
    private let modelContext: ModelContext
    private let calendar = Calendar.current
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Individual Game Streaks
    
    func calculateCurrentStreak(for gameType: GameType) -> Int {
        print("🔍 Calculating current streak for \(gameType.displayName)")
        
        // Get all completions for this game type and find the most recent date
        let completions = getAllCompletions(for: gameType)
        guard !completions.isEmpty else {
            print("   ❌ No completions found, returning 0")
            return 0
        }
        
        // Group completions by date and get unique dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let completedDates = Set(completions.map { completion in
            dateFormatter.string(from: calendar.startOfDay(for: completion.date))
        })
        
        let sortedDates = completedDates.sorted(by: >)  // Most recent first
        print("   📅 Completed dates: \(sortedDates)")
        
        guard let mostRecentDateString = sortedDates.first,
              let mostRecentDate = dateFormatter.date(from: mostRecentDateString) else {
            print("   ❌ Can't parse most recent date")
            return 0
        }
        
        let today = calendar.startOfDay(for: Date())
        print("   📅 Most recent completion: \(mostRecentDate)")
        print("   📅 Today: \(today)")
        
        // If most recent completion is more than 1 day ago from today, streak is broken
        let daysBetween = calendar.dateComponents([.day], from: mostRecentDate, to: today).day ?? 0
        if daysBetween > 1 {
            print("   💔 Streak broken - \(daysBetween) days gap")
            return 0
        }
        
        // Count consecutive days backwards from most recent completion
        var streakCount = 0
        var checkDate = mostRecentDate
        
        while hasCompletedDate(checkDate, gameType: gameType) {
            streakCount += 1
            print("   🔥 Streak count: \(streakCount) (date: \(checkDate))")
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }
        
        print("   🏁 Final streak: \(streakCount)")
        return streakCount
    }
    
    func calculateMaxStreak(for gameType: GameType) -> Int {
        let completions = getAllCompletions(for: gameType)
        guard !completions.isEmpty else { return 0 }
        
        // Group completions by date
        var completedDates = Set<String>()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for completion in completions {
            let dateString = dateFormatter.string(from: completion.date)
            completedDates.insert(dateString)
        }
        
        // Sort dates and find longest consecutive sequence
        let sortedDates = completedDates.sorted()
        var maxStreak = 0
        var currentStreak = 0
        var lastDate: Date?
        
        for dateString in sortedDates {
            guard let date = dateFormatter.date(from: dateString) else { continue }
            
            if let last = lastDate,
               let daysDiff = calendar.dateComponents([.day], from: last, to: date).day,
               daysDiff == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
            
            maxStreak = max(maxStreak, currentStreak)
            lastDate = date
        }
        
        return maxStreak
    }
    
    // MARK: - All Games Streak
    
    func calculateAllGamesStreak(for selectedGames: Set<GameType>) -> (current: Int, max: Int) {
        let today = Date()
        var currentStreak = 0
        var checkDate = today
        
        // Check if today has all games completed
        if !hasCompletedAllGames(on: checkDate, games: selectedGames) {
            // If today isn't complete, check yesterday
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { 
                return (0, calculateMaxAllGamesStreak(for: selectedGames))
            }
            checkDate = yesterday
        }
        
        // Count consecutive days where all games were completed
        while hasCompletedAllGames(on: checkDate, games: selectedGames) {
            currentStreak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }
        
        let maxStreak = calculateMaxAllGamesStreak(for: selectedGames)
        return (currentStreak, maxStreak)
    }
    
    private func calculateMaxAllGamesStreak(for selectedGames: Set<GameType>) -> Int {
        guard !selectedGames.isEmpty else { return 0 }
        
        // Get all completion dates
        let allCompletions = getAllCompletions()
        
        // Group by date and check if all games completed each day
        var completedDays = Set<String>()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let completionsByDate = Dictionary(grouping: allCompletions) { completion in
            dateFormatter.string(from: completion.date)
        }
        
        for (dateString, completions) in completionsByDate {
            let gamesCompletedOnDate = Set(completions.map { $0.gameType })
            if selectedGames.isSubset(of: gamesCompletedOnDate) {
                completedDays.insert(dateString)
            }
        }
        
        // Find longest consecutive sequence
        let sortedDates = completedDays.sorted()
        var maxStreak = 0
        var currentStreak = 0
        var lastDate: Date?
        
        for dateString in sortedDates {
            guard let date = dateFormatter.date(from: dateString) else { continue }
            
            if let last = lastDate,
               let daysDiff = calendar.dateComponents([.day], from: last, to: date).day,
               daysDiff == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
            
            maxStreak = max(maxStreak, currentStreak)
            lastDate = date
        }
        
        return maxStreak
    }
    
    private func hasCompletedAllGames(on date: Date, games: Set<GameType>) -> Bool {
        for gameType in games {
            if !hasCompletedDate(date, gameType: gameType) {
                return false
            }
        }
        return true
    }
    
    // MARK: - Statistics Calculation
    
    func getStatistics(for gameType: GameType, period: StatisticsPeriod) -> GameStatistics {
        let (startDate, endDate) = period.dateRange
        let completions = getCompletions(for: gameType, from: startDate, to: endDate)
        
        let totalCompletions = completions.count
        let totalPlayTime = completions.reduce(0) { $0 + $1.completionTime }
        let averageTime = totalCompletions > 0 ? totalPlayTime / Double(totalCompletions) : 0
        let bestTime = completions.map { $0.completionTime }.min()
        
        let currentStreak = calculateCurrentStreak(for: gameType)
        let maxStreak = calculateMaxStreak(for: gameType)
        
        // Calculate completion rate (days with completion / total days in period)
        let totalDays = calendar.dateComponents([.day], from: startDate, to: min(endDate, Date())).day ?? 1
        let completedDays = Set(completions.map { calendar.startOfDay(for: $0.date) }).count
        let completionRate = Double(completedDays) / Double(totalDays)
        
        let lastPlayedDate = completions.map { $0.date }.max()
        
        return GameStatistics(
            gameType: gameType,
            totalCompletions: totalCompletions,
            totalPlayTime: totalPlayTime,
            averageTime: averageTime,
            bestTime: bestTime,
            currentStreak: currentStreak,
            maxStreak: maxStreak,
            completionRate: completionRate,
            lastPlayedDate: lastPlayedDate
        )
    }
    
    func getAllGamesStatistics(for games: Set<GameType>, period: StatisticsPeriod) -> AllGamesStatistics {
        let (startDate, endDate) = period.dateRange
        let allCompletions = getCompletions(from: startDate, to: endDate)
        
        let totalCompletions = allCompletions.count
        let totalPlayTime = allCompletions.reduce(0) { $0 + $1.completionTime }
        
        // Calculate completed days (days where at least one game was completed)
        let completedDaysSet = Set(allCompletions.map { calendar.startOfDay(for: $0.date) })
        let completedDays = completedDaysSet.count
        
        let totalDays = calendar.dateComponents([.day], from: startDate, to: min(endDate, Date())).day ?? 1
        let averageCompletionsPerDay = Double(totalCompletions) / Double(totalDays)
        
        let allGamesStreaks = calculateAllGamesStreak(for: games)
        
        let gamesStatistics = games.map { getStatistics(for: $0, period: period) }
        
        return AllGamesStatistics(
            totalPlayTime: totalPlayTime,
            totalCompletions: totalCompletions,
            completedDays: completedDays,
            currentAllGamesStreak: allGamesStreaks.current,
            maxAllGamesStreak: allGamesStreaks.max,
            averageCompletionsPerDay: averageCompletionsPerDay,
            gamesStatistics: gamesStatistics
        )
    }
    
    // MARK: - Helper Methods
    
    private func hasCompletedDate(_ date: Date, gameType: GameType) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let fetchDescriptor = FetchDescriptor<DailyCompletion>(
            predicate: #Predicate<DailyCompletion> { completion in
                completion.gameType == gameType &&
                completion.date >= startOfDay &&
                completion.date < endOfDay
            }
        )
        
        let completions = (try? modelContext.fetch(fetchDescriptor)) ?? []
        let hasCompleted = !completions.isEmpty
        
        print("   🔍 Checking \(gameType.displayName) for \(startOfDay): \(hasCompleted ? "✅" : "❌") (\(completions.count) completions)")
        
        return hasCompleted
    }
    
    private func getCompletions(for gameType: GameType, from startDate: Date, to endDate: Date) -> [DailyCompletion] {
        let fetchDescriptor = FetchDescriptor<DailyCompletion>(
            predicate: #Predicate<DailyCompletion> { completion in
                completion.gameType == gameType &&
                completion.date >= startDate &&
                completion.date < endDate
            },
            sortBy: [SortDescriptor(\.date)]
        )
        
        return (try? modelContext.fetch(fetchDescriptor)) ?? []
    }
    
    private func getCompletions(from startDate: Date, to endDate: Date) -> [DailyCompletion] {
        let fetchDescriptor = FetchDescriptor<DailyCompletion>(
            predicate: #Predicate<DailyCompletion> { completion in
                completion.date >= startDate &&
                completion.date < endDate
            },
            sortBy: [SortDescriptor(\.date)]
        )
        
        return (try? modelContext.fetch(fetchDescriptor)) ?? []
    }
    
    private func getAllCompletions(for gameType: GameType) -> [DailyCompletion] {
        let fetchDescriptor = FetchDescriptor<DailyCompletion>(
            predicate: #Predicate<DailyCompletion> { $0.gameType == gameType },
            sortBy: [SortDescriptor(\.date)]
        )
        
        return (try? modelContext.fetch(fetchDescriptor)) ?? []
    }
    
    private func getAllCompletions() -> [DailyCompletion] {
        let fetchDescriptor = FetchDescriptor<DailyCompletion>(
            sortBy: [SortDescriptor(\.date)]
        )
        
        return (try? modelContext.fetch(fetchDescriptor)) ?? []
    }
    
    // MARK: - Streak Updates
    
    func updateStreaks(for gameType: GameType) {
        let currentStreak = calculateCurrentStreak(for: gameType)
        let maxStreak = calculateMaxStreak(for: gameType)
        
        let fetchDescriptor = FetchDescriptor<GameProgress>(
            predicate: #Predicate<GameProgress> { $0.gameType == gameType }
        )
        
        if let progress = try? modelContext.fetch(fetchDescriptor).first {
            progress.currentStreak = currentStreak
            progress.maxStreak = max(progress.maxStreak, maxStreak)
        } else {
            let newProgress = GameProgress(gameType: gameType)
            newProgress.currentStreak = currentStreak
            newProgress.maxStreak = maxStreak
            modelContext.insert(newProgress)
        }
        
        try? modelContext.save()
    }
}

// MARK: - Extensions

extension TimeInterval {
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    var formattedTime: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedShortDuration: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(Int(self))s"
        }
    }
    
    var formattedShortTime: String {
        let minutes = Int(self) / 60
        if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(Int(self))s"
        }
    }
}