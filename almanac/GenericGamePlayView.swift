//
//  GamePlayView.swift
//  Multi-Game Puzzle App
//
//  Generic game play interface that adapts to different game types
//

import SwiftUI

struct GamePlayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(GameCoordinator.self) private var coordinator

    @State private var session: GameSession
    @State private var showExitConfirmation = false
    @State private var isPaused = false

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

                    // Game-specific content area
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
            // Resume timer if it was paused
            if session.isPaused {
                session.resume()
                isPaused = false
            }
        }
        .onDisappear {
            // Pause timer when view disappears
            if !session.isCompleted {
                session.pause()
                isPaused = true
            }
        }
        .confirmationDialog("Exit Game", isPresented: $showExitConfirmation) {
            Button("Exit", role: .destructive) {
                coordinator.dismissFullScreen()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to exit? Progress will be lost.")
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
                Text(session.formattedPlayTime)
                    .font(.headline)
                    .fontWeight(.medium)
                    .monospacedDigit()

                Text(formatEstimatedTime(session.level.estimatedTime))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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

                // Mock completion button for testing
                Button("Complete Game (Test)") {
                    completeGame()
                }
                .padding()
                .background(session.gameType.color)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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

                Text("Completed in \(session.formattedPlayTime)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
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

            Text("Game Paused")
                .font(.title)
                .fontWeight(.bold)

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

    private func formatEstimatedTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60

        if minutes > 0 {
            return "~\(minutes)m \(remainingSeconds)s"
        } else {
            return "~\(remainingSeconds)s"
        }
    }

    private func togglePause() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPaused.toggle()

            if isPaused {
                session.pause()
            } else {
                session.resume()
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

struct StatisticsView: View {
    var body: some View {
        Text("Statistics View")
            .font(.title)
    }
}

struct StatisticsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            StatisticsView()
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
}

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
