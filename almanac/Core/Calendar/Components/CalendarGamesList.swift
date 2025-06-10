//
//  CalendarGameList.swift
//  almanac
//
//  List of games for selected date
//

import SwiftUI
import SwiftData

struct CalendarGameList: View {
  @Bindable var viewModel: CalendarViewModel
  let coordinator: GameCoordinator
  let completions: [DailyCompletion]
  let progressData: [GameProgress]
  let progressManager: ProgressManager?

  var body: some View {
    if viewModel.selectedGames.isEmpty {
      EmptyGamesView()
    } else {
      LazyVStack(spacing: 12) {
        ForEach(sortedSelectedGames, id: \.self) { gameType in
          GameListItem(
            gameType: gameType,
            viewModel: viewModel,
            coordinator: coordinator,
            completions: completions,
            progressData: progressData,
            progressManager: progressManager
          )
        }
      }
    }
  }

  private var sortedSelectedGames: [GameType] {
    Array(viewModel.selectedGames).sorted(by: { $0.rawValue < $1.rawValue })
  }
}

struct GameListItem: View {
  let gameType: GameType
  @Bindable var viewModel: CalendarViewModel
  let coordinator: GameCoordinator
  let completions: [DailyCompletion]
  let progressData: [GameProgress]
  let progressManager: ProgressManager?

  private let calendar = Calendar.current

  var body: some View {
    VStack(spacing: 8) {
      GameDayCard(
        gameType: gameType,
        date: viewModel.selectedDate,
        level: viewModel.getLevelForGame(gameType),
        isCompleted: viewModel.isGameCompletedForDate(
          viewModel.selectedDate,
          gameType: gameType,
          completions: completions
        ),
        progress: getGameProgress(gameType),
        completionTime: getCompletionTimeForDate(viewModel.selectedDate, gameType: gameType),
        canPlay: viewModel.canPlayGame(for: viewModel.selectedDate),
        onTap: {
          handleGameTap()
        }
      )
    }
  }

  private func handleGameTap() {
    guard viewModel.canPlayGame(for: viewModel.selectedDate) else { return }

    if let level = viewModel.getLevelForGame(gameType) {
      let context = viewModel.getGameContext(for: viewModel.selectedDate)
      coordinator.startGame(
        gameType: gameType,
        level: level,
        context: context
      )
    }
  }

  private func getGameProgress(_ gameType: GameType) -> GameProgress? {
    return progressData.first { $0.gameType == gameType }
  }

  private func getCompletionTimeForDate(_ date: Date, gameType: GameType) -> TimeInterval? {
    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

    // Find the completion for this specific date and game type
    let completion = completions.first { completion in
      completion.gameType == gameType &&
      completion.date >= startOfDay &&
      completion.date < endOfDay
    }

    return completion?.completionTime
  }
}

struct EmptyGamesView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "gamecontroller")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)

      Text("No games selected")
        .font(.headline)
        .foregroundStyle(.secondary)

      Text("Select games above to see your daily puzzles")
        .font(.subheadline)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, minHeight: 120)
  }
}

struct DebugCompletionButton: View {
  let gameType: GameType
  let date: Date
  let viewModel: CalendarViewModel
  let progressManager: ProgressManager?

  var body: some View {
    Button("🚀 DEBUG: Complete \(gameType.displayName)") {
      debugCompleteGame()
    }
    .font(.caption2)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(.red.opacity(0.2))
    .foregroundStyle(.red)
    .cornerRadius(6)
  }

  private func debugCompleteGame() {
    guard let level = viewModel.getLevelForGame(gameType),
          let progressManager = progressManager else {
      return
    }

    let context = viewModel.getGameContext(for: date)
    let mockSession = GameSession(gameType: gameType, level: level, context: context)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      mockSession.complete()
      progressManager.recordCompletion(session: mockSession)
    }
  }
}
