//
//  EnhancedStatisticsView.swift
//  almanac
//
//  Comprehensive statistics view with charts and detailed analytics
//

import SwiftUI
import SwiftData
import Charts

struct EnhancedStatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Data queries
    @Query private var dailyCompletions: [DailyCompletion]
    @Query private var practiceProgress: [PracticeProgress]
    @Query private var practiceSessions: [PracticeSession]
    @Query private var gameProgress: [GameProgress]
    
    @State private var selectedTab: StatisticTab = .overview
    @State private var selectedTimeRange: TimeRange = .month
    
    enum StatisticTab: String, CaseIterable {
        case overview = "Overview"
        case daily = "Daily Challenges"
        case practice = "Practice Mode"
        case achievements = "Achievements"
        
        var icon: String {
            switch self {
            case .overview: return "chart.bar.xaxis"
            case .daily: return "calendar"
            case .practice: return "gamecontroller"
            case .achievements: return "trophy"
            }
        }
    }
    
    enum TimeRange: String, CaseIterable {
        case week = "7D"
        case month = "30D"
        case quarter = "90D"
        case year = "1Y"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabSelector
                
                timeRangeSelector
                    .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 24) {
                        switch selectedTab {
                        case .overview:
                            overviewContent
                        case .daily:
                            dailyContent
                        case .practice:
                            practiceContent
                        case .achievements:
                            achievementsContent
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StatisticTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.caption)
                            
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(selectedTab == tab ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? Color.blue : Color.secondary.opacity(0.1))
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        HStack {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    selectedTimeRange = range
                } label: {
                    Text(range.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(selectedTimeRange == range ? .white : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedTimeRange == range ? Color.blue : Color.clear)
                        )
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Overview Content
    
    @ViewBuilder
    private var overviewContent: some View {
        VStack(spacing: 24) {
            // Summary Cards
            summaryCards
            
            // Activity Chart
            activityChart
            
            // Game Type Breakdown
            gameTypeBreakdown
            
            // Recent Achievements
            recentAchievements
        }
    }
    
    private var summaryCards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
            StatSummaryCard(
                title: "Total Puzzles",
                value: "\(totalPuzzlesCompleted)",
                subtitle: "All time",
                icon: "puzzlepiece",
                color: .blue
            )
            
            StatSummaryCard(
                title: "Current Streak",
                value: "\(currentStreak)",
                subtitle: "days",
                icon: "flame.fill",
                color: .orange
            )
            
            StatSummaryCard(
                title: "Best Time",
                value: formatTime(bestCompletionTime),
                subtitle: "fastest puzzle",
                icon: "stopwatch",
                color: .green
            )
            
            StatSummaryCard(
                title: "Play Time",
                value: "\(Int(totalPlayTimeHours))h",
                subtitle: "total",
                icon: "clock",
                color: .purple
            )
        }
    }
    
    @ViewBuilder
    private var activityChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity Over Time")
                .font(.headline)
                .fontWeight(.medium)
            
            Chart(getActivityData()) { item in
                BarMark(
                    x: .value("Date", item.date),
                    y: .value("Puzzles", item.count)
                )
                .foregroundStyle(.blue.gradient)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: selectedTimeRange.days / 7)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    @ViewBuilder
    private var gameTypeBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Games Completed by Type")
                .font(.headline)
                .fontWeight(.medium)
            
            Chart(getGameTypeData()) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(item.gameType.color)
                .opacity(0.8)
            }
            .frame(height: 200)
            
            // Legend
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(getGameTypeData(), id: \.gameType) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.gameType.color)
                            .frame(width: 12, height: 12)
                        
                        Text(item.gameType.displayName)
                            .font(.caption)
                        
                        Spacer()
                        
                        Text("\(item.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    @ViewBuilder
    private var recentAchievements: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Achievements")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("View All") {
                    selectedTab = .achievements
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            
            // Show recent badges (last 3)
            let recentBadges = getRecentBadges()
            if recentBadges.isEmpty {
                Text("No achievements yet. Keep playing to unlock badges!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(recentBadges.prefix(3), id: \.id) { badge in
                        AchievementRow(badge: badge)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Daily Content
    
    @ViewBuilder
    private var dailyContent: some View {
        VStack(spacing: 24) {
            // Daily stats summary
            dailyStatsCards
            
            // Streak chart
            streakChart
            
            // Completion rate by game
            dailyCompletionRates
        }
    }
    
    private var dailyStatsCards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
            StatSummaryCard(
                title: "Daily Streak",
                value: "\(currentStreak)",
                subtitle: "current",
                icon: "flame.fill",
                color: .orange
            )
            
            StatSummaryCard(
                title: "Best Streak",
                value: "\(maxStreak)",
                subtitle: "all time",
                icon: "trophy.fill",
                color: .yellow
            )
            
            StatSummaryCard(
                title: "Perfect Days",
                value: "\(perfectDaysCount)",
                subtitle: "last 30 days",
                icon: "star.fill",
                color: .blue
            )
            
            StatSummaryCard(
                title: "Completion Rate",
                value: "\(Int(dailyCompletionRate * 100))%",
                subtitle: "last 30 days",
                icon: "percent",
                color: .green
            )
        }
    }
    
    @ViewBuilder
    private var streakChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Challenge Streak")
                .font(.headline)
                .fontWeight(.medium)
            
            Chart(getStreakData()) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Streak", item.streak)
                )
                .foregroundStyle(.orange.gradient)
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Streak", item.streak)
                )
                .foregroundStyle(.orange.gradient.opacity(0.3))
            }
            .frame(height: 200)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    @ViewBuilder
    private var dailyCompletionRates: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Completion Rate by Game")
                .font(.headline)
                .fontWeight(.medium)
            
            ForEach(GameType.allCases, id: \.self) { gameType in
                let rate = getDailyCompletionRate(for: gameType)
                
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: gameType.icon)
                            .foregroundStyle(gameType.color)
                        
                        Text(gameType.displayName)
                            .font(.subheadline)
                    }
                    
                    Spacer()
                    
                    Text("\(Int(rate * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
                
                ProgressView(value: rate)
                    .tint(gameType.color)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Practice Content
    
    @ViewBuilder
    private var practiceContent: some View {
        VStack(spacing: 24) {
            practiceStatsCards
            practiceTimeChart
            practiceProgressByGame
        }
    }
    
    private var practiceStatsCards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
            StatSummaryCard(
                title: "Practice Sessions",
                value: "\(totalPracticeSessions)",
                subtitle: "completed",
                icon: "gamecontroller",
                color: .blue
            )
            
            StatSummaryCard(
                title: "Average Time",
                value: formatTime(averagePracticeTime),
                subtitle: "per puzzle",
                icon: "clock",
                color: .green
            )
            
            StatSummaryCard(
                title: "Best Practice",
                value: formatTime(bestPracticeTime),
                subtitle: "fastest",
                icon: "bolt.fill",
                color: .yellow
            )
            
            StatSummaryCard(
                title: "Practice Hours",
                value: "\(Int(totalPracticeHours))h",
                subtitle: "total",
                icon: "hourglass",
                color: .purple
            )
        }
    }
    
    @ViewBuilder
    private var practiceTimeChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Practice Session Times")
                .font(.headline)
                .fontWeight(.medium)
            
            Chart(getPracticeTimeData()) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Time", item.averageTime)
                )
                .foregroundStyle(.green.gradient)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .frame(height: 200)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    @ViewBuilder
    private var practiceProgressByGame: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Practice Progress by Game")
                .font(.headline)
                .fontWeight(.medium)
            
            ForEach(GameType.allCases, id: \.self) { gameType in
                let progress = practiceProgress.first { $0.gameType == gameType }
                
                VStack(spacing: 8) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: gameType.icon)
                                .foregroundStyle(gameType.color)
                            
                            Text(gameType.displayName)
                                .font(.subheadline)
                        }
                        
                        Spacer()
                        
                        Text("\(progress?.completedSessions ?? 0)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                    
                    if let avgTime = progress?.averageTime {
                        HStack {
                            Text("Avg: \(formatTime(avgTime))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            if let bestTime = progress?.bestTime {
                                Text("Best: \(formatTime(bestTime))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Achievements Content
    
    @ViewBuilder
    private var achievementsContent: some View {
        VStack(spacing: 24) {
            // Progress overview
            achievementProgressCard
            
            // All badges
            allBadgesGrid
        }
    }
    
    @ViewBuilder
    private var achievementProgressCard: some View {
        let unlockedBadges = getUnlockedBadges()
        let totalBadges = BadgeType.allCases.count
        let progress = Double(unlockedBadges.count) / Double(totalBadges)
        
        VStack(spacing: 16) {
            HStack {
                Text("Achievement Progress")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(unlockedBadges.count)/\(totalBadges)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            ProgressView(value: progress)
                .tint(.blue)
            
            Text("\(Int(progress * 100))% Complete")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    @ViewBuilder
    private var allBadgesGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Achievements")
                .font(.headline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                ForEach(BadgeType.allCases, id: \.self) { badgeType in
                    let unlockedBadges = getUnlockedBadges()
                    let isUnlocked = unlockedBadges.contains { $0.type == badgeType }
                    let badge = unlockedBadges.first { $0.type == badgeType }
                    
                    BadgeDetailView(
                        type: badgeType,
                        isUnlocked: isUnlocked,
                        unlockedDate: badge?.unlockedAt
                    )
                }
            }
        }
    }
    
    // MARK: - Data Processing Methods
    
    private var totalPuzzlesCompleted: Int {
        dailyCompletions.count + practiceSessions.filter { $0.isCompleted }.count
    }
    
    private var currentStreak: Int {
        gameProgress.map { $0.currentStreak }.max() ?? 0
    }
    
    private var maxStreak: Int {
        gameProgress.map { $0.maxStreak }.max() ?? 0
    }
    
    private var bestCompletionTime: TimeInterval {
        let dailyBest = dailyCompletions.map { $0.completionTime }.min() ?? Double.infinity
        let practiceBest = practiceSessions.compactMap { $0.isCompleted ? $0.completionTime : nil }.min() ?? Double.infinity
        return min(dailyBest, practiceBest) == Double.infinity ? 0 : min(dailyBest, practiceBest)
    }
    
    private var totalPlayTimeHours: TimeInterval {
        let dailyTime = dailyCompletions.reduce(0) { $0 + $1.completionTime }
        let practiceTime = practiceProgress.reduce(0) { $0 + $1.totalPlayTime }
        return (dailyTime + practiceTime) / 3600
    }
    
    private var perfectDaysCount: Int {
        let calendar = Calendar.current
        let today = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        
        var perfectDays = 0
        var checkDate = thirtyDaysAgo
        
        while checkDate <= today {
            let completedGames = GameType.allCases.filter { gameType in
                let startOfDay = calendar.startOfDay(for: checkDate)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                return dailyCompletions.contains { completion in
                    completion.gameType == gameType &&
                    completion.date >= startOfDay &&
                    completion.date < endOfDay
                }
            }
            
            if completedGames.count == GameType.allCases.count {
                perfectDays += 1
            }
            
            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? today
        }
        
        return perfectDays
    }
    
    private var dailyCompletionRate: Double {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentCompletions = dailyCompletions.filter { $0.date >= thirtyDaysAgo }
        let possibleCompletions = 30 * GameType.allCases.count
        return possibleCompletions > 0 ? Double(recentCompletions.count) / Double(possibleCompletions) : 0
    }
    
    private var totalPracticeSessions: Int {
        practiceSessions.filter { $0.isCompleted }.count
    }
    
    private var averagePracticeTime: TimeInterval {
        let completedSessions = practiceSessions.filter { $0.isCompleted }
        guard !completedSessions.isEmpty else { return 0 }
        return completedSessions.reduce(0) { $0 + $1.completionTime } / Double(completedSessions.count)
    }
    
    private var bestPracticeTime: TimeInterval {
        practiceSessions.compactMap { $0.isCompleted ? $0.completionTime : nil }.min() ?? 0
    }
    
    private var totalPracticeHours: TimeInterval {
        practiceProgress.reduce(0) { $0 + $1.totalPlayTime } / 3600
    }
    
    // MARK: - Chart Data Methods
    
    private func getActivityData() -> [ActivityDataPoint] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate) ?? endDate
        
        var data: [ActivityDataPoint] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            let dayStart = calendar.startOfDay(for: currentDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            let dailyCount = dailyCompletions.filter { completion in
                completion.date >= dayStart && completion.date < dayEnd
            }.count
            
            let practiceCount = practiceSessions.filter { session in
                session.startedAt >= dayStart && session.startedAt < dayEnd && session.isCompleted
            }.count
            
            data.append(ActivityDataPoint(date: currentDate, count: dailyCount + practiceCount))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        return data
    }
    
    private func getGameTypeData() -> [GameTypeDataPoint] {
        return GameType.allCases.map { gameType in
            let dailyCount = dailyCompletions.filter { $0.gameType == gameType }.count
            let practiceCount = practiceSessions.filter { $0.gameType == gameType && $0.isCompleted }.count
            return GameTypeDataPoint(gameType: gameType, count: dailyCount + practiceCount)
        }.filter { $0.count > 0 }
    }
    
    private func getStreakData() -> [StreakDataPoint] {
        // Simplified - would need more complex logic for actual streak calculation
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate) ?? endDate
        
        var data: [StreakDataPoint] = []
        var currentDate = startDate
        var streak = 0
        
        while currentDate <= endDate {
            let dayStart = calendar.startOfDay(for: currentDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            let hasCompletion = dailyCompletions.contains { completion in
                completion.date >= dayStart && completion.date < dayEnd
            }
            
            if hasCompletion {
                streak += 1
            } else {
                streak = 0
            }
            
            data.append(StreakDataPoint(date: currentDate, streak: streak))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        return data
    }
    
    private func getPracticeTimeData() -> [PracticeTimeDataPoint] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate) ?? endDate
        
        var data: [PracticeTimeDataPoint] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            let dayStart = calendar.startOfDay(for: currentDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            let daySessions = practiceSessions.filter { session in
                session.startedAt >= dayStart && session.startedAt < dayEnd && session.isCompleted
            }
            
            let averageTime = daySessions.isEmpty ? 0 : daySessions.reduce(0) { $0 + $1.completionTime } / Double(daySessions.count)
            
            data.append(PracticeTimeDataPoint(date: currentDate, averageTime: averageTime))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        return data
    }
    
    private func getDailyCompletionRate(for gameType: GameType) -> Double {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentCompletions = dailyCompletions.filter { 
            $0.gameType == gameType && $0.date >= thirtyDaysAgo 
        }
        return Double(recentCompletions.count) / 30.0
    }
    
    private func getRecentBadges() -> [PlayerBadge] {
        let badges = (try? modelContext.fetch(FetchDescriptor<PlayerBadge>())) ?? []
        return badges.sorted { $0.unlockedAt > $1.unlockedAt }
    }
    
    private func getUnlockedBadges() -> [PlayerBadge] {
        (try? modelContext.fetch(FetchDescriptor<PlayerBadge>())) ?? []
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "—" }
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Data Structures

struct ActivityDataPoint: Identifiable {
  let id: UUID = UUID()
    let date: Date
    let count: Int
}

struct GameTypeDataPoint : Identifiable {
  let id: UUID = UUID()
    let gameType: GameType
    let count: Int
}

struct StreakDataPoint : Identifiable {
  let id: UUID = UUID()

    let date: Date
    let streak: Int
}

struct PracticeTimeDataPoint : Identifiable {
  let id: UUID = UUID()

    let date: Date
    let averageTime: TimeInterval
}

// MARK: - Supporting Views

struct StatSummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct AchievementRow: View {
    let badge: PlayerBadge
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: badge.type.icon)
                .font(.title3)
                .foregroundStyle(badge.type.backgroundColor)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(badge.type.backgroundColor.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(badge.type.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(badge.type.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(badge.unlockedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct BadgeDetailView: View {
    let type: BadgeType
    let isUnlocked: Bool
    let unlockedDate: Date?
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? type.backgroundColor : Color.secondary.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: type.icon)
                    .font(.title3)
                    .foregroundStyle(isUnlocked ? .white : .secondary)
            }
            
            Text(type.name)
                .font(.caption2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(isUnlocked ? .primary : .secondary)
            
            if let date = unlockedDate {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Not unlocked")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

#Preview {
    EnhancedStatisticsView()
        .modelContainer(for: [
            DailyCompletion.self,
            PracticeProgress.self,
            PracticeSession.self,
            GameProgress.self,
            PlayerBadge.self
        ], inMemory: true)
}
