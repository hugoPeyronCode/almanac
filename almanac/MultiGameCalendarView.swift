//
//  MultiGameCalendarView.swift
//  Multi-Game Puzzle App
//
//  Main calendar interface for multi-game daily puzzles
//

import SwiftUI
import SwiftData

struct MultiGameCalendarView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.modelContext) private var modelContext

  // SwiftData queries to observe changes
  @Query private var allCompletions: [DailyCompletion]
  @Query private var allProgress: [GameProgress]

  @State private var coordinator = GameCoordinator()
  @State private var progressManager: ProgressManager?
  @State private var selectedDate = Date()
  @State private var currentMonth = Date()
  @State private var isCompactMode = true
  @State private var showingCompletionCelebration = false

  // MARK: - Game Filter State
  @State private var selectedGames: Set<GameType> = Set(GameType.allCases)
  @State private var showingAllGames = true
  @State private var showingFilters = false

  private let levelManager = LevelManager.shared
  private let calendar = Calendar.current

  var body: some View {
    NavigationStack(path: $coordinator.navigationPath) {
      ZStack{
        VStack(spacing: 0) {
          headerView
          ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 32) {
              gameFilterSection
              calendarSection
              selectedDateSection
              quickStatsSection

              Spacer(minLength: 100)
            }
            .padding(.top)
          }
        }
        VStack {
          Spacer()

          TabBar {
            coordinator.showStatistics()
          } middleButtonAction: {
            //
          } rightButtonAction: {
            coordinator.push(.practiceMode)
          }
        }
      }
      .environment(coordinator)
      .navigationDestination(for: GameCoordinator.NavigationDestination.self) { destination in
        navigationContent(for: destination)
      }
      .alert("🎉 Day Complete!", isPresented: $showingCompletionCelebration) {
        Button("Great!") { }
      } message: {
        Text("You've completed all \(selectedGames.count) selected games for \(selectedDateTitle)! 🏆")
      }
    }
    .sheet(item: $coordinator.presentedSheet) { destination in
      sheetContent(for: destination)
        .presentationBackground(.ultraThinMaterial)
    }
    .fullScreenCover(item: $coordinator.presentedFullScreen) { destination in
      fullScreenContent(for: destination)
        .presentationBackground(.ultraThinMaterial)
    }
    .onAppear {
      progressManager = ProgressManager(modelContext: modelContext)
      let today = Date()
      if !calendar.isDate(selectedDate, inSameDayAs: today) {
        selectedDate = today
        currentMonth = today
      }
    }
  }

  // MARK: - Header
  private var headerView: some View {
    HStack {
      Text("THE ALMANAC")
        .monospaced()
        .font(.title)
        .fontWeight(.black)

      Spacer()

      Button {
        withAnimation(.bouncy){
        showingFilters.toggle()
      }
      } label: {
        Image(systemName: showingFilters ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
          .font(.title2)
          .foregroundStyle(Color.secondary)
      }
    }
    .padding(.horizontal)
    .padding(.top, 8)
  }

  // MARK: - Game Filter Section
  @ViewBuilder
  private var gameFilterSection: some View {
      if showingFilters {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(GameType.allCases, id: \.self) { gameType in
              GameFilterChip(
                gameType: gameType,
                isSelected: selectedGames.contains(gameType),
                progress: getGameProgress(gameType)
              ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                  toggleGameSelection(gameType)
                }
              }
            }
          }
          .padding(.horizontal)
        }
    }
  }

  // MARK: - Calendar Section

  private var calendarSection: some View {
    VStack(spacing: 16) {
      monthNavigationHeader

      if isCompactMode {
        horizontalCalendarView
      } else {
        fullCalendarView
      }
    }
    .transition(.asymmetric(
      insertion: .move(edge: .top).combined(with: .opacity),
      removal: .move(edge: .top).combined(with: .opacity)
    ))
  }

  private var monthNavigationHeader: some View {
    HStack {
      Button {
        navigateMonth(direction: -1)
      } label: {
        Image(systemName: "chevron.left")
          .font(.title3)
          .foregroundStyle(Color.secondary)
      }
      .sensoryFeedback(.impact(weight: .light), trigger: currentMonth)

      Spacer()

      Text(monthTitle)
        .font(isCompactMode ? .headline : .title2)
        .fontWeight(.medium)

      Spacer()

      Button {
        focusOnToday()
      } label: {
        Image(systemName: "location")
          .font(.title3)
          .foregroundStyle(Color.secondary)
      }
      .sensoryFeedback(.impact(weight: .light), trigger: selectedDate)

      Button {
        withAnimation(.easeInOut(duration: 0.3)) {
          isCompactMode.toggle()
        }
      } label: {
        Image(systemName: isCompactMode ? "rectangle.grid.3x2" : "rectangle.compress.vertical")
          .font(.title3)
          .foregroundStyle(Color.secondary)
      }
      .sensoryFeedback(.impact(weight: .light), trigger: isCompactMode)

      Button {
        navigateMonth(direction: 1)
      } label: {
        Image(systemName: "chevron.right")
          .font(.title3)
          .foregroundStyle(Color.secondary)
      }
      .sensoryFeedback(.impact(weight: .light), trigger: currentMonth)
    }
    .padding(.horizontal)
  }

  private var horizontalCalendarView: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 12) {
          ForEach(currentMonthDays, id: \.date) { day in
            CalendarDayView(
              day: day,
              isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
              completionStatus: getFilteredDayCompletionStatus(day.date),
              isCompact: true
            ) {
              selectDate(day.date)
            }
            .id(day.date)
          }
        }
        .padding(.horizontal)
      }
      .onAppear {
        withAnimation(.easeInOut(duration: 0.5)) {
          proxy.scrollTo(Date(), anchor: .center)
        }
      }
      .onChange(of: selectedDate) { _, newDate in
        withAnimation(.easeInOut(duration: 0.3)) {
          proxy.scrollTo(newDate, anchor: .center)
        }
      }
    }
  }

  private var fullCalendarView: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
      ForEach(generateCalendarDays(), id: \.date) { day in
        CalendarDayView(
          day: day,
          isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
          completionStatus: getFilteredDayCompletionStatus(day.date),
          isCompact: false
        ) {
          selectDate(day.date)
        }
      }
    }
    .padding(.horizontal)
  }

  // MARK: - Selected Date Section

  private var selectedDateSection: some View {
    VStack(spacing: 20) {
      HStack {
        Text(selectedDateTitle)
          .font(.title2)
          .fontWeight(.medium)

        Spacer()

        let completedCount = getFilteredTotalCompletedToday()
        let totalGames = selectedGames.count

        if completedCount > 0 && totalGames > 0 {
          HStack(spacing: 6) {
            if completedCount == totalGames {
              Image(systemName: "crown.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
              Text("Perfect Day!")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.yellow)
            } else {
              Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)

              Text("\(completedCount)/\(totalGames) completed")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.green)
            }
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(
            Capsule()
              .fill(completedCount == totalGames ? .yellow.opacity(0.1) : .green.opacity(0.1))
              .overlay(
                Capsule()
                  .stroke(completedCount == totalGames ? .yellow.opacity(0.3) : .green.opacity(0.3), lineWidth: 1)
              )
          )
        }
      }

      if selectedGames.isEmpty {
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
      } else {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
          ForEach(Array(selectedGames).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { gameType in
            GameDayCard(
              gameType: gameType,
              date: selectedDate,
              level: levelManager.getLevelForDate(selectedDate, gameType: gameType),
              isCompleted: isGameCompletedForDate(selectedDate, gameType: gameType),
              progress: getGameProgress(gameType),
              onTap: {
                if let level = levelManager.getLevelForDate(selectedDate, gameType: gameType) {
                  coordinator.startGame(
                    gameType: gameType,
                    level: level,
                    context: .daily(selectedDate)
                  )
                }
              }
            )
          }
        }
      }
    }
    .padding(.horizontal)
  }

  // MARK: - Quick Stats Section

  private var quickStatsSection: some View {
    VStack(spacing: 20) {
      HStack {
        Text("Quick Stats")
          .font(.headline)
          .fontWeight(.medium)

        if !selectedGames.isEmpty && selectedGames.count < GameType.allCases.count {
          Text("(\(selectedGames.count) games)")
            .font(.caption)
            .foregroundStyle(Color.secondary)
        }

        Spacer()
      }

      if selectedGames.isEmpty {
        Text("Select games to see statistics")
          .font(.subheadline)
          .foregroundStyle(Color.secondary)
          .frame(maxWidth: .infinity, minHeight: 80)
      } else {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
          StatCard(
            value: getFilteredTotalCompletedGames(),
            label: "Total\nCompleted",
            icon: "checkmark.circle.fill",
            color: .green
          )

          StatCard(
            value: getFilteredCurrentStreak(),
            label: "Current\nStreak",
            icon: "flame.fill",
            color: .orange
          )

          StatCard(
            value: getFilteredMaxStreak(),
            label: "Best\nStreak",
            icon: "star.fill",
            color: .yellow
          )

          StatCard(
            value: getFilteredPerfectDaysCount(),
            label: "Perfect\nDays",
            icon: "crown.fill",
            color: .purple
          )
        }
      }
    }
    .padding(.horizontal)
  }

  // MARK: - Game Filter Logic

  private func toggleGameSelection(_ gameType: GameType) {
    if selectedGames.contains(gameType) {
      selectedGames.remove(gameType)
    } else {
      selectedGames.insert(gameType)
    }
    updateSelectAllState()
  }

  private func toggleSelectAll() {
    if showingAllGames {
      selectedGames.removeAll()
      showingAllGames = false
    } else {
      selectedGames = Set(GameType.allCases)
      showingAllGames = true
    }
  }

  private func updateSelectAllState() {
    showingAllGames = selectedGames.count == GameType.allCases.count
  }

  // MARK: - Filtered Data Methods

  private func getFilteredDayCompletionStatus(_ date: Date) -> DayCompletionStatus {
    let completedGames = selectedGames.filter { gameType in
      isGameCompletedForDate(date, gameType: gameType)
    }

    if completedGames.count == selectedGames.count && !selectedGames.isEmpty {
      return .allCompleted
    } else if !completedGames.isEmpty {
      return .partiallyCompleted(completedGames.count, selectedGames.count)
    } else {
      return .none
    }
  }

  private func getFilteredTotalCompletedToday() -> Int {
    return selectedGames.filter { gameType in
      isGameCompletedForDate(selectedDate, gameType: gameType)
    }.count
  }

  private func getFilteredTotalCompletedGames() -> Int {
    return allProgress
      .filter { selectedGames.contains($0.gameType) }
      .reduce(0) { $0 + $1.totalCompleted }
  }

  private func getFilteredCurrentStreak() -> Int {
    return allProgress
      .filter { selectedGames.contains($0.gameType) }
      .map(\.currentStreak)
      .max() ?? 0
  }

  private func getFilteredMaxStreak() -> Int {
    return allProgress
      .filter { selectedGames.contains($0.gameType) }
      .map(\.maxStreak)
      .max() ?? 0
  }

  private func getFilteredPerfectDaysCount() -> Int {
    let calendar = Calendar.current
    let today = Date()
    let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today

    var perfectDays = 0
    var checkDate = thirtyDaysAgo

    while checkDate <= today {
      let completedGames = selectedGames.filter { gameType in
        isGameCompletedForDate(checkDate, gameType: gameType)
      }

      if completedGames.count == selectedGames.count && !selectedGames.isEmpty {
        perfectDays += 1
      }

      checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? today
    }

    return perfectDays
  }

  // MARK: - Navigation Content (Keep existing implementation)

  @ViewBuilder
  private func navigationContent(for destination: GameCoordinator.NavigationDestination) -> some View {
    switch destination {
    case .practiceMode:
      PracticeModeView()
        .environment(coordinator)
        .environment(\.modelContext, modelContext)
        .navigationBarBackButtonHidden(true)
    case .gameSelection(let date):
      GameSelectionView(date: date)
        .environment(coordinator)
    case .statistics:
      StatisticsView()
        .environment(coordinator)
        .environment(\.modelContext, modelContext)
    }
  }

  @ViewBuilder
  private func sheetContent(for destination: GameCoordinator.SheetDestination) -> some View {
    switch destination {
    case .gameSelection(let date):
      GameSelectionSheet(date: date)
        .environment(coordinator)
    case .statistics:
      StatisticsSheet()
        .environment(coordinator)
        .environment(\.modelContext, modelContext)
    }
  }

  @ViewBuilder
  private func fullScreenContent(for destination: GameCoordinator.FullScreenDestination) -> some View {
    switch destination {
    case .gamePlay(let session):
      // Route to specific game view based on game type
      Group {
        switch session.gameType {
        case .pipe:
          PipeGameView(session: session)
        case .shikaku:
          ShikakuGameView(session: session)
        default:
          GamePlayView(session: session)
        }
      }
      .environment(coordinator)
      .environment(\.modelContext, modelContext)
      .onChange(of: session.isCompleted) { _, isCompleted in
        if isCompleted {
          progressManager?.recordCompletion(session: session)
        }
      }
    }
  }

  // MARK: - Helper Methods (Keep existing implementation but update for filtered data)

  private func navigateMonth(direction: Int) {
    withAnimation(.spring(duration: 0.3)) {
      currentMonth = calendar.date(byAdding: .month, value: direction, to: currentMonth) ?? currentMonth
    }
  }

  private func selectDate(_ date: Date) {
    withAnimation(.spring(duration: 0.2)) {
      selectedDate = date
    }
  }

  private func focusOnToday() {
    let today = Date()
    withAnimation(.easeInOut(duration: 0.3)) {
      selectedDate = today
      currentMonth = today
    }
  }

  private var monthTitle: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM"
    return formatter.string(from: currentMonth)
  }

  private var selectedDateTitle: String {
    if calendar.isDateInToday(selectedDate) {
      return "Today"
    } else if calendar.isDateInYesterday(selectedDate) {
      return "Yesterday"
    } else if calendar.isDateInTomorrow(selectedDate) {
      return "Tomorrow"
    } else {
      let formatter = DateFormatter()
      formatter.dateFormat = "EEEE, MMMM d"
      return formatter.string(from: selectedDate)
    }
  }

  private var currentMonthDays: [CalendarDay] {
    let currentMonth = self.currentMonth
    guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
          let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth) else {
      return []
    }

    return daysInMonth.compactMap { dayNumber in
      if let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthInterval.start) {
        return CalendarDay(date: date, dayNumber: dayNumber, isCurrentMonth: true)
      }
      return nil
    }
  }

  private func generateCalendarDays() -> [CalendarDay] {
    let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
    let firstWeekday = calendar.component(.weekday, from: startOfMonth)
    let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 30

    var days: [CalendarDay] = []

    // Add empty days for the start of the week
    for i in 1..<firstWeekday {
      let emptyDate = calendar.date(byAdding: .day, value: -i, to: startOfMonth) ?? Date.distantPast
      days.append(CalendarDay(date: emptyDate, dayNumber: 0, isCurrentMonth: false))
    }

    // Add days of the month
    for day in 1...daysInMonth {
      if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
        days.append(CalendarDay(date: date, dayNumber: day, isCurrentMonth: true))
      }
    }

    return days
  }

  // MARK: - SwiftData Helper Methods

  private func isGameCompletedForDate(_ date: Date, gameType: GameType) -> Bool {
    let startOfDay = Calendar.current.startOfDay(for: date)
    let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

    return allCompletions.contains { completion in
      completion.gameType == gameType &&
      completion.date >= startOfDay &&
      completion.date < endOfDay
    }
  }

  private func getGameProgress(_ gameType: GameType) -> GameProgress? {
    return allProgress.first { $0.gameType == gameType }
  }
}
// MARK: - Supporting Types

struct CalendarDay {
  let date: Date
  let dayNumber: Int
  let isCurrentMonth: Bool
}

enum DayCompletionStatus {
  case none
  case partiallyCompleted(Int, Int)
  case allCompleted
}


#Preview("Calendar - With Sample Data") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DailyCompletion.self, GameProgress.self, configurations: config)
    let context = container.mainContext

    // Add sample completions
    let today = Date()
    let calendar = Calendar.current

    // Create completions for the last few days
    for i in 0..<5 {
        if let date = calendar.date(byAdding: .day, value: -i, to: today) {
            // Complete some random games for each day
            let gamesToComplete = GameType.allCases.shuffled().prefix(Int.random(in: 1...4))

            for gameType in gamesToComplete {
                let completion = DailyCompletion(
                    date: date,
                    gameType: gameType,
                    levelDataId: "\(gameType.rawValue)_\(i)",
                    completionTime: Double.random(in: 60...300)
                )
                context.insert(completion)

                // Add corresponding progress
                let fetchDescriptor = FetchDescriptor<GameProgress>(
                    predicate: #Predicate<GameProgress> { $0.gameType == gameType }
                )

                if let progress = try? context.fetch(fetchDescriptor).first {
                    progress.updateProgress(completionTime: completion.completionTime)
                } else {
                    let newProgress = GameProgress(gameType: gameType)
                    newProgress.updateProgress(completionTime: completion.completionTime)
                    context.insert(newProgress)
                }
            }
        }
    }

    try? context.save()

    return MultiGameCalendarView()
        .modelContainer(container)
}


// MARK: - Game Filter Chip Component

struct GameFilterChip: View {
    let gameType: GameType
    let isSelected: Bool
    let progress: GameProgress?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: gameType.icon)
                        .font(.title3)
                        .foregroundStyle(gameType.color)

                    Text(gameType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(gameType.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? gameType.color : gameType.color.opacity(0.3),
                                lineWidth: isSelected ? 2 : 0
                            )
                    )
            )
        }
        .padding(.vertical, 5)
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.0 : 0.95)
        .animation(.spring(duration: 0.2), value: isSelected)
        .sensoryFeedback(.impact(weight: .light), trigger: isSelected)
    }
}

#Preview("Game Filter Chips") {
    ScrollView(.horizontal) {
        HStack(spacing: 12) {
            ForEach(GameType.allCases, id: \.self) { gameType in
                GameFilterChip(
                    gameType: gameType,
                    isSelected: gameType == .shikaku,
                    progress: nil
                ) {
                    print("Tapped \(gameType.displayName)")
                }
            }
        }
        .padding()
    }
}
