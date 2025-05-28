//
//  MultiGameCalendarView.swift
//  Multi-Game Puzzle App
//
//  Main calendar interface for multi-game daily puzzles
//

import SwiftUI
import SwiftData

struct MultiGameCalendarView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext

    // SwiftData queries to observe changes
    @Query private var allCompletions: [DailyCompletion]
    @Query private var allProgress: [GameProgress]

    @State private var coordinator = GameCoordinator()
    @State private var progressManager: ProgressManager?
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var isCompactMode = true
    @State private var showingCompletionCelebration = false

    private let levelManager = LevelManager.shared
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            VStack(spacing: 0) {
                headerView

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 32) {
                        calendarSection
                        selectedDateSection
                        quickStatsSection

                        Spacer(minLength: 100)
                    }
                    .padding(.top)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("")
            .environment(coordinator)
            .navigationDestination(for: GameCoordinator.NavigationDestination.self) { destination in
                navigationContent(for: destination)
            }
            .alert("🎉 Day Complete!", isPresented: $showingCompletionCelebration) {
                Button("Great!") { }
            } message: {
                Text("You've completed all 4 games for \(selectedDateTitle)! 🏆")
            }
        }
        .sheet(item: $coordinator.presentedSheet) { destination in
            sheetContent(for: destination)
        }
        .fullScreenCover(item: $coordinator.presentedFullScreen) { destination in
            fullScreenContent(for: destination)
        }
        .onAppear {
            progressManager = ProgressManager(modelContext: modelContext)

            // Focus on today if not already selected
            let today = Date()
            if !calendar.isDate(selectedDate, inSameDayAs: today) {
                selectedDate = today
                currentMonth = today
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.title2)
                .foregroundStyle(.primary)

            Text("Daily Puzzles")
                .font(.title)
                .fontWeight(.bold)

            Spacer()

            Button {
                coordinator.push(.practiceMode)
            } label: {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: false)

            Button {
                coordinator.showStatistics()
            } label: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: false)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(spacing: 16) {
            monthNavigationHeader

            if isCompactMode {
                horizontalCalendarView
            } else {
                fullCalendarView
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }

    private var monthNavigationHeader: some View {
        HStack {
            Button {
                navigateMonth(direction: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: currentMonth)

            Spacer()

            Text(monthTitle)
                .font(isCompactMode ? .headline : .title2)
                .fontWeight(.medium)

            Spacer()

            Button {
                focusOnToday()
            } label: {
                Image(systemName: "location")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: selectedDate)

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isCompactMode.toggle()
                }
            } label: {
                Image(systemName: isCompactMode ? "rectangle.grid.3x2" : "rectangle.compress.vertical")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: isCompactMode)

            Button {
                navigateMonth(direction: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: currentMonth)
        }
        .padding(.horizontal)
    }

    private var horizontalCalendarView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(currentMonthDays, id: \.date) { day in
                        CalendarDayView(
                            day: day,
                            isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                            completionStatus: getDayCompletionStatus(day.date),
                            isCompact: true
                        ) {
                            selectDate(day.date)
                        }
                        .id(day.date)
                    }
                }
                .padding(.horizontal)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(Date(), anchor: .center)
                }
            }
            .onChange(of: selectedDate) { _, newDate in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newDate, anchor: .center)
                }
            }
        }
    }

    private var fullCalendarView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ForEach(generateCalendarDays(), id: \.date) { day in
                CalendarDayView(
                    day: day,
                    isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                    completionStatus: getDayCompletionStatus(day.date),
                    isCompact: false
                ) {
                    selectDate(day.date)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Selected Date Section

    private var selectedDateSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text(selectedDateTitle)
                    .font(.title2)
                    .fontWeight(.medium)

                Spacer()

                let completedCount = getTotalCompletedToday()
                let totalGames = GameType.allCases.count

                if completedCount > 0 {
                    HStack(spacing: 6) {
                        if completedCount == totalGames {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                            Text("Perfect Day!")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.yellow)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text("\(completedCount)/\(totalGames) completed")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(completedCount == totalGames ? .yellow.opacity(0.1) : .green.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(completedCount == totalGames ? .yellow.opacity(0.3) : .green.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(GameType.allCases, id: \.self) { gameType in
                    GameDayCard(
                        gameType: gameType,
                        date: selectedDate,
                        level: levelManager.getLevelForDate(selectedDate, gameType: gameType),
                        isCompleted: isGameCompletedForDate(selectedDate, gameType: gameType),
                        progress: getGameProgress(gameType),
                        onTap: {
                            if let level = levelManager.getLevelForDate(selectedDate, gameType: gameType) {
                                coordinator.startGame(
                                    gameType: gameType,
                                    level: level,
                                    context: .daily(selectedDate)
                                )
                            }
                        },
                        onMarkComplete: {
                            simulateGameCompletion(gameType: gameType, date: selectedDate)
                        }
                    )
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Quick Stats Section

    private var quickStatsSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Quick Stats")
                    .font(.headline)
                    .fontWeight(.medium)

                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                StatCard(
                    value: getTotalCompletedGames(),
                    label: "Total\nCompleted",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                StatCard(
                    value: getCurrentStreak(),
                    label: "Current\nStreak",
                    icon: "flame.fill",
                    color: .orange
                )

                StatCard(
                    value: getMaxStreak(),
                    label: "Best\nStreak",
                    icon: "star.fill",
                    color: .yellow
                )

                StatCard(
                    value: getPerfectDaysCount(),
                    label: "Perfect\nDays",
                    icon: "crown.fill",
                    color: .purple
                )
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Navigation Content

    @ViewBuilder
    private func navigationContent(for destination: GameCoordinator.NavigationDestination) -> some View {
        switch destination {
        case .practiceMode:
            PracticeModeView()
                .environment(coordinator)
                .environment(\.modelContext, modelContext)
                .navigationBarBackButtonHidden(true)
        case .gameSelection(let date):
            GameSelectionView(date: date)
                .environment(coordinator)
        case .statistics:
            StatisticsView()
                .environment(coordinator)
                .environment(\.modelContext, modelContext)
        }
    }

    @ViewBuilder
    private func sheetContent(for destination: GameCoordinator.SheetDestination) -> some View {
        switch destination {
        case .gameSelection(let date):
            GameSelectionSheet(date: date)
                .environment(coordinator)
        case .statistics:
            StatisticsSheet()
                .environment(coordinator)
                .environment(\.modelContext, modelContext)
        }
    }

    @ViewBuilder
    private func fullScreenContent(for destination: GameCoordinator.FullScreenDestination) -> some View {
        switch destination {
        case .gamePlay(let session):
            // Route to specific game view based on game type
            Group {
                switch session.gameType {
                case .pipe:
                    PipeGameView(session: session)
                case .shikaku:
                    ShikakuGameView(session: session)
                default:
                    GamePlayView(session: session)
                }
            }
            .environment(coordinator)
            .environment(\.modelContext, modelContext)
            .onChange(of: session.isCompleted) { _, isCompleted in
                if isCompleted {
                    progressManager?.recordCompletion(session: session)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func simulateGameCompletion(gameType: GameType, date: Date) {
        guard let progressManager = progressManager,
              let level = levelManager.getLevelForDate(date, gameType: gameType) else { return }

        // Check if already completed
        if progressManager.hasCompletedDate(date, gameType: gameType) {
            print("⚠️ Game already completed for \(gameType.displayName) on \(date)")
            return
        }

        // Create a mock completion
        let completion = DailyCompletion(
            date: date,
            gameType: gameType,
            levelDataId: level.id,
            completionTime: Double.random(in: 30...300)
        )

        modelContext.insert(completion)

        // Update game progress
        let fetchDescriptor = FetchDescriptor<GameProgress>(
            predicate: #Predicate<GameProgress> { $0.gameType == gameType }
        )

        if let progress = try? modelContext.fetch(fetchDescriptor).first {
            progress.updateProgress(completionTime: completion.completionTime)
        } else {
            let newProgress = GameProgress(gameType: gameType)
            newProgress.updateProgress(completionTime: completion.completionTime)
            modelContext.insert(newProgress)
        }

        // Update streaks
        updateStreaksForGame(gameType, date: date)

        do {
            try modelContext.save()
            print("✅ Simulated completion for \(gameType.displayName) on \(date)")

            // Check if all games for this date are now completed
            if checkDayComplete(date) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingCompletionCelebration = true
                }
            }
        } catch {
            print("❌ Failed to save simulated completion: \(error)")
        }
    }

    private func checkDayComplete(_ date: Date) -> Bool {
        let completedGames = GameType.allCases.filter { gameType in
            isGameCompletedForDate(date, gameType: gameType)
        }

        return completedGames.count == GameType.allCases.count
    }

    private func updateStreaksForGame(_ gameType: GameType, date: Date) {
        let today = Date()
        let calendar = Calendar.current
        var streakCount = 0
        var checkDate = today

        while true {
            if hasCompletedDateForStreak(checkDate, gameType: gameType) {
                streakCount += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDay
            } else {
                break
            }
        }

        let fetchDescriptor = FetchDescriptor<GameProgress>(
            predicate: #Predicate<GameProgress> { $0.gameType == gameType }
        )

        if let progress = try? modelContext.fetch(fetchDescriptor).first {
            progress.currentStreak = streakCount
            progress.maxStreak = max(progress.maxStreak, streakCount)
        }
    }

    private func hasCompletedDateForStreak(_ date: Date, gameType: GameType) -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let fetchDescriptor = FetchDescriptor<DailyCompletion>(
            predicate: #Predicate<DailyCompletion> { completion in
                completion.gameType == gameType &&
                completion.date >= startOfDay &&
                completion.date < endOfDay
            }
        )

        let completions = (try? modelContext.fetch(fetchDescriptor)) ?? []
        return !completions.isEmpty
    }

    private func navigateMonth(direction: Int) {
        withAnimation(.spring(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: direction, to: currentMonth) ?? currentMonth
        }
    }

    private func selectDate(_ date: Date) {
        withAnimation(.spring(duration: 0.2)) {
            selectedDate = date
        }
    }

    private func focusOnToday() {
        let today = Date()
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDate = today
            currentMonth = today
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: currentMonth)
    }

    private var selectedDateTitle: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: selectedDate)
        }
    }

    private var currentMonthDays: [CalendarDay] {
        let currentMonth = self.currentMonth
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth) else {
            return []
        }

        return daysInMonth.compactMap { dayNumber in
            if let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthInterval.start) {
                return CalendarDay(date: date, dayNumber: dayNumber, isCurrentMonth: true)
            }
            return nil
        }
    }

    private func generateCalendarDays() -> [CalendarDay] {
        let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 30

        var days: [CalendarDay] = []

        // Add empty days for the start of the week
        for i in 1..<firstWeekday {
            let emptyDate = calendar.date(byAdding: .day, value: -i, to: startOfMonth) ?? Date.distantPast
            days.append(CalendarDay(date: emptyDate, dayNumber: 0, isCurrentMonth: false))
        }

        // Add days of the month
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(CalendarDay(date: date, dayNumber: day, isCurrentMonth: true))
            }
        }

        return days
    }

    private func getDayCompletionStatus(_ date: Date) -> DayCompletionStatus {
        let completedGames = GameType.allCases.filter { gameType in
            isGameCompletedForDate(date, gameType: gameType)
        }

        if completedGames.count == GameType.allCases.count {
            return .allCompleted
        } else if !completedGames.isEmpty {
            return .partiallyCompleted(completedGames.count, GameType.allCases.count)
        } else {
            return .none
        }
    }

    private func getTotalCompletedToday() -> Int {
        return GameType.allCases.filter { gameType in
            isGameCompletedForDate(selectedDate, gameType: gameType)
        }.count
    }

    private func getTotalCompletedGames() -> Int {
        return allProgress.reduce(0) { $0 + $1.totalCompleted }
    }

    private func getCurrentStreak() -> Int {
        return allProgress.map(\.currentStreak).max() ?? 0
    }

    private func getMaxStreak() -> Int {
        return allProgress.map(\.maxStreak).max() ?? 0
    }

    private func getPerfectDaysCount() -> Int {
        let calendar = Calendar.current
        let today = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today

        var perfectDays = 0
        var checkDate = thirtyDaysAgo

        while checkDate <= today {
            let completedGames = GameType.allCases.filter { gameType in
                isGameCompletedForDate(checkDate, gameType: gameType)
            }

            if completedGames.count == GameType.allCases.count {
                perfectDays += 1
            }

            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? today
        }

        return perfectDays
    }

    // MARK: - SwiftData Helper Methods

    private func isGameCompletedForDate(_ date: Date, gameType: GameType) -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        return allCompletions.contains { completion in
            completion.gameType == gameType &&
            completion.date >= startOfDay &&
            completion.date < endOfDay
        }
    }

    private func getGameProgress(_ gameType: GameType) -> GameProgress? {
        return allProgress.first { $0.gameType == gameType }
    }
}

// MARK: - Supporting Types

struct CalendarDay {
    let date: Date
    let dayNumber: Int
    let isCurrentMonth: Bool
}

enum DayCompletionStatus {
    case none
    case partiallyCompleted(Int, Int) // completed, total
    case allCompleted
}
