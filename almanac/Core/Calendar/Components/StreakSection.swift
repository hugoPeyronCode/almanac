//
//  StreakSection.swift
//  almanac
//
//  Streak display section
//

import SwiftUI
import SwiftData

struct StreakSection: View {
    let selectedGames: Set<GameType>
    let progressManager: ProgressManager?
    let allCompletions: [DailyCompletion]

    private let calendar = Calendar.current

    var body: some View {
        StreakDisplayView(
            selectedGames: selectedGames,
            progressManager: progressManager,
            individualStreaks: getIndividualStreaks(),
            allGamesStreak: getAllGamesStreakLocal()
        )
    }

    // MARK: - Streak Calculations

    private func getIndividualStreaks() -> [GameType: (current: Int, max: Int)] {
        var streaks: [GameType: (current: Int, max: Int)] = [:]

        for gameType in selectedGames {
            let current = calculateCurrentStreakLocal(for: gameType)
            let max = calculateMaxStreakLocal(for: gameType)
            streaks[gameType] = (current, max)
        }

        return streaks
    }

    private func getAllGamesStreakLocal() -> (current: Int, max: Int) {
        guard !selectedGames.isEmpty else { return (0, 0) }

        let today = calendar.startOfDay(for: Date())
        let allDates = Set(allCompletions.map { calendar.startOfDay(for: $0.date) })
        let sortedDates = allDates.sorted(by: >)

        var mostRecentAllComplete: Date?

        for date in sortedDates {
            let completedGamesForDate = selectedGames.filter { gameType in
                hasCompletedDateLocal(date, gameType: gameType)
            }

            if completedGamesForDate.count == selectedGames.count {
                mostRecentAllComplete = date
                break
            }
        }

        guard let startDate = mostRecentAllComplete else {
            return (0, calculateMaxAllGamesStreakLocal())
        }

        let daysBetween = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
        if daysBetween > 1 {
            return (0, calculateMaxAllGamesStreakLocal())
        }

        var currentStreak = 0
        var checkDate = startDate

        while areAllGamesCompletedLocal(on: checkDate) {
            currentStreak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }

        return (currentStreak, calculateMaxAllGamesStreakLocal())
    }

    private func calculateCurrentStreakLocal(for gameType: GameType) -> Int {
        let gameCompletions = allCompletions.filter { $0.gameType == gameType }

        guard !gameCompletions.isEmpty else { return 0 }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let completedDates = Set(gameCompletions.map { completion in
            dateFormatter.string(from: calendar.startOfDay(for: completion.date))
        })

        let sortedDates = completedDates.sorted(by: >)

        guard let mostRecentDateString = sortedDates.first,
              let mostRecentDate = dateFormatter.date(from: mostRecentDateString) else {
            return 0
        }

        let today = calendar.startOfDay(for: Date())
        let daysBetween = calendar.dateComponents([.day], from: mostRecentDate, to: today).day ?? 0

        if daysBetween > 1 {
            return 0
        }

        var streakCount = 0
        var checkDate = mostRecentDate

        while hasCompletedDateLocal(checkDate, gameType: gameType) {
            streakCount += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }

        return streakCount
    }

    private func calculateMaxStreakLocal(for gameType: GameType) -> Int {
        let gameCompletions = allCompletions.filter { $0.gameType == gameType }
        guard !gameCompletions.isEmpty else { return 0 }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var completedDates = Set<String>()
        for completion in gameCompletions {
            let dateString = dateFormatter.string(from: completion.date)
            completedDates.insert(dateString)
        }

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

    private func calculateMaxAllGamesStreakLocal() -> Int {
        guard !selectedGames.isEmpty else { return 0 }

        let allDates = Set(allCompletions.map { calendar.startOfDay(for: $0.date) })
        let sortedDates = allDates.sorted()

        var maxStreak = 0
        var currentStreak = 0
        var lastDate: Date?

        for date in sortedDates {
            if areAllGamesCompletedLocal(on: date) {
                if let last = lastDate,
                   let daysDiff = calendar.dateComponents([.day], from: last, to: date).day,
                   daysDiff == 1 {
                    currentStreak += 1
                } else {
                    currentStreak = 1
                }

                maxStreak = max(maxStreak, currentStreak)
                lastDate = date
            } else {
                currentStreak = 0
                lastDate = nil
            }
        }

        return maxStreak
    }

    private func hasCompletedDateLocal(_ date: Date, gameType: GameType) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return allCompletions.contains { completion in
            completion.gameType == gameType &&
            completion.date >= startOfDay &&
            completion.date < endOfDay
        }
    }

    private func areAllGamesCompletedLocal(on date: Date) -> Bool {
        for gameType in selectedGames {
            if !hasCompletedDateLocal(date, gameType: gameType) {
                return false
            }
        }
        return true
    }
}
