//
//  CalendarView.swift
//  almanac
//
//  Main calendar interface - Refactored with ViewModel
//

import SwiftUI
import SwiftData

struct CalendarView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.modelContext) private var modelContext

  @Query private var allCompletions: [DailyCompletion]
  @Query private var allProgress: [GameProgress]

  @State private var coordinator = GameCoordinator()
  @State private var progressManager: ProgressManager?
  @State private var viewModel = CalendarViewModel()

  private let levelManager = LevelManager.shared
  private let calendar = Calendar.current

  private var currentGameType: GameType? {
    guard !viewModel.selectedGames.isEmpty else { return nil }

    if let nextGame = viewModel.getNextAvailableGame(completions: allCompletions) {
      return nextGame
    }
    return viewModel.selectedGames.sorted { $0.rawValue < $1.rawValue }.first
  }

  var body: some View {
    NavigationStack(path: $coordinator.navigationPath) {
      ZStack {
        VStack(spacing: 0) {
          CalendarHeaderView(
            viewModel: viewModel,
            coordinator: coordinator
          )

          ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 32) {
              if viewModel.showingFilters {
                GameFilterSection(
                  viewModel: viewModel,
                  progressData: allProgress
                )
              }

              CalendarSection(
                viewModel: viewModel,
                weekProgress: viewModel.getVisibleWeekProgress(completions: allCompletions)
              )

              SelectedDateSection(
                viewModel: viewModel,
                coordinator: coordinator,
                completions: allCompletions,
                progressData: allProgress,
                progressManager: progressManager,
                dayProgress: viewModel.getSelectedDayProgress(completions: allCompletions),
                completedCount: viewModel.getFilteredTotalCompletedToday(completions: allCompletions)
              )

              if !viewModel.selectedGames.isEmpty {
                StreakSection(
                  selectedGames: viewModel.selectedGames,
                  progressManager: progressManager,
                  allCompletions: allCompletions
                )
                .padding(.horizontal)
              }

              QuickStatsSection(
                viewModel: viewModel,
                allProgress: allProgress,
                allCompletions: allCompletions
              )
              .padding(.horizontal)

              Spacer(minLength: 100)
            }
            .padding(.top)
          }
        }

        VStack {
          Spacer()

          if let currentGameType = currentGameType {
            TabBar(
              leftButtonAction: { coordinator.showStatistics() },
              rightButtonAction: { coordinator.showPractice() },
              selectedDate: viewModel.selectedDate,
              gameType: currentGameType,
              progressManager: progressManager,
              coordinator: coordinator
            )
          }
        }
      }
      .background {
        Image(.dotsBackground)
          .resizable()
          .scaledToFill()
          .overlay {
            Rectangle()
              .foregroundStyle(.thinMaterial)
              .ignoresSafeArea()
          }
      }
      .environment(coordinator)
      .alert("🎉 Day Complete!", isPresented: $viewModel.showingCompletionCelebration) {
        Button("Great!") { }
      } message: {
        Text("You've completed all \(viewModel.selectedGames.count) selected games for \(viewModel.selectedDateTitle)! 🏆")
      }
    }
    .sheet(item: $coordinator.presentedSheet) { destination in
      handleSheet(destination)
    }
    .fullScreenCover(item: $coordinator.presentedFullScreen) { destination in
      handleFullScreen(destination)
    }
    .fullScreenCover(isPresented: $viewModel.showingPipeLevelEditor) {
      PipeLevelEditorView()
    }
    .fullScreenCover(isPresented: $viewModel.showingFullCalendar) {
      CalendarFullView(
        selectedDate: $viewModel.selectedDate,
        currentMonth: $viewModel.currentMonth,
        selectedGames: viewModel.selectedGames,
        onDateSelected: viewModel.selectDate
      )
    }
    .onAppear {
      setupOnAppear()
    }
  }

  // MARK: - Sheet Handling

  @ViewBuilder
  private func handleSheet(_ destination: GameCoordinator.SheetDestination) -> some View {
    switch destination {
    case .gameSelection(let date):
      GameSelectionSheet(date: date)
        .environment(coordinator)
        .presentationBackground(.ultraThinMaterial)
    }
  }

  // MARK: - Full Screen Handling

  @ViewBuilder
  private func handleFullScreen(_ destination: GameCoordinator.FullScreenDestination) -> some View {
    switch destination {
    case .gamePlay(let session):
      GamePlayView(session: session, coordinator: coordinator, progressManager: progressManager)
        .environment(\.modelContext, modelContext)

    case .statistics:
      NavigationView {
        StatisticsView()
          .environment(coordinator)
          .environment(\.modelContext, modelContext)
          .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
              CloseButton {
                coordinator.dismissFullScreen()
              }
            }
          }
      }

    case .practice:
      NavigationView {
        PracticeModeView()
          .environment(coordinator)
          .environment(\.modelContext, modelContext)
          .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
              CloseButton {
                coordinator.dismissFullScreen()
              }
            }
          }
      }

    case .profile:
      NavigationView {
        ProfileView()
          .environment(\.modelContext, modelContext)
          .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
              CloseButton {
                coordinator.dismissFullScreen()
              }
            }
          }
      }
    }
  }

  // MARK: - Setup

  private func setupOnAppear() {
    progressManager = ProgressManager(modelContext: modelContext)
    let today = Date()
    if !calendar.isDate(viewModel.selectedDate, inSameDayAs: today) {
      viewModel.selectedDate = today
      viewModel.currentMonth = today
    }
  }
}

// MARK: - Supporting Components

struct GameFilterSection: View {
  @Bindable var viewModel: CalendarViewModel
  let progressData: [GameProgress]

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(GameType.allCases, id: \.self) { gameType in
          GameFilterChip(
            gameType: gameType,
            isSelected: viewModel.selectedGames.contains(gameType),
            progress: getGameProgress(gameType)
          ) {
            withAnimation(.easeInOut(duration: 0.2)) {
              viewModel.toggleGameSelection(gameType)
            }
          }
        }
      }
      .padding(.horizontal)
    }
  }

  private func getGameProgress(_ gameType: GameType) -> GameProgress? {
    return progressData.first { $0.gameType == gameType }
  }
}

struct CalendarSection: View {
  @Bindable var viewModel: CalendarViewModel
  let weekProgress: WeekProgress?

  var body: some View {
    VStack(spacing: 16) {
      CalendarMonthHeader(
        viewModel: viewModel,
        weekProgress: weekProgress
      )

      CalendarHorizontalView(
        selectedDate: $viewModel.selectedDate,
        currentMonth: $viewModel.currentMonth,
        selectedGames: viewModel.selectedGames,
        onDateSelected: viewModel.selectDate
      )
    }
    .transition(.asymmetric(
      insertion: .move(edge: .top).combined(with: .opacity),
      removal: .move(edge: .top).combined(with: .opacity)
    ))
  }
}

struct SelectedDateSection: View {
  @Bindable var viewModel: CalendarViewModel
  let coordinator: GameCoordinator
  let completions: [DailyCompletion]
  let progressData: [GameProgress]
  let progressManager: ProgressManager?
  let dayProgress: DayProgress?
  let completedCount: Int

  var body: some View {
    VStack(spacing: 20) {
      CalendarDateHeader(
        viewModel: viewModel,
        dayProgress: dayProgress,
        completedCount: completedCount
      )
      
      CalendarGameList(
        viewModel: viewModel,
        coordinator: coordinator,
        completions: completions,
        progressData: progressData,
        progressManager: progressManager
      )
    }
    .padding(.horizontal)
  }
}

struct GamePlayView: View {
  let session: GameSession
  let coordinator: GameCoordinator
  let progressManager: ProgressManager?

  var body: some View {
    Group {
      if case .practice = session.context {
        PracticeGameWrapper(session: session)
      } else {
        switch session.gameType {
        case .pipe:
          PipeGameView(session: session)
        case .shikaku:
          ShikakuGameView(session: session)
        case .sets:
          SetsGameView(session: session)
        case .wordle:
          WordleGameView(session: session)
        }
      }
    }
    .environment(coordinator)
    .onChange(of: session.isCompleted) { _, isCompleted in
      if isCompleted {
        if let progressManager = progressManager {
          progressManager.recordCompletion(session: session)
        }
      }
    }
  }
}
