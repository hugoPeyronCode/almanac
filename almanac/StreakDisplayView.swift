//
//  StreakDisplayView.swift
//  almanac
//
//  Displays streak information in calendar and other views
//

import SwiftUI
import SwiftData

struct StreakDisplayView: View {
    let selectedGames: Set<GameType>
    let progressManager: ProgressManager?
    let individualStreaks: [GameType: (current: Int, max: Int)]?
    let allGamesStreak: (current: Int, max: Int)?
    
    // Observe changes to force updates
    @Query private var allCompletions: [DailyCompletion]
    @Query private var allProgress: [GameProgress]
    
    @State private var calculatedAllGamesStreak: (current: Int, max: Int) = (0, 0)
    @State private var calculatedIndividualStreaks: [GameType: (current: Int, max: Int)] = [:]
    
    // Computed properties to use either passed data or calculated data
    private var displayAllGamesStreak: (current: Int, max: Int) {
        return allGamesStreak ?? calculatedAllGamesStreak
    }
    
    private var displayIndividualStreaks: [GameType: (current: Int, max: Int)] {
        return individualStreaks ?? calculatedIndividualStreaks
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // All Games Streak (only if multiple games selected)
            if selectedGames.count > 1 {
                allGamesStreakView
            }
            
            // Individual Game Streaks
            individualStreaksView
        }
        .onAppear {
            if individualStreaks == nil || allGamesStreak == nil {
                updateStreaks()
            }
        }
        .onChange(of: selectedGames) { _, _ in
            if individualStreaks == nil || allGamesStreak == nil {
                updateStreaks()
            }
        }
        .onChange(of: allCompletions.count) { _, _ in
            if individualStreaks == nil || allGamesStreak == nil {
                updateStreaks()
            }
        }
        .onChange(of: allProgress.count) { _, _ in
            if individualStreaks == nil || allGamesStreak == nil {
                updateStreaks()
            }
        }
    }
    
    // MARK: - All Games Streak
    
    private var allGamesStreakView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Streak tous jeux")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 24) {
                StreakItemView(
                    title: "Actuelle",
                    value: displayAllGamesStreak.current,
                    color: .green
                )
                
                StreakItemView(
                    title: "Record",
                    value: displayAllGamesStreak.max,
                    color: .orange
                )
                
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Individual Game Streaks
    
    private var individualStreaksView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(.blue)
                Text("Streaks par jeu")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(selectedGames.count, 2)), spacing: 12) {
                ForEach(Array(selectedGames), id: \.self) { gameType in
                    GameStreakCard(
                        gameType: gameType,
                        streak: displayIndividualStreaks[gameType] ?? (0, 0)
                    )
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Methods
    
    private func updateStreaks() {
        guard let manager = progressManager else { return }
        
        print("🔄 Updating streaks in StreakDisplayView for \(selectedGames.count) games (fallback mode)")
        
        // Update all games streak (fallback when no data passed)
        calculatedAllGamesStreak = manager.statistics.calculateAllGamesStreak(for: selectedGames)
        print("   📊 All games streak: current=\(calculatedAllGamesStreak.current), max=\(calculatedAllGamesStreak.max)")
        
        // Update individual streaks (fallback when no data passed)
        var newIndividualStreaks: [GameType: (current: Int, max: Int)] = [:]
        for gameType in selectedGames {
            let current = manager.statistics.calculateCurrentStreak(for: gameType)
            let max = manager.statistics.calculateMaxStreak(for: gameType)
            newIndividualStreaks[gameType] = (current, max)
            print("   🎮 \(gameType.displayName): current=\(current), max=\(max)")
        }
        calculatedIndividualStreaks = newIndividualStreaks
    }
}

// MARK: - Supporting Views

struct StreakItemView: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct GameStreakCard: View {
    let gameType: GameType
    let streak: (current: Int, max: Int)
    
    var body: some View {
        VStack(spacing: 8) {
            // Game icon and name
            HStack(spacing: 6) {
                Image(systemName: gameType.icon)
                    .font(.caption)
                    .foregroundStyle(gameType.color)
                
                Text(gameType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer()
            }
            
            // Streak numbers
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streak.current)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    
                    Text("Actuelle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(streak.max)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    
                    Text("Record")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DailyCompletion.self, GameProgress.self, configurations: config)
    
    return StreakDisplayView(
        selectedGames: Set([.wordle, .shikaku, .sets]),
        progressManager: ProgressManager(modelContext: container.mainContext),
        individualStreaks: nil,
        allGamesStreak: nil
    )
    .padding()
    .modelContainer(container)
}