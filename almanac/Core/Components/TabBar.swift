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
  let selectedGames: Set<GameType>
  let progressManager: ProgressManager?
  let coordinator: GameCoordinator
  
  // SwiftData queries to observe changes
  @Query private var allCompletions: [DailyCompletion]
  @Query private var allProgress: [GameProgress]
  
  @State private var triggerHaptics: Bool = false
  @State private var availableGame: GameType?
  @State private var isDayComplete: Bool = false
  @State private var allGamesComplete: Bool = false
  
  private let levelManager = LevelManager.shared

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 25)
        .foregroundStyle(.ultraThinMaterial)
        .overlay {
          RoundedRectangle(cornerRadius: 25)
            .stroke(lineWidth: 1)
            .foregroundStyle(.secondary)
        }

      HStack{
        Button {
          leftButtonAction()
          triggerHaptics.toggle()
        } label: {
          Image(systemName: "chart.xyaxis.line")
            .foregroundStyle(Color.primary)
        }

        Spacer()

        Button {
          rightButtonAction()
          triggerHaptics.toggle()
        } label: {
          Image(systemName: "dumbbell")
            .foregroundStyle(Color.primary)
        }
      }
      .padding(.horizontal)

      Button {
        handlePlayButtonTap()
      } label: {
        playButtonContent
      }
      .disabled(allGamesComplete)
    }
    .sensoryFeedback(.impact(flexibility: .soft), trigger: triggerHaptics)
    .frame(width: 200, height: 60)
    .onAppear {
      updateGameState()
    }
    .onChange(of: selectedDate) { _, _ in
      updateGameState()
    }
  }
  
  // MARK: - Play Button Content
  
  @ViewBuilder
  private var playButtonContent: some View {
    Circle()
      .foregroundStyle(.thinMaterial)
      .overlay {
        Circle()
          .stroke(lineWidth: 1)
          .foregroundStyle(playButtonBorderColor)
      }
      .overlay {
        playButtonIcon
      }
      .scaleEffect(1.2)
      .opacity(allGamesComplete ? 0.6 : 1.0)
      .animation(.easeInOut(duration: 0.2), value: allGamesComplete)
  }
  
  @ViewBuilder
  private var playButtonIcon: some View {
    if allGamesComplete {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
        .font(.title2)
    } else if let game = availableGame {
      VStack(spacing: 2) {
        Image(systemName: game.icon)
          .font(.caption)
          .foregroundStyle(game.color)
        
        if isDayComplete && selectedGames.count > 1 {
          // Show completion indicator when individual games are done but not all
          Circle()
            .fill(.green)
            .frame(width: 4, height: 4)
        }
      }
    } else {
      Image(systemName: "play.fill")
        .foregroundStyle(.mint)
    }
  }
  
  private var playButtonBorderColor: Color {
    if allGamesComplete {
      return .green
    } else if let game = availableGame {
      return game.color
    } else {
      return .mint
    }
  }
  
  // MARK: - Game Logic
  
  private func updateGameState() {
    guard !selectedGames.isEmpty else {
      availableGame = nil
      isDayComplete = false
      allGamesComplete = false
      return
    }
    
    let dateString = DateFormatter.localizedString(from: selectedDate, dateStyle: .short, timeStyle: .none)
    print("🔄 Updating game state for \(dateString) with \(selectedGames.count) selected games")
    print("   🗓️ Selected date (full): \(selectedDate)")
    print("   🗓️ Selected date (start of day): \(Calendar.current.startOfDay(for: selectedDate))")
    
    // Check completion status for selected games
    let completedGames = selectedGames.filter { gameType in
      isGameCompletedForDate(selectedDate, gameType: gameType)
    }
    
    print("📊 Completed games: \(completedGames.map { $0.displayName })")
    
    allGamesComplete = completedGames.count == selectedGames.count
    isDayComplete = completedGames.count > 0
    
    if !allGamesComplete {
      // Find first uncompleted game to suggest
      let uncompletedGames = selectedGames.subtracting(Set(completedGames))
      let sortedUncompletedGames = Array(uncompletedGames).sorted { $0.rawValue < $1.rawValue }
      availableGame = sortedUncompletedGames.first
      
      if let nextGame = availableGame {
        print("🎯 Next available game: \(nextGame.displayName)")
      } else {
        print("❌ No uncompleted games found")
      }
    } else {
      availableGame = nil
      print("✅ All games completed for this date")
    }
  }
  
  private func handlePlayButtonTap() {
    guard !allGamesComplete else { 
      print("🚫 All games complete for \(selectedDate)")
      return 
    }
    
    // If no specific game available, show game selection
    guard let gameType = availableGame else {
      print("🎮 No available game, showing selection for \(selectedDate)")
      coordinator.showGameSelection(for: selectedDate)
      return
    }
    
    // Double-check if game is already completed for this date
    if isGameCompletedForDate(selectedDate, gameType: gameType) {
      print("⚠️ Game \(gameType.displayName) already completed for \(selectedDate)")
      // Force update game state to find next available game
      updateGameState()
      
      // Try again with updated state
      if let nextGame = availableGame, !isGameCompletedForDate(selectedDate, gameType: nextGame) {
        startGame(gameType: nextGame)
      } else {
        coordinator.showGameSelection(for: selectedDate)
      }
    } else {
      // Start the suggested game
      print("🎯 Starting \(gameType.displayName) for \(selectedDate)")
      startGame(gameType: gameType)
    }
    
    triggerHaptics.toggle()
  }
  
  private func startGame(gameType: GameType) {
    // Prevent playing games in the future
    let today = Calendar.current.startOfDay(for: Date())
    let selectedDay = Calendar.current.startOfDay(for: selectedDate)
    
    guard selectedDay <= today else {
      print("🚫 Cannot play games in the future")
      return
    }
    
    guard let level = levelManager.getLevelForDate(selectedDate, gameType: gameType) else {
      print("❌ No level available for \(gameType.displayName) on \(selectedDate)")
      return
    }
    
    let context: GameSession.GameContext
    
    if selectedDay == today {
      context = .daily(selectedDate)
      
      // Final safety check: prevent starting completed daily games
      if isGameCompletedForDate(selectedDate, gameType: gameType) {
        print("🚫 Preventing launch of completed daily game: \(gameType.displayName)")
        coordinator.showGameSelection(for: selectedDate)
        return
      }
    } else {
      context = .practice() // Past dates are practice mode
    }
    
    print("🚀 Launching \(gameType.displayName) in \(context.displayName) mode")
    coordinator.startGame(gameType: gameType, level: level, context: context)
  }
  
  private func isGameCompletedForDate(_ date: Date, gameType: GameType) -> Bool {
    // Use a consistent calendar for date operations
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
    
    let matchingCompletions = allCompletions.filter { completion in
      let completionStartOfDay = calendar.startOfDay(for: completion.date)
      return completion.gameType == gameType && completionStartOfDay == startOfDay
    }
    
    let isCompleted = !matchingCompletions.isEmpty
    
    let dateString = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
    print("🔍 Checking \(gameType.displayName) for \(dateString):")
    print("   📅 Target date (start of day): \(startOfDay)")
    print("   📊 Total completions in DB: \(allCompletions.count)")
    print("   🎯 Matching completions: \(matchingCompletions.count)")
    
    // Debug all completions for this game
    let gameCompletions = allCompletions.filter { $0.gameType == gameType }
    for completion in gameCompletions {
      let completionStartOfDay = calendar.startOfDay(for: completion.date)
      let matches = completionStartOfDay == startOfDay
      print("   📝 Completion: \(completion.date) (start: \(completionStartOfDay)) -> \(matches ? "✅ MATCH" : "❌ no match")")
    }
    
    print("   📝 Result: \(isCompleted ? "✅ Completed" : "❌ Not completed")")
    
    return isCompleted
  }
}

#Preview {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  let container = try! ModelContainer(for: DailyCompletion.self, GameProgress.self, configurations: config)
  
  TabBar(
    leftButtonAction: { print("Stats") },
    rightButtonAction: { print("Practice") },
    selectedDate: Date(),
    selectedGames: Set([.wordle, .shikaku]),
    progressManager: ProgressManager(modelContext: container.mainContext),
    coordinator: GameCoordinator()
  )
  .padding()
  .modelContainer(container)
}
