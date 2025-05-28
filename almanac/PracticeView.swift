//
//  PracticeModeView.swift
//  Multi-Game Puzzle App
//
//  Simplified practice mode with game cards and basic stats
//

import SwiftUI
import SwiftData

struct PracticeModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(GameCoordinator.self) private var coordinator

    // SwiftData queries to observe changes
    @Query private var allCompletions: [DailyCompletion]
    @Query private var allProgress: [GameProgress]

    private let levelManager = LevelManager.shared

    var body: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.horizontal)
                .padding(.top)

            ScrollView {
                VStack(spacing: 32) {
                    todayStatsSection
                        .padding(.horizontal)

                    gameCardsSection
                        .padding(.horizontal)

                    overallStatsSection
                        .padding(.horizontal)

                    Spacer(minLength: 100)
                }
                .padding(.vertical, 32)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Back")
                            .font(.body)
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Practice Mode")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Sharpen your skills with unlimited puzzles")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Today Stats Section

    private var todayStatsSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Today's Practice")
                    .font(.headline)
                    .fontWeight(.medium)

                Spacer()
            }

            let todayStats = getTodayPracticeStats()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                StatCard(
                    value: todayStats.levelsPlayed,
                    label: "Levels\nToday",
                    icon: "calendar",
                    color: .blue
                )

                StatCard(
                    value: Int(todayStats.timePlayedMinutes),
                    label: "Minutes\nToday",
                    icon: "clock",
                    color: .green
                )
            }
        }
    }

    // MARK: - Game Cards Section

    private var gameCardsSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Choose Your Game")
                    .font(.headline)
                    .fontWeight(.medium)

                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(GameType.allCases, id: \.self) { gameType in
                    SimplePracticeCard(
                        gameType: gameType,
                        progress: getGameProgress(gameType),
                        totalLevels: levelManager.getTotalLevelsCount(for: gameType)
                    ) {
                        startPractice(gameType: gameType)
                    }
                }
            }
        }
    }

    // MARK: - Overall Stats Section

    private var overallStatsSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("All Time Stats")
                    .font(.headline)
                    .fontWeight(.medium)

                Spacer()
            }

            let allTimeStats = getAllTimePracticeStats()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                StatCard(
                    value: allTimeStats.totalLevels,
                    label: "Total\nLevels",
                    icon: "trophy",
                    color: .yellow
                )

                StatCard(
                    value: Int(allTimeStats.totalTimeHours),
                    label: "Total\nHours",
                    icon: "hourglass",
                    color: .purple
                )
            }
        }
    }

    // MARK: - Helper Methods

    private func getGameProgress(_ gameType: GameType) -> GameProgress? {
        return allProgress.first { $0.gameType == gameType }
    }

    private func startPractice(gameType: GameType) {
        guard let level = levelManager.getRandomLevelForGame(gameType) else {
            print("No available levels for \(gameType.displayName)")
            return
        }

        coordinator.startGame(gameType: gameType, level: level, context: .practice)
    }

    private func getTodayPracticeStats() -> (levelsPlayed: Int, timePlayedMinutes: Double) {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()

        // Only count practice sessions (not daily completions)
        // For now, we'll simulate with random data since we don't track practice separately
        let todayCompletions = allCompletions.filter { completion in
            completion.date >= today && completion.date < tomorrow
        }

        let levelsPlayed = todayCompletions.count
        let timePlayedSeconds = todayCompletions.reduce(0) { $0 + $1.completionTime }
        let timePlayedMinutes = timePlayedSeconds / 60

        return (levelsPlayed, timePlayedMinutes)
    }

    private func getAllTimePracticeStats() -> (totalLevels: Int, totalTimeHours: Double) {
        let totalLevels = allProgress.reduce(0) { $0 + $1.totalCompleted }

        // Estimate total time from average times
        let totalTimeSeconds = allProgress.compactMap { $0.averageTime }.reduce(0) { total, avgTime in
            let progress = allProgress.first { $0.averageTime == avgTime }
            return total + (avgTime * Double(progress?.totalCompleted ?? 0))
        }

        let totalTimeHours = totalTimeSeconds / 3600

        return (totalLevels, totalTimeHours)
    }
}

// MARK: - Simple Practice Card

struct SimplePracticeCard: View {
    let gameType: GameType
    let progress: GameProgress?
    let totalLevels: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Header with icon
                HStack {
                    Image(systemName: gameType.icon)
                        .font(.title)
                        .foregroundStyle(gameType.color)

                    Spacer()

                    if let progress = progress, progress.totalCompleted > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(progress.totalCompleted)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .monospacedDigit()

                            Text("played")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Game name
                VStack(alignment: .leading, spacing: 8) {
                    Text(gameType.displayName)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(totalLevels) levels available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                // Play button
                HStack {
                    Image(systemName: "play.fill")
                        .font(.caption)
                    Text("Practice")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(gameType.color, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(gameType.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: false)
    }
}
