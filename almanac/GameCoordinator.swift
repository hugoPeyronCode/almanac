//
//  GameCoordinator.swift
//  Multi-Game Puzzle App
//
//  Navigation and game session management
//

import SwiftUI
import SwiftData

@Observable
class GameCoordinator {
    var navigationPath = NavigationPath()
    var presentedSheet: SheetDestination?
    var presentedFullScreen: FullScreenDestination?

    enum NavigationDestination: Hashable {
        case practiceMode
        case gameSelection(Date)
        case statistics

        static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
            switch (lhs, rhs) {
            case (.practiceMode, .practiceMode), (.statistics, .statistics):
                return true
            case (.gameSelection(let lhsDate), .gameSelection(let rhsDate)):
                return Calendar.current.isDate(lhsDate, inSameDayAs: rhsDate)
            default:
                return false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case .practiceMode:
                hasher.combine("practiceMode")
            case .gameSelection(let date):
                hasher.combine("gameSelection")
                hasher.combine(Calendar.current.startOfDay(for: date))
            case .statistics:
                hasher.combine("statistics")
            }
        }
    }

    enum SheetDestination: Identifiable {
        case gameSelection(Date)
        case statistics

        var id: String {
            switch self {
            case .gameSelection: return "gameSelection"
            case .statistics: return "statistics"
            }
        }
    }

    enum FullScreenDestination: Identifiable, Equatable {
        case gamePlay(GameSession)

        var id: String {
            switch self {
            case .gamePlay: return "gamePlay"
            }
        }

        static func == (lhs: FullScreenDestination, rhs: FullScreenDestination) -> Bool {
            switch (lhs, rhs) {
            case (.gamePlay(let lhsSession), .gamePlay(let rhsSession)):
                return lhsSession.id == rhsSession.id
            }
        }
    }

    // MARK: - Navigation Actions

    func push(_ destination: NavigationDestination) {
        navigationPath.append(destination)
    }

    func presentSheet(_ destination: SheetDestination) {
        presentedSheet = destination
    }

    func presentFullScreen(_ destination: FullScreenDestination) {
        presentedFullScreen = destination
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    func dismissFullScreen() {
        presentedFullScreen = nil
    }

    func pop() {
        navigationPath.removeLast()
    }

    func popToRoot() {
        navigationPath = NavigationPath()
    }

    // MARK: - Game Actions

    func startGame(gameType: GameType, level: AnyGameLevel, context: GameSession.GameContext) {
        let session = GameSession(gameType: gameType, level: level, context: context)
        presentFullScreen(.gamePlay(session))
    }

    func showGameSelection(for date: Date) {
        presentSheet(.gameSelection(date))
    }

    func showStatistics() {
        presentSheet(.statistics)
    }
}

// MARK: - Game Session Management

@Observable
class GameSession {
    let id = UUID()
    let gameType: GameType
    let level: AnyGameLevel
    let context: GameContext
    var startTime = Date()
    var endTime: Date?
    var isCompleted = false
    var isPaused = false
    var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?

    enum GameContext {
        case daily(Date)
        case practice
        case random
    }

    init(gameType: GameType, level: AnyGameLevel, context: GameContext) {
        self.gameType = gameType
        self.level = level
        self.context = context
    }

    func complete() {
        guard !isCompleted else { return }
        isCompleted = true
        endTime = Date()
    }

    func pause() {
        guard !isPaused else { return }
        isPaused = true
        pauseStartTime = Date()
    }

    func resume() {
        guard isPaused, let pauseStart = pauseStartTime else { return }
        isPaused = false
        pausedDuration += Date().timeIntervalSince(pauseStart)
        pauseStartTime = nil
    }

    var actualPlayTime: TimeInterval {
        let end = endTime ?? Date()
        let totalTime = end.timeIntervalSince(startTime)
        let currentPauseDuration = isPaused ? Date().timeIntervalSince(pauseStartTime ?? Date()) : 0
        return totalTime - pausedDuration - currentPauseDuration
    }

    var formattedPlayTime: String {
        let time = actualPlayTime
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Progress Manager

@Observable
class ProgressManager {
    private let modelContext: ModelContext
    private let levelManager = LevelManager.shared

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func recordCompletion(session: GameSession) {
        // Record daily completion
        if case .daily(let date) = session.context {
            let completion = DailyCompletion(
                date: date,
                gameType: session.gameType,
                levelDataId: session.level.id,
                completionTime: session.actualPlayTime
            )
            modelContext.insert(completion)
        }

        // Update game progress
        updateGameProgress(for: session.gameType, completionTime: session.actualPlayTime)

        // Update streaks
        updateStreaks(for: session.gameType, date: session.context.date)

        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save completion: \(error)")
        }
    }

    private func updateGameProgress(for gameType: GameType, completionTime: TimeInterval) {
        let fetchDescriptor = FetchDescriptor<GameProgress>(
            predicate: #Predicate<GameProgress> { $0.gameType == gameType }
        )

        if let progress = try? modelContext.fetch(fetchDescriptor).first {
            progress.updateProgress(completionTime: completionTime)
        } else {
            let newProgress = GameProgress(gameType: gameType)
            newProgress.updateProgress(completionTime: completionTime)
            modelContext.insert(newProgress)
        }
    }

    private func updateStreaks(for gameType: GameType, date: Date?) {
        guard let date = date else { return }

        // Calculate current streak by checking consecutive days backwards from today
        let today = Date()
        let calendar = Calendar.current
        var streakCount = 0
        var checkDate = today

        while true {
            if hasCompletedDate(checkDate, gameType: gameType) {
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

    func hasCompletedDate(_ date: Date, gameType: GameType) -> Bool {
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

    func getProgressForGame(_ gameType: GameType) -> GameProgress? {
        let fetchDescriptor = FetchDescriptor<GameProgress>(
            predicate: #Predicate<GameProgress> { $0.gameType == gameType }
        )
        return try? modelContext.fetch(fetchDescriptor).first
    }

    func getAllProgress() -> [GameProgress] {
        let fetchDescriptor = FetchDescriptor<GameProgress>()
        return (try? modelContext.fetch(fetchDescriptor)) ?? []
    }

    func getCompletedLevelsCount(for gameType: GameType) -> Int {
        let fetchDescriptor = FetchDescriptor<DailyCompletion>(
            predicate: #Predicate<DailyCompletion> { $0.gameType == gameType }
        )
        return (try? modelContext.fetch(fetchDescriptor).count) ?? 0
    }
}

extension GameSession.GameContext {
    var date: Date? {
        switch self {
        case .daily(let date): return date
        default: return nil
        }
    }
}
