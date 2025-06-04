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
    .onChange(of: selectedGames) { _, _ in
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
    
    // Check completion status for selected games
    let completedGames = selectedGames.filter { gameType in
      isGameCompletedForDate(selectedDate, gameType: gameType)
    }
    
    allGamesComplete = completedGames.count == selectedGames.count
    isDayComplete = completedGames.count > 0
    
    if !allGamesComplete {
      // Find first uncompleted game to suggest
      let uncompletedGames = selectedGames.subtracting(Set(completedGames))
      availableGame = uncompletedGames.first ?? selectedGames.first
    } else {
      availableGame = nil
    }
  }
  
  private func handlePlayButtonTap() {
    guard !allGamesComplete else { return }
    
    // If no specific game available, show game selection
    guard let gameType = availableGame else {
      coordinator.showGameSelection(for: selectedDate)
      return
    }
    
    // Check if game is already completed for this date
    if isGameCompletedForDate(selectedDate, gameType: gameType) {
      // If this specific game is completed, find another or show selection
      let uncompletedGames = selectedGames.filter { !isGameCompletedForDate(selectedDate, gameType: $0) }
      
      if let nextGame = uncompletedGames.first {
        startGame(gameType: nextGame)
      } else {
        coordinator.showGameSelection(for: selectedDate)
      }
    } else {
      // Start the suggested game
      startGame(gameType: gameType)
    }
    
    triggerHaptics.toggle()
  }
  
  private func startGame(gameType: GameType) {
    guard let level = levelManager.getLevelForDate(selectedDate, gameType: gameType) else {
      print("❌ No level available for \(gameType.displayName) on \(selectedDate)")
      return
    }
    
    let context: GameSession.GameContext
    let today = Calendar.current.startOfDay(for: Date())
    let selectedDay = Calendar.current.startOfDay(for: selectedDate)
    
    if selectedDay == today {
      context = .daily(selectedDate)
    } else {
      context = .practice // Past/future dates are practice mode
    }
    
    coordinator.startGame(gameType: gameType, level: level, context: context)
  }
  
  private func isGameCompletedForDate(_ date: Date, gameType: GameType) -> Bool {
    return progressManager?.hasCompletedDate(date, gameType: gameType) ?? false
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
