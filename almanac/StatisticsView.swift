//
//  StatisticsView.swift
//  almanac
//
//  Comprehensive statistics view with charts and filtering
//

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var statisticsManager: StatisticsManager?
    @State private var selectedPeriod: StatisticsPeriod = .thisWeek
    @State private var selectedGameFilter: GameFilterOption = .all
    @State private var allGamesStats: AllGamesStatistics?
    @State private var individualStats: [GameStatistics] = []
    
    // Filter state from CalendarView
    @State private var selectedGames: Set<GameType> = Set(GameType.allCases)
    
    enum GameFilterOption: String, CaseIterable {
        case all = "all"
        case individual = "individual"
        
        var displayName: String {
            switch self {
            case .all: return "Tous les jeux"
            case .individual: return "Par jeu"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Filters Section
                    filtersSection
                    
                    // Main Statistics
                    if selectedGameFilter == .all {
                        allGamesStatsSection
                    } else {
                        individualGamesStatsSection
                    }
                    
                    // Charts Section
                    chartsSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .background {
                Image(.dotsBackground)
                    .resizable()
                    .scaledToFill()
                    .overlay {
                        Rectangle()
                            .foregroundStyle(.thinMaterial)
                            .ignoresSafeArea()
                    }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupStatisticsManager()
                loadStatistics()
            }
            .onChange(of: selectedPeriod) { _, _ in loadStatistics() }
            .onChange(of: selectedGameFilter) { _, _ in loadStatistics() }
            .onChange(of: selectedGames) { _, _ in loadStatistics() }
        }
    }
    
    // MARK: - Filters Section
    
    private var filtersSection: some View {
        VStack(spacing: 12) {
            periodFilterView
            gameFilterView
        }
    }
    
    private var periodFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                    periodButton(for: period)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func periodButton(for period: StatisticsPeriod) -> some View {
        Button {
            selectedPeriod = period
        } label: {
            Text(period.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(selectedPeriod == period ? .primary : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                  selectedPeriod == period ? .red : .clear,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(.primary.opacity(selectedPeriod == period ? 0.3 : 0.1), lineWidth: 1)
                )
        }
    }
    
    private var gameFilterView: some View {
        HStack(spacing: 6) {
            ForEach(GameFilterOption.allCases, id: \.self) { option in
                gameFilterButton(for: option)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private func gameFilterButton(for option: GameFilterOption) -> some View {
        Button {
            selectedGameFilter = option
        } label: {
            Text(option.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(selectedGameFilter == option ? .primary : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    selectedGameFilter == option ? .purple : .clear,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(.primary.opacity(selectedGameFilter == option ? 0.3 : 0.1), lineWidth: 1)
                )
        }
    }
    
    private var gameSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Jeux sélectionnés")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(GameType.allCases, id: \.self) { gameType in
                    Button {
                        if selectedGames.contains(gameType) {
                            selectedGames.remove(gameType)
                        } else {
                            selectedGames.insert(gameType)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: gameType.icon)
                                .font(.title3)
                                .foregroundStyle(gameType.color)
                            
                            Text(gameType.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            if selectedGames.contains(gameType) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .opacity(selectedGames.contains(gameType) ? 1.0 : 0.6)
                    }
                }
            }
        }
    }
    
    // MARK: - All Games Stats Section
    
    private var allGamesStatsSection: some View {
        VStack(spacing: 12) {
            if let stats = allGamesStats {
                // Minimalist streak display
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(stats.currentAllGamesStreak)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                        Text("Streak")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(stats.maxAllGamesStreak)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                        Text("Record")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                
                // Compact stats grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    MinimalStatView(
                        value: "\(stats.totalCompletions)",
                        label: "Parties"
                    )
                    
                    MinimalStatView(
                        value: "\(stats.completedDays)",
                        label: "Jours"
                    )
                    
                    MinimalStatView(
                        value: stats.totalPlayTime.formattedShortDuration,
                        label: "Temps"
                    )
                    
                    MinimalStatView(
                        value: String(format: "%.1f", stats.averageCompletionsPerDay),
                        label: "Moy/j"
                    )
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Chargement...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 60)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Individual Games Stats Section
    
    private var individualGamesStatsSection: some View {
        VStack(spacing: 8) {
            ForEach(individualStats, id: \.gameType) { stats in
                MinimalGameStatsCard(stats: stats)
            }
        }
    }
    
    // MARK: - Charts Section
    
    private var chartsSection: some View {
        VStack(spacing: 12) {
            if selectedGameFilter == .all, let allStats = allGamesStats {
                // All games charts - simplified
                compactChartsView(stats: allStats)
            }
        }
    }
    
    private func compactChartsView(stats: AllGamesStatistics) -> some View {
        VStack(spacing: 12) {
            // Simple horizontal bar chart
            VStack(alignment: .leading, spacing: 8) {
                Text("Répartition")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 6) {
                    ForEach(stats.gamesStatistics, id: \.gameType) { gameStat in
                        HStack(spacing: 8) {
                            Image(systemName: gameStat.gameType.icon)
                                .font(.caption2)
                                .foregroundStyle(gameStat.gameType.color)
                                .frame(width: 12)
                            
                            Text(gameStat.gameType.displayName)
                                .font(.caption2)
                                .frame(width: 60, alignment: .leading)
                            
                            GeometryReader { geometry in
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(gameStat.gameType.color)
                                        .frame(width: geometry.size.width * (Double(gameStat.totalCompletions) / Double(stats.totalCompletions)))
                                    
                                    Spacer()
                                }
                            }
                            .frame(height: 8)
                            .background(.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                            
                            Text("\(gameStat.totalCompletions)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .frame(width: 20, alignment: .trailing)
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    
    // MARK: - Helper Methods
    
    private func setupStatisticsManager() {
        statisticsManager = StatisticsManager(modelContext: modelContext)
    }
    
    private func loadStatistics() {
        guard let manager = statisticsManager else { return }
        
        if selectedGameFilter == .all {
            allGamesStats = manager.getAllGamesStatistics(for: selectedGames, period: selectedPeriod)
        } else {
            individualStats = selectedGames.map { gameType in
                manager.getStatistics(for: gameType, period: selectedPeriod)
            }
        }
    }
}

// MARK: - Supporting Views

struct MinimalStatView: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MinimalGameStatsCard: View {
    let stats: GameStatistics
    
    var body: some View {
        HStack(spacing: 12) {
            // Game info
            HStack(spacing: 6) {
                Image(systemName: stats.gameType.icon)
                    .font(.caption)
                    .foregroundStyle(stats.gameType.color)
                    .frame(width: 12)
                
                Text(stats.gameType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(width: 50, alignment: .leading)
            }
            
            Spacer()
            
            // Compact stats
            HStack(spacing: 8) {
                VStack(spacing: 1) {
                    Text("\(stats.totalCompletions)")
                        .font(.caption2)
                        .fontWeight(.bold)
                    Text("parties")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 1) {
                    Text("\(stats.currentStreak)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text("streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 1) {
                    Text(stats.averageTime.formattedShortTime)
                        .font(.caption2)
                        .fontWeight(.bold)
                    Text("moy")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DailyCompletion.self, GameProgress.self, configurations: config)
    
    return StatisticsView()
        .modelContainer(container)
}
