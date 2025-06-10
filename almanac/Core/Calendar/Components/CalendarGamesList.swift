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
                canPlay: viewModel.canPlayGame(for: viewModel.selectedDate),
                onTap: {
                    handleGameTap()
                }
            )

            // Debug completion button
            if !viewModel.isGameCompletedForDate(viewModel.selectedDate, gameType: gameType, completions: completions)
                && viewModel.canPlayGame(for: viewModel.selectedDate) {
                DebugCompletionButton(
                    gameType: gameType,
                    date: viewModel.selectedDate,
                    viewModel: viewModel,
                    progressManager: progressManager
                )
            }
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
