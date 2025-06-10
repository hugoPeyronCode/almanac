//
//  QuickStatsSection.swift
//  almanac
//
//  Quick statistics section
//

import SwiftUI
import SwiftData

struct QuickStatsSection: View {
    @Bindable var viewModel: CalendarViewModel
    let allProgress: [GameProgress]
    let allCompletions: [DailyCompletion]

    private let statsCalculator: StatsCalculator

    init(viewModel: CalendarViewModel, allProgress: [GameProgress], allCompletions: [DailyCompletion]) {
        self.viewModel = viewModel
        self.allProgress = allProgress
        self.allCompletions = allCompletions
        self.statsCalculator = StatsCalculator(
            selectedGames: viewModel.selectedGames,
            allProgress: allProgress,
            allCompletions: allCompletions
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Quick Stats")
                    .font(.headline)
                    .fontWeight(.medium)

                if !viewModel.selectedGames.isEmpty && viewModel.selectedGames.count < GameType.allCases.count {
                    Text("(\(viewModel.selectedGames.count) games)")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }

                Spacer()
            }

            if viewModel.selectedGames.isEmpty {
                Text("Select games to see statistics")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                    StatCard(
                        value: statsCalculator.totalCompletedGames,
                        label: "Total\nCompleted",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )

                    StatCard(
                        value: statsCalculator.currentStreak,
                        label: "Current\nStreak",
                        icon: "flame.fill",
                        color: .orange
                    )

                    StatCard(
                        value: statsCalculator.maxStreak,
                        label: "Best\nStreak",
                        icon: "star.fill",
                        color: .yellow
                    )

                    StatCard(
                        value: statsCalculator.perfectDaysCount,
                        label: "Perfect\nDays",
                        icon: "crown.fill",
                        color: .purple
                    )
                }
            }
        }
    }
}

// Stats calculation helper
struct StatsCalculator {
    let selectedGames: Set<GameType>
    let allProgress: [GameProgress]
    let allCompletions: [DailyCompletion]

    private let calendar = Calendar.current

    var totalCompletedGames: Int {
        allProgress
            .filter { selectedGames.contains($0.gameType) }
            .reduce(0) { $0 + $1.totalCompleted }
    }

    var currentStreak: Int {
        let streaks = selectedGames.compactMap { gameType in
            calculateCurrentStreak(for: gameType)
        }
        return streaks.max() ?? 0
    }

    var maxStreak: Int {
        let streaks = selectedGames.compactMap { gameType in
            calculateMaxStreak(for: gameType)
        }
        return streaks.max() ?? 0
    }

    var perfectDaysCount: Int {
        let today = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today

        var perfectDays = 0
        var checkDate = thirtyDaysAgo

        while checkDate <= today {
            let completedGames = selectedGames.filter { gameType in
                isGameCompletedForDate(checkDate, gameType: gameType)
            }

            if completedGames.count == selectedGames.count && !selectedGames.isEmpty {
                perfectDays += 1
            }

            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? today
        }

        return perfectDays
    }

    private func calculateCurrentStreak(for gameType: GameType) -> Int {
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

        while hasCompletedDate(checkDate, gameType: gameType) {
            streakCount += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }

        return streakCount
    }

    private func calculateMaxStreak(for gameType: GameType) -> Int {
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

    private func hasCompletedDate(_ date: Date, gameType: GameType) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return allCompletions.contains { completion in
            completion.gameType == gameType &&
            completion.date >= startOfDay &&
            completion.date < endOfDay
        }
    }

    private func isGameCompletedForDate(_ date: Date, gameType: GameType) -> Bool {
        hasCompletedDate(date, gameType: gameType)
    }
}
