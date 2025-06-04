//
//  GamePlayView.swift
//  Multi-Game Puzzle App
//
//  Generic game play interface that adapts to different game types
//

import SwiftUI
import SwiftData

struct GamePlayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(GameCoordinator.self) private var coordinator

    @State private var session: GameSession
    @State private var showExitConfirmation = false
    @State private var isPaused = false

    // Timer state
    @State private var timer: Timer?
    @State private var currentPlayTime: TimeInterval = 0

    // Progress manager for data persistence
    @State private var progressManager: ProgressManager?

    init(session: GameSession) {
        self._session = State(initialValue: session)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundGradient

                VStack(spacing: 0) {
                    headerView
                        .padding()

                    Spacer()

                    gameContentArea
                        .containerRelativeFrame([.horizontal, .vertical]) { length, axis in
                            axis == .vertical ? length * 0.7 : length * 0.9
                        }

                    Spacer()

                    controlsView
                        .padding()
                }

                if session.isCompleted {
                    completionOverlay
                }

                if isPaused {
                    pauseOverlay
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupProgressManager()
            startTimer()

            // Resume timer if it was paused
            if session.isPaused {
                session.resume()
                isPaused = false
            }
        }
        .onDisappear {
            stopTimer()

            // Pause timer when view disappears
            if !session.isCompleted {
                session.pause()
                isPaused = true
            }
        }
        .confirmationDialog("Exit Game", isPresented: $showExitConfirmation) {
            Button("Exit", role: .destructive) {
                stopTimer()
                coordinator.dismissFullScreen()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to exit? Progress will be lost.")
        }
        .onChange(of: session.isCompleted) { _, isCompleted in
            if isCompleted {
                stopTimer()
                saveGameCompletion()
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Button {
                showExitConfirmation = true
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showExitConfirmation)

            Spacer()

            VStack(spacing: 4) {
                Text(contextTitle)
                    .font(.headline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(session.gameType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Difficulty \(session.level.difficulty)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                // Real-time timer display
              Text(Duration.seconds(currentPlayTime), format: .time(pattern: .minuteSecond))
                    .font(.headline)
                    .fontWeight(.medium)
                    .contentTransition(.numericText())
                    .monospacedDigit()
                    .foregroundStyle(isPaused ? .secondary : .primary)
            }
        }
    }

    // MARK: - Game Content Area

    @ViewBuilder
    private var gameContentArea: some View {
        VStack {
            // Game type indicator
            HStack {
                Image(systemName: session.gameType.icon)
                    .font(.title)
                    .foregroundStyle(session.gameType.color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.gameType.displayName)
                        .font(.title2)
                        .fontWeight(.medium)

                    Text("Level ID: \(session.level.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Game status indicator
                if isPaused {
                    Image(systemName: "pause.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                } else if session.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )

            Spacer()

            // Placeholder for actual game implementation
            VStack(spacing: 20) {
                Text("🎮")
                    .font(.system(size: 64))

                Text("Game Implementation")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("This is where the specific \(session.gameType.displayName.lowercased()) game would be implemented.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Debug completion button
                DebugCompleteButton(session: session, label: "Complete Game")
                    .disabled(session.isCompleted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            )

            Spacer()
        }
    }

    // MARK: - Controls View

    private var controlsView: some View {
        HStack {
            Button {
                togglePause()
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .sensoryFeedback(.impact(weight: .light), trigger: isPaused)
            .disabled(session.isCompleted)

            Spacer()

            // Game-specific controls would go here
            if case .practice = session.context {
                Button {
                    // Hint button for practice mode
                } label: {
                    Image(systemName: "lightbulb")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .disabled(session.isCompleted)
            }
        }
    }

    // MARK: - Completion Overlay

    private var completionOverlay: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Puzzle Complete!")
                    .font(.title)
                    .fontWeight(.bold)

              Text("Completed in \(currentPlayTime)")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                let congratulationText = getCongratulationText()
                if !congratulationText.isEmpty {
                    Text(congratulationText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }

            VStack(spacing: 12) {
                Button {
                    coordinator.dismissFullScreen()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(session.gameType.color, in: RoundedRectangle(cornerRadius: 12))
                }

                if case .practice = session.context {
                    Button {
                        startNewPracticeGame()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.trianglehead.counterclockwise")
                            Text("Play Again")
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(session.gameType.color)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(session.gameType.color, lineWidth: 2)
                        )
                    }
                }
            }
        }
        .padding(32)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        )
        .sensoryFeedback(.success, trigger: session.isCompleted)
    }

    // MARK: - Pause Overlay

    private var pauseOverlay: some View {
        VStack(spacing: 24) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Game Paused")
                    .font(.title)
                    .fontWeight(.bold)

              Text("Time: \(currentPlayTime)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                togglePause()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Resume")
                }
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 200, height: 50)
                .background(session.gameType.color, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    // MARK: - Timer Management

    private func startTimer() {
        stopTimer() // Ensure no duplicate timers

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateCurrentPlayTime()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateCurrentPlayTime() {
        guard !session.isCompleted && !isPaused else { return }
        currentPlayTime = session.actualPlayTime
    }

    // MARK: - Data Persistence

    private func setupProgressManager() {
        progressManager = ProgressManager(modelContext: modelContext)
    }

    private func saveGameCompletion() {
        guard let progressManager = progressManager else { return }

        do {
            // Update the session's final completion time
            session.complete()

            // Record completion in SwiftData
            progressManager.recordCompletion(session: session)

            // Save context immediately
            try modelContext.save()

          print("✅ Game completion saved: \(session.gameType.displayName) in \(currentPlayTime)")

        } catch {
            print("❌ Failed to save game completion: \(error)")
        }
    }

    // MARK: - Helper Methods

    private var contextTitle: String {
        switch session.context {
        case .daily: return "Daily Puzzle"
        case .practice: return "Practice"
        case .random: return "Random Puzzle"
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [.clear, session.gameType.color.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func getCongratulationText() -> String {
          return "Great job! 👏"
    }

    private func togglePause() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPaused.toggle()

            if isPaused {
                session.pause()
                stopTimer()
            } else {
                session.resume()
                startTimer()
            }
        }
    }

    private func completeGame() {
        session.complete()
    }

    private func startNewPracticeGame() {
        // Generate a new random level for practice
        let levelManager = LevelManager.shared

        if let newLevel = levelManager.getRandomLevelForGame(session.gameType) {
            let newSession = GameSession(
                gameType: session.gameType,
                level: newLevel,
                context: .practice
            )
            coordinator.presentFullScreen(.gamePlay(newSession))
        }
    }
}
// MARK: - Supporting Views

struct GameSelectionView: View {
    let date: Date

    var body: some View {
        Text("Game Selection for \(date.formatted(date: .abbreviated, time: .omitted))")
            .font(.title)
    }
}

struct GameSelectionSheet: View {
    let date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GameSelectionView(date: date)
                .navigationTitle("Select Game")
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
}

// MARK: - GamePlayView Previews

#Preview("GamePlayView - Shikaku Daily") {
    let mockLevel = try! AnyGameLevel(MockShikakuLevel(
        id: "shikaku_daily_1",
        difficulty: 3,
        estimatedTime: 180,
        gridRows: 6,
        gridCols: 6,
        clues: []
    ))

    let session = GameSession(
        gameType: .shikaku,
        level: mockLevel,
        context: .daily(Date())
    )

    GamePlayView(session: session)
        .environment(GameCoordinator())
}

#Preview("GamePlayView - Pipe Practice") {
    let mockLevel = try! AnyGameLevel(MockPipeLevel(
        id: "pipe_practice_1",
        difficulty: 2,
        estimatedTime: 120,
        gridSize: 5,
        pipes: []
    ))

    let session = GameSession(
        gameType: .pipe,
        level: mockLevel,
        context: .practice
    )

    GamePlayView(session: session)
        .environment(GameCoordinator())
}

#Preview("GamePlayView - Binario Random") {
    let mockLevel = try! AnyGameLevel(MockBinarioLevel(
        id: "binario_random_1",
        difficulty: 4,
        estimatedTime: 240,
        gridSize: 8,
        initialGrid: []
    ))

    let session = GameSession(
        gameType: .wordle,
        level: mockLevel,
        context: .random
    )

    GamePlayView(session: session)
        .environment(GameCoordinator())
}

#Preview("GamePlayView - Wordle Daily") {
    let mockLevel = try! AnyGameLevel(MockWordleLevel(
        id: "wordle_daily_1",
        difficulty: 3,
        estimatedTime: 300,
        targetWord: "SWIFT",
        maxAttempts: 6
    ))

    let session = GameSession(
        gameType: .sets,
        level: mockLevel,
        context: .daily(Date())
    )

    GamePlayView(session: session)
        .environment(GameCoordinator())
}

#Preview("GamePlayView - Completed State") {
    let mockLevel = try! AnyGameLevel(MockShikakuLevel(
        id: "shikaku_completed",
        difficulty: 1,
        estimatedTime: 60,
        gridRows: 4,
        gridCols: 4,
        clues: []
    ))

    let session = GameSession(
        gameType: .shikaku,
        level: mockLevel,
        context: .practice
    )

    // Simulate completion
    session.complete()

    return GamePlayView(session: session)
        .environment(GameCoordinator())
}

#Preview("GamePlayView - With SwiftData") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DailyCompletion.self, GameProgress.self, configurations: config)

    let mockLevel = try! AnyGameLevel(MockPipeLevel(
        id: "pipe_test",
        difficulty: 3,
        estimatedTime: 150,
        gridSize: 6,
        pipes: []
    ))

    let session = GameSession(
        gameType: .pipe,
        level: mockLevel,
        context: .daily(Date())
    )

    return GamePlayView(session: session)
        .environment(GameCoordinator())
        .modelContainer(container)
}

#Preview("GamePlayView - Dark Mode") {
    let mockLevel = try! AnyGameLevel(MockWordleLevel(
        id: "wordle_dark",
        difficulty: 2,
        estimatedTime: 180,
        targetWord: "THEME",
        maxAttempts: 6
    ))

    let session = GameSession(
        gameType: .sets,
        level: mockLevel,
        context: .practice
    )

    GamePlayView(session: session)
        .environment(GameCoordinator())
        .preferredColorScheme(.dark)
}

#Preview("GamePlayView - All Game Types") {
    TabView {
        ForEach(GameType.allCases, id: \.self) { gameType in
            let mockLevel = createMockLevel(for: gameType)
            let session = GameSession(
                gameType: gameType,
                level: mockLevel,
                context: .practice
            )

            GamePlayView(session: session)
                .environment(GameCoordinator())
                .tabItem {
                    Image(systemName: gameType.icon)
                    Text(gameType.displayName)
                }
        }
    }
}

// MARK: - Mock Data Helper Functions

private func createMockLevel(for gameType: GameType) -> AnyGameLevel {
    do {
        switch gameType {
        case .shikaku:
            return try AnyGameLevel(MockShikakuLevel(
                id: "\(gameType.rawValue)_mock",
                difficulty: 3,
                estimatedTime: 180,
                gridRows: 6,
                gridCols: 6,
                clues: []
            ))
        case .pipe:
            return try AnyGameLevel(MockPipeLevel(
                id: "\(gameType.rawValue)_mock",
                difficulty: 3,
                estimatedTime: 150,
                gridSize: 5,
                pipes: []
            ))
        case .wordle:
            return try AnyGameLevel(MockBinarioLevel(
                id: "\(gameType.rawValue)_mock",
                difficulty: 3,
                estimatedTime: 200,
                gridSize: 6,
                initialGrid: []
            ))
        case .sets:
            return try AnyGameLevel(MockWordleLevel(
                id: "\(gameType.rawValue)_mock",
                difficulty: 3,
                estimatedTime: 240,
                targetWord: "SWIFT",
                maxAttempts: 6
            ))
        }
    } catch {
        fatalError("Failed to create mock level: \(error)")
    }
}

// MARK: - Mock Level Data Structures

struct MockShikakuLevel: GameLevelData {
    let id: String
    let difficulty: Int
    let estimatedTime: TimeInterval
    let gridRows: Int
    let gridCols: Int
    let clues: [String]
}

struct MockPipeLevel: GameLevelData {
    let id: String
    let difficulty: Int
    let estimatedTime: TimeInterval
    let gridSize: Int
    let pipes: [String]
}

struct MockBinarioLevel: GameLevelData {
    let id: String
    let difficulty: Int
    let estimatedTime: TimeInterval
    let gridSize: Int
    let initialGrid: [[Int?]]

    init(id: String, difficulty: Int, estimatedTime: TimeInterval, gridSize: Int, initialGrid: [[Int?]]) {
        self.id = id
        self.difficulty = difficulty
        self.estimatedTime = estimatedTime
        self.gridSize = gridSize
        self.initialGrid = initialGrid.isEmpty ? Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize) : initialGrid
    }
}

struct MockWordleLevel: GameLevelData {
    let id: String
    let difficulty: Int
    let estimatedTime: TimeInterval
    let targetWord: String
    let maxAttempts: Int
}

// MARK: - Preview with Different Screen Sizes

#Preview("GamePlayView - iPhone SE") {
    let mockLevel = try! AnyGameLevel(MockShikakuLevel(
        id: "shikaku_se",
        difficulty: 2,
        estimatedTime: 120,
        gridRows: 5,
        gridCols: 5,
        clues: []
    ))

    let session = GameSession(
        gameType: .shikaku,
        level: mockLevel,
        context: .daily(Date())
    )

    GamePlayView(session: session)
        .environment(GameCoordinator())
}

#Preview("GamePlayView - iPhone 15 Pro Max") {
    let mockLevel = try! AnyGameLevel(MockPipeLevel(
        id: "pipe_pro_max",
        difficulty: 4,
        estimatedTime: 300,
        gridSize: 8,
        pipes: []
    ))

    let session = GameSession(
        gameType: .pipe,
        level: mockLevel,
        context: .practice
    )
    GamePlayView(session: session)
        .environment(GameCoordinator())
}
