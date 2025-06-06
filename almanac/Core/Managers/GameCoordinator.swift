//
//  GameCoordinator.swift
//  Multi-Game Puzzle App
//
//  Navigation and game session management
//

import SwiftUI
import SwiftData

// MARK: - Temporary Debug Button
struct DebugCompleteButton: View {
    let session: GameSession
    let label: String
    
    var body: some View {
        Button("🚀 DEBUG: \(label)") {
            session.complete()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.red.opacity(0.2))
        .foregroundStyle(.red)
        .cornerRadius(8)
        .font(.caption)
        .fontWeight(.medium)
    }
}

@Observable
class GameCoordinator {
    var navigationPath = NavigationPath()
    var presentedSheet: SheetDestination?
    var presentedFullScreen: FullScreenDestination?

    enum NavigationDestination: Hashable {
        case gameSelection(Date)

        static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
            switch (lhs, rhs) {
            case (.gameSelection(let lhsDate), .gameSelection(let rhsDate)):
                return Calendar.current.isDate(lhsDate, inSameDayAs: rhsDate)
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case .gameSelection(let date):
                hasher.combine("gameSelection")
                hasher.combine(Calendar.current.startOfDay(for: date))
            }
        }
    }

    enum SheetDestination: Identifiable {
        case gameSelection(Date)
        case statistics
        case practice
        case profile

        var id: String {
            switch self {
            case .gameSelection: return "gameSelection"
            case .statistics: return "statistics"
            case .practice: return "practice"
            case .profile: return "profile"
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
    
    func showProfile() {
        presentSheet(.profile)
    }
    
    func showPractice() {
        presentSheet(.practice)
    }
}

// MARK: - Game Session Management

@Observable
class GameSession {
    let id = UUID()
    let gameType: GameType
    let level: AnyGameLevel
    let context: GameContext

    // Time tracking
    private(set) var startTime = Date()
    private(set) var endTime: Date?
    private(set) var isCompleted = false
    private(set) var isPaused = false
    private(set) var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?

    // Session state
    private var lastActiveTime = Date()

    enum GameContext {
        case daily(Date)
        case practice(PracticeMode = .normal)
        case random
    }

    init(gameType: GameType, level: AnyGameLevel, context: GameContext) {
        self.gameType = gameType
        self.level = level
        self.context = context
        self.startTime = Date()
        self.lastActiveTime = startTime
    }

    func complete() {
        guard !isCompleted else { return }

        isCompleted = true
        endTime = Date()

        // If we were paused when completing, account for the current pause
        if isPaused, let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
            isPaused = false
        }

    }

    func pause() {
        guard !isPaused && !isCompleted else { return }

        isPaused = true
        pauseStartTime = Date()
        lastActiveTime = Date()

    }

    func resume() {
        guard isPaused, let pauseStart = pauseStartTime else { return }

        isPaused = false
        pausedDuration += Date().timeIntervalSince(pauseStart)
        pauseStartTime = nil
        lastActiveTime = Date()

    }

    // MARK: - Time Calculations

    /// Total time elapsed since game start, excluding paused time
    var actualPlayTime: TimeInterval {
        let endTimeToUse = endTime ?? Date()
        let totalElapsed = endTimeToUse.timeIntervalSince(startTime)

        // Account for current pause if in progress
        let currentPauseDuration = isPaused
            ? Date().timeIntervalSince(pauseStartTime ?? Date())
            : 0

        let totalPausedTime = pausedDuration + currentPauseDuration

        return max(0, totalElapsed - totalPausedTime)
    }

    /// Raw time elapsed since game start, including paused time
    var totalElapsedTime: TimeInterval {
        let endTimeToUse = endTime ?? Date()
        return endTimeToUse.timeIntervalSince(startTime)
    }

    var formattedPlayTime: String {
        let time = actualPlayTime
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var detailedTimeString: String {
        let time = actualPlayTime
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let centiseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, centiseconds)
    }

    // MARK: - Session Validation

    func validateSession() -> Bool {
        // Basic validation checks
        guard startTime <= Date() else { return false }
        guard actualPlayTime >= 0 else { return false }

        if let endTime = endTime {
            guard endTime >= startTime else { return false }
        }

        return true
    }

    // MARK: - Debug Information

    var debugTimeInfo: String {
        return """
        Session Debug Info:
        - Game: \(gameType.displayName)
        - Started: \(startTime)
        - Current Status: \(isCompleted ? "Completed" : isPaused ? "Paused" : "Active")
        - Actual Play Time: \(formattedPlayTime)
        - Total Elapsed: \(String(format: "%.1f", totalElapsedTime))s
        - Paused Duration: \(String(format: "%.1f", pausedDuration))s
        """
    }
}

// MARK: - Context Extensions

extension GameSession.GameContext {
    var date: Date? {
        switch self {
        case .daily(let date):
            return date
        default:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .daily:
            return "Daily Challenge"
        case .practice(let mode):
            return "\(mode.displayName) Practice"
        case .random:
            return "Random Level"
        }
    }

    var isDaily: Bool {
        if case .daily = self { return true }
        return false
    }
}

// MARK: - Progress Manager

@Observable
class ProgressManager {
    private let modelContext: ModelContext
    private let levelManager = LevelManager.shared
    private let statisticsManager: StatisticsManager

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.statisticsManager = StatisticsManager(modelContext: modelContext)
    }

    func recordCompletion(session: GameSession) {
        
        switch session.context {
        case .daily(let date):
            // Record daily completion
            let completion = DailyCompletion(
                date: date,
                gameType: session.gameType,
                levelDataId: session.level.id,
                completionTime: session.actualPlayTime
            )
            
            modelContext.insert(completion)
            
            // Update game progress for daily challenges
            updateGameProgress(for: session.gameType, completionTime: session.actualPlayTime)
            
            // Update streaks using the new StatisticsManager
            statisticsManager.updateStreaks(for: session.gameType)
            
        case .practice(let mode):
            // Record practice session
            let practiceSession = PracticeSession(
                gameType: session.gameType,
                levelDataId: session.level.id
            )
            practiceSession.markCompleted(in: session.actualPlayTime)
            
            
            modelContext.insert(practiceSession)
            
            // Update practice progress
            updatePracticeProgress(for: session.gameType, session: practiceSession)
            
            // Check badges for practice modes
            let badgeManager = BadgeManager(modelContext: modelContext)
            if let profile = getPlayerProfile() {
                profile.addExperience(10) // Base XP for completing puzzle
                badgeManager.checkAndUnlockBadges(profile: profile)
            }
            
            // Notify for mode-specific tracking
            NotificationCenter.default.post(
                name: .practiceSessionCompleted,
                object: ["mode": mode, "gameType": session.gameType]
            )
            
        case .random:
            break
        }

        do {
            try modelContext.save()
        } catch {
            // Failed to save completion
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
    
    private func updatePracticeProgress(for gameType: GameType, session: PracticeSession) {
        let fetchDescriptor = FetchDescriptor<PracticeProgress>(
            predicate: #Predicate<PracticeProgress> { $0.gameType == gameType }
        )

        if let progress = try? modelContext.fetch(fetchDescriptor).first {
            progress.updateProgress(session: session)
        } else {
            let newProgress = PracticeProgress(gameType: gameType)
            newProgress.updateProgress(session: session)
            modelContext.insert(newProgress)
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
    
    // Expose statistics manager for external use
    var statistics: StatisticsManager {
        return statisticsManager
    }
    
    private func getPlayerProfile() -> PlayerProfile? {
        let descriptor = FetchDescriptor<PlayerProfile>()
        return try? modelContext.fetch(descriptor).first
    }
}

// MARK: Sets GameSession Extension
extension GameSession {
  private static var setsGameInstances: [String: SetsGame] = [:]

  var setsGame: SetsGame {
    let sessionKey = "\(id.uuidString)"

    if let existingGame = Self.setsGameInstances[sessionKey] {
      return existingGame
    }

    let setsGame = SetsGame()

    if gameType == .sets {
      let levelData = SetsLevelData(id: level.id, difficulty: level.difficulty)
      setsGame.loadLevel(levelData)
    }

    Self.setsGameInstances[sessionKey] = setsGame
    return setsGame
  }

  func cleanupSetsGameInstance() {
    let sessionKey = "\(id.uuidString)"
    Self.setsGameInstances.removeValue(forKey: sessionKey)
  }
}

extension GameSession {
    private static var gameInstances: [String: ShikakuGame] = [:]

    var shikakuGame: ShikakuGame {
        // Use session ID as key to maintain unique game instances
        let sessionKey = "\(id.uuidString)"

        // Return existing game instance if it exists
        if let existingGame = Self.gameInstances[sessionKey] {
            return existingGame
        }

        // Create new game instance for this session
        let shikakuGame = ShikakuGame()

        // Load the actual level data if it's a Shikaku level
        if gameType == .shikaku {
            do {
                let levelData = try level.decode(as: ShikakuLevelData.self)
                shikakuGame.loadLevel(levelData)
            } catch {
                // Fallback: create a default level
                shikakuGame.loadDefaultLevel()
            }
        } else {
            // For non-Shikaku games, load default
            shikakuGame.loadDefaultLevel()
        }

        // Store the game instance
        Self.gameInstances[sessionKey] = shikakuGame

        return shikakuGame
    }

    // Clean up game instance when session ends
    func cleanupGameInstance() {
        let sessionKey = "\(id.uuidString)"
        Self.gameInstances.removeValue(forKey: sessionKey)
    }
}

extension GameSession {
    private static var wordleGameInstances: [String: WordleGame] = [:]

    var wordleGame: WordleGame {
        let sessionKey = "\(id.uuidString)"

        if let existingGame = Self.wordleGameInstances[sessionKey] {
            return existingGame
        }

        let wordleGame: WordleGame
        
        if gameType == .wordle {
            do {
                let levelData = try level.decode(as: WordleLevelData.self)
                wordleGame = WordleGame(targetWord: levelData.targetWord, maxAttempts: levelData.maxAttempts)
            } catch {
                wordleGame = WordleGame(targetWord: "SWIFT", maxAttempts: 6)
            }
        } else {
            wordleGame = WordleGame(targetWord: "SWIFT", maxAttempts: 6)
        }

        Self.wordleGameInstances[sessionKey] = wordleGame
        return wordleGame
    }

    func cleanupWordleGameInstance() {
        let sessionKey = "\(id.uuidString)"
        Self.wordleGameInstances.removeValue(forKey: sessionKey)
    }
}
