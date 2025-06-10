//
//  TabBar.swift
//  almanac
//
//  Smart TabBar with daily game integration
//

import SwiftUI
import SwiftData

struct TabBar: View {
  let leftButtonAction: () -> Void
  let rightButtonAction: () -> Void

  // Daily game state
  let selectedDate: Date
  let gameType: GameType
  let progressManager: ProgressManager?
  let coordinator: GameCoordinator

  // SwiftData queries to observe changes
  @Query private var allCompletions: [DailyCompletion]
  @Query private var allProgress: [GameProgress]

  @State private var isGameComplete: Bool = false
  @State private var triggerHaptics: Bool = false

  private let levelManager = LevelManager.shared

  var body: some View {
    ZStack {
      // Tab bar background
      tabBarBackground

      // Side buttons
      sideButtons

      // Center play button
      centerPlayButton
    }
    .frame(width: 200, height: 60)
    .sensoryFeedback(.impact(flexibility: .soft), trigger: triggerHaptics)
    .onAppear { updateGameState() }
    .onChange(of: selectedDate) { _, _ in updateGameState() }
  }

  // MARK: - Tab Bar Background

  private var tabBarBackground: some View {
    RoundedRectangle(cornerRadius: 25)
      .foregroundStyle(.ultraThinMaterial)
      .overlay {
        RoundedRectangle(cornerRadius: 25)
          .stroke(lineWidth: 1)
          .foregroundStyle(.secondary)
      }
  }

  // MARK: - Side Buttons

  private var sideButtons: some View {
    HStack {
      statsButton
      Spacer()
      practiceButton
    }
    .padding(.horizontal)
  }

  private var statsButton: some View {
    Button(action: {
      leftButtonAction()
      triggerHaptics.toggle()
    }) {
      Image(systemName: "chart.xyaxis.line")
        .foregroundStyle(Color.primary)
    }
  }

  private var practiceButton: some View {
    Button(action: {
      rightButtonAction()
      triggerHaptics.toggle()
    }) {
      Image(systemName: "dumbbell")
        .foregroundStyle(Color.primary)
    }
  }

  // MARK: - Center Play Button

  private var centerPlayButton: some View {
    Button(action: {
      handlePlayButtonTap()
      triggerHaptics.toggle()
    }) {
      playButtonContent
    }
    .disabled(isGameComplete)
  }

  @ViewBuilder
  private var playButtonContent: some View {
    ZStack {
      // Button background
      Circle()
        .fill(playButtonBackgroundColor)
        .frame(width: 50, height: 50)

      // Button icon
      playButtonIcon
        .font(.system(size: 16))
        .foregroundStyle(.white)
    }
    .scaleEffect(1.2)
    .opacity(isGameComplete ? 0.6 : 1.0)
    .animation(.easeInOut(duration: 0.2), value: isGameComplete)
  }

  private var playButtonBackgroundColor: Color {
    isGameComplete ? .green : gameType.color
  }

  @ViewBuilder
  private var playButtonIcon: some View {
    Image(systemName: isGameComplete ? "checkmark.circle.fill" : "play.fill")
  }

  // MARK: - Game State Management

  private func updateGameState() {
    isGameComplete = isGameCompletedForDate(selectedDate, gameType: gameType)

    let dateString = DateFormatter.localizedString(from: selectedDate, dateStyle: .short, timeStyle: .none)
    print("🔄 Game state for \(dateString):")
    print("   🎮 Game: \(gameType.displayName)")
    print("   ✅ Complete: \(isGameComplete)")
  }

  // MARK: - Play Button Action

  private func handlePlayButtonTap() {
    guard !isGameComplete else {
      print("🚫 Game already completed for \(selectedDate)")
      return
    }

    startGame(gameType)
  }

  private func startGame(_ gameType: GameType) {
    guard canPlayOnDate(selectedDate) else {
      print("🚫 Cannot play games in the future")
      return
    }

    guard let level = levelManager.getLevelForDate(selectedDate, gameType: gameType) else {
      print("❌ No level available for \(gameType.displayName)")
      return
    }

    let context = determineGameContext(for: selectedDate)

    // Final safety check for daily games
    if case .daily = context, isGameComplete {
      print("🚫 Preventing launch of completed daily game")
      return
    }

    print("🚀 Launching \(gameType.displayName) in \(context.displayName) mode")
    coordinator.startGame(gameType: gameType, level: level, context: context)
  }

  // MARK: - Helper Methods

  private func canPlayOnDate(_ date: Date) -> Bool {
    let today = Calendar.current.startOfDay(for: Date())
    let selectedDay = Calendar.current.startOfDay(for: date)
    return selectedDay <= today
  }

  private func determineGameContext(for date: Date) -> GameSession.GameContext {
    let today = Calendar.current.startOfDay(for: Date())
    let selectedDay = Calendar.current.startOfDay(for: date)

    return selectedDay == today ? .daily(date) : .practice()
  }

  private func isGameCompletedForDate(_ date: Date, gameType: GameType) -> Bool {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)

    return allCompletions.contains { completion in
      completion.gameType == gameType &&
      calendar.startOfDay(for: completion.date) == startOfDay
    }
  }
}

// MARK: - Preview

#Preview {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  let container = try! ModelContainer(for: DailyCompletion.self, GameProgress.self, configurations: config)

  TabBar(
    leftButtonAction: { print("Stats") },
    rightButtonAction: { print("Practice") },
    selectedDate: Date(),
    gameType: .wordle,
    progressManager: ProgressManager(modelContext: container.mainContext),
    coordinator: GameCoordinator()
  )
  .padding()
  .modelContainer(container)
}
