//
//  CalendarViewModel.swift
//  almanac
//
//  ViewModel for CalendarView - Updated for single game play
//

import SwiftUI
import SwiftData

@Observable
class CalendarViewModel {
    // MARK: - Properties

    var selectedDate = Date()
    var currentMonth = Date()
    var selectedGames: Set<GameType> = []
    var showingAllGames = true
    var showingFilters = false
    var showingFullCalendar = false
    var showingCompletionCelebration = false
    var showingPipeLevelEditor = false

    private let calendar = Calendar.current
    private let selectedGamesKey = "SelectedGameTypes"
    private let levelManager = LevelManager.shared

    // MARK: - Computed Properties

    var isTodayVisible: Bool {
        calendar.isDate(selectedDate, inSameDayAs: Date()) &&
        calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }

    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    var selectedDateTitle: String {
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

    var weekOfMonth: String {
        let weekOfYear = calendar.component(.weekOfYear, from: currentMonth)
        let firstOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        let firstWeekOfMonth = calendar.component(.weekOfYear, from: firstOfMonth)

        let weekNumber = weekOfYear - firstWeekOfMonth + 1

        if weekNumber <= 0 {
            return "Week 1"
        } else if weekNumber > 5 {
            return "Week 5"
        }

        return "Week \(weekNumber)"
    }

    // MARK: - Initialization

    init() {
        loadSelectedGamesFromUserDefaults()
    }

    // MARK: - Public Methods

    func selectDate(_ date: Date) {
        withAnimation(.spring(duration: 0.2)) {
            selectedDate = date
        }
    }

    func focusOnToday() {
        let today = Date()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            selectedDate = today
            currentMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        }
    }

    func toggleGameSelection(_ gameType: GameType) {
        if selectedGames.contains(gameType) {
            selectedGames.remove(gameType)
        } else {
            selectedGames.insert(gameType)
        }
        updateSelectAllState()
        saveSelectedGamesToUserDefaults()
    }

    func toggleFilters() {
        withAnimation(.bouncy) {
            showingFilters.toggle()
        }
    }

    func canPlayGame(for date: Date) -> Bool {
        let today = calendar.startOfDay(for: Date())
        let selectedDay = calendar.startOfDay(for: date)
        return selectedDay <= today
    }

    func getGameContext(for date: Date) -> GameSession.GameContext {
        let today = calendar.startOfDay(for: Date())
        let selectedDay = calendar.startOfDay(for: date)

        if selectedDay <= today {
            return .daily(date)
        } else {
            return .practice()
        }
    }

    func getLevelForGame(_ gameType: GameType) -> AnyGameLevel? {
        return levelManager.getLevelForDate(selectedDate, gameType: gameType)
    }

    // MARK: - New Method for Getting Next Available Game

    func getNextAvailableGame(completions: [DailyCompletion]) -> GameType? {
        // Return nil if no games selected or can't play on this date
        guard !selectedGames.isEmpty, canPlayGame(for: selectedDate) else { return nil }

        // Find first uncompleted game from selected games
        let sortedGames = selectedGames.sorted { $0.rawValue < $1.rawValue }

        for gameType in sortedGames {
            if !isGameCompletedForDate(selectedDate, gameType: gameType, completions: completions) {
                return gameType
            }
        }

        // All games completed
        return nil
    }

    func getSelectedDayProgress(completions: [DailyCompletion]) -> DayProgress? {
        let gamesCount = selectedGames.count

        guard gamesCount > 0 else { return nil }
        guard canPlayGame(for: selectedDate) else { return nil }

        let completedCount = selectedGames.filter { gameType in
            isGameCompletedForDate(selectedDate, gameType: gameType, completions: completions)
        }.count

        let percentage = gamesCount > 0 ? Double(completedCount) / Double(gamesCount) : 0
        return DayProgress(completed: completedCount, total: gamesCount, percentage: percentage)
    }

    func isGameCompletedForDate(_ date: Date, gameType: GameType, completions: [DailyCompletion]) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return completions.contains { completion in
            completion.gameType == gameType &&
            completion.date >= startOfDay &&
            completion.date < endOfDay
        }
    }

    func getFilteredTotalCompletedToday(completions: [DailyCompletion]) -> Int {
        return selectedGames.filter { gameType in
            isGameCompletedForDate(selectedDate, gameType: gameType, completions: completions)
        }.count
    }

    // MARK: - Private Methods

    private func loadSelectedGamesFromUserDefaults() {
        if let savedGameTypes = UserDefaults.standard.array(forKey: selectedGamesKey) as? [String] {
            let gameTypes = savedGameTypes.compactMap { GameType(rawValue: $0) }
            selectedGames = Set(gameTypes)

            if selectedGames.isEmpty {
                selectedGames = Set(GameType.allCases)
            }
        } else {
            selectedGames = Set(GameType.allCases)
        }

        updateSelectAllState()
    }

    private func saveSelectedGamesToUserDefaults() {
        let gameTypeStrings = selectedGames.map { $0.rawValue }
        UserDefaults.standard.set(gameTypeStrings, forKey: selectedGamesKey)
    }

    private func updateSelectAllState() {
        showingAllGames = selectedGames.count == GameType.allCases.count
    }
}

struct DayProgress {
    let completed: Int
    let total: Int
    let percentage: Double
}
