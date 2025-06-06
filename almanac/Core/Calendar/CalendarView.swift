//
//  MultiGameCalendarView.swift
//  Multi-Game Puzzle App
//
//  Main calendar interface for multi-game daily puzzles
//

import SwiftUI
import SwiftData

struct CalendarView: View {
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
  @State private var showingPipeLevelEditor = false

  // MARK: - Game Filter State with UserDefaults persistence
  @State private var selectedGames: Set<GameType> = []
  @State private var showingAllGames = true
  @State private var showingFilters = false

  private let levelManager = LevelManager.shared
  private let calendar = Calendar.current

  private let selectedGamesKey = "SelectedGameTypes"

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
              streakSection
              quickStatsSection

              Spacer(minLength: 100)
            }
            .padding(.top)
          }
        }
        VStack {
          Spacer()

          TabBar(
            leftButtonAction: { coordinator.showStatistics() },
            rightButtonAction: { 
              coordinator.showPractice()
            },
            selectedDate: selectedDate,
            selectedGames: selectedGames,
            progressManager: progressManager,
            coordinator: coordinator
          )
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
      .alert("🎉 Day Complete!", isPresented: $showingCompletionCelebration) {
        Button("Great!") { }
      } message: {
        Text("You've completed all \(selectedGames.count) selected games for \(selectedDateTitle)! 🏆")
      }
    }
    .sheet(item: $coordinator.presentedSheet) { destination in
      switch destination {
      case .gameSelection(let date):
        GameSelectionSheet(date: date)
          .environment(coordinator)
          .presentationBackground(.ultraThinMaterial)
      }
    }
    .fullScreenCover(item: $coordinator.presentedFullScreen) { destination in
      switch destination {
      case .gamePlay(let session):
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
            default:
              GamePlayView(session: session)
            }
          }
        }
        .environment(coordinator)
        .environment(\.modelContext, modelContext)
        .onChange(of: session.isCompleted) { _, isCompleted in
          if isCompleted {
            if let progressManager = progressManager {
              progressManager.recordCompletion(session: session)
            }
          }
        }
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
    .fullScreenCover(isPresented: $showingPipeLevelEditor) {
      PipeLevelEditorView()
    }
    .onAppear {
      progressManager = ProgressManager(modelContext: modelContext)
      let today = Date()
      if !calendar.isDate(selectedDate, inSameDayAs: today) {
        selectedDate = today
        currentMonth = today
      }

      // Load selected games from UserDefaults on first appearance
      loadSelectedGamesFromUserDefaults()
    }
    .onChange(of: allCompletions.count) { _, newCount in
      // Completions count changed
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
      
      HStack(spacing: 16) {
        Button {
          coordinator.showProfile()
        } label: {
          Image(systemName: "person.circle.fill")
            .font(.title2)
            .foregroundStyle(Color.secondary)
        }
        
        Button {
          showingPipeLevelEditor = true
        } label: {
          Image(systemName: "wrench.and.screwdriver")
            .font(.title2)
            .foregroundStyle(Color.secondary)
        }

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
              selectedGamesColors: selectedGames.colors,
              isCompact: true,
              canPlay: canPlayGame(for: day.date)
            ) {
              selectDate(day.date)
            }
            .id(day.date)
          }
        }
        .padding(.horizontal)
      }
      .onAppear {
        let today = Date()
        withAnimation(.easeInOut(duration: 0.5)) {
          proxy.scrollTo(today, anchor: UnitPoint.center)
        }
      }
      .onChange(of: selectedDate) { _, newDate in
        withAnimation(.easeInOut(duration: 0.3)) {
          proxy.scrollTo(newDate, anchor: UnitPoint.center)
        }
      }
      .onChange(of: currentMonth) { _, _ in
        // When month changes, scroll to today if it's in the current month, otherwise to the 15th
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          let today = Date()
          let currentMonthStart = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
          
          // Check if today is in the current month being displayed
          if calendar.isDate(today, equalTo: currentMonth, toGranularity: .month) {
            // Today is in current month, scroll to today
            withAnimation(.easeInOut(duration: 0.4)) {
              proxy.scrollTo(today, anchor: UnitPoint.center)
            }
          } else {
            // Today is not in current month, scroll to middle of month (15th)
            if let fifteenth = calendar.date(byAdding: .day, value: 14, to: currentMonthStart) {
              withAnimation(.easeInOut(duration: 0.4)) {
                proxy.scrollTo(fifteenth, anchor: UnitPoint.center)
              }
            }
          }
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
          selectedGamesColors: selectedGames.colors,
          isCompact: false,
          canPlay: canPlayGame(for: day.date)
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
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Text(selectedDateTitle)
              .font(.title2)
              .fontWeight(.medium)
            
            if calendar.isDateInToday(selectedDate) {
              Image(systemName: "sun.max.fill")
                .font(.caption)
                .foregroundStyle(.orange)
            }
          }
          
          if !canPlayGame(for: selectedDate) {
            Text("Jeux non disponibles dans le futur")
              .font(.caption)
              .foregroundStyle(.orange)
          } else if !calendar.isDateInToday(selectedDate) {
            Text("Mode pratique")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

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
        //  LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16)
        LazyVStack {
          ForEach(Array(selectedGames).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { gameType in
            VStack(spacing: 8) {
              GameDayCard(
                gameType: gameType,
                date: selectedDate,
                level: levelManager.getLevelForDate(selectedDate, gameType: gameType),
                isCompleted: isGameCompletedForDate(selectedDate, gameType: gameType),
                progress: getGameProgress(gameType),
                canPlay: canPlayGame(for: selectedDate),
                onTap: {
                  guard canPlayGame(for: selectedDate) else {
                    return
                  }
                  
                  if let level = levelManager.getLevelForDate(selectedDate, gameType: gameType) {
                    let context = getGameContext(for: selectedDate)
                    coordinator.startGame(
                      gameType: gameType,
                      level: level,
                      context: context
                    )
                  }
                }
              )
              
              // Debug completion button
              if !isGameCompletedForDate(selectedDate, gameType: gameType) && canPlayGame(for: selectedDate) {
                Button("🚀 DEBUG: Complete \(gameType.displayName)") {
                  debugCompleteGame(gameType: gameType, date: selectedDate)
                }
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.red.opacity(0.2))
                .foregroundStyle(.red)
                .cornerRadius(6)
              }
            }
          }
        }
      }
    }
    .padding(.horizontal)
  }

  // MARK: - Streak Section
  
  private var streakSection: some View {
    VStack(spacing: 16) {
      if !selectedGames.isEmpty {
        StreakDisplayView(
          selectedGames: selectedGames,
          progressManager: progressManager,
          individualStreaks: getIndividualStreaks(),
          allGamesStreak: getAllGamesStreakLocal()
        )
        .padding(.horizontal)
      }
    }
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

  // MARK: - UserDefaults Persistence Methods

  private func loadSelectedGamesFromUserDefaults() {
    if let savedGameTypes = UserDefaults.standard.array(forKey: selectedGamesKey) as? [String] {
      let gameTypes = savedGameTypes.compactMap { GameType(rawValue: $0) }
      selectedGames = Set(gameTypes)

      // If no valid games were saved or all games are selected, default to all games
      if selectedGames.isEmpty {
        selectedGames = Set(GameType.allCases)
      }
    } else {
      // First time launch - default to all games
      selectedGames = Set(GameType.allCases)
    }

    updateSelectAllState()
  }

  private func saveSelectedGamesToUserDefaults() {
    let gameTypeStrings = selectedGames.map { $0.rawValue }
    UserDefaults.standard.set(gameTypeStrings, forKey: selectedGamesKey)
  }

  // MARK: - Game Filter Logic

  private func toggleGameSelection(_ gameType: GameType) {
    if selectedGames.contains(gameType) {
      selectedGames.remove(gameType)
    } else {
      selectedGames.insert(gameType)
    }
    updateSelectAllState()
    saveSelectedGamesToUserDefaults()
  }

  private func toggleSelectAll() {
    if showingAllGames {
      selectedGames.removeAll()
      showingAllGames = false
    } else {
      selectedGames = Set(GameType.allCases)
      showingAllGames = true
    }
    saveSelectedGamesToUserDefaults()
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
    let streaks = selectedGames.compactMap { gameType in
      let streak = calculateCurrentStreakLocal(for: gameType)
      return streak
    }
    
    let maxStreak = streaks.max() ?? 0
    return maxStreak
  }

  private func getFilteredMaxStreak() -> Int {
    let streaks = selectedGames.compactMap { gameType in
      let streak = calculateMaxStreakLocal(for: gameType)
      return streak
    }
    
    let maxStreak = streaks.max() ?? 0
    return maxStreak
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
        // Only show dates up to one week after today
        guard shouldShowDate(date) else { return nil }
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
        // Only show dates up to one week after today, but show past dates
        if shouldShowDate(date) {
          days.append(CalendarDay(date: date, dayNumber: day, isCurrentMonth: true))
        }
      }
    }

    return days
  }

  // MARK: - Game Context Helper
  
  private func getGameContext(for date: Date) -> GameSession.GameContext {
    let today = Calendar.current.startOfDay(for: Date())
    let selectedDay = Calendar.current.startOfDay(for: date)
    
    // Allow daily completions for today and past dates
    if selectedDay <= today {
      return .daily(date)
    } else {
      return .practice() // Only future dates are practice mode
    }
  }
  
  private func canPlayGame(for date: Date) -> Bool {
    let today = Calendar.current.startOfDay(for: Date())
    let selectedDay = Calendar.current.startOfDay(for: date)
    
    // Can play today and past dates, but not future dates
    return selectedDay <= today
  }
  
  private func shouldShowDate(_ date: Date) -> Bool {
    let today = Calendar.current.startOfDay(for: Date())
    let targetDate = Calendar.current.startOfDay(for: date)
    let weekAfterToday = Calendar.current.date(byAdding: .day, value: 7, to: today)!
    
    // Show only dates up to one week after today
    return targetDate <= weekAfterToday
  }

  // MARK: - Debug Helper
  
  private func debugCompleteGame(gameType: GameType, date: Date) {
    guard let level = levelManager.getLevelForDate(date, gameType: gameType),
          let progressManager = progressManager else {
      return
    }
    
    let context = getGameContext(for: date)
    let mockSession = GameSession(gameType: gameType, level: level, context: context)
    
    // Simulate a quick completion
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      mockSession.complete()
      progressManager.recordCompletion(session: mockSession)
    }
  }

  // MARK: - Local Streak Calculations (using @Query data directly)
  
  private func calculateCurrentStreakLocal(for gameType: GameType) -> Int {
    
    // Get completions for this game type from our @Query data
    let gameCompletions = allCompletions.filter { $0.gameType == gameType }
    
    guard !gameCompletions.isEmpty else {
      return 0
    }
    
    
    // Group completions by date and get unique dates
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    
    let completedDates = Set(gameCompletions.map { completion in
      dateFormatter.string(from: calendar.startOfDay(for: completion.date))
    })
    
    let sortedDates = completedDates.sorted(by: >)  // Most recent first
    
    guard let mostRecentDateString = sortedDates.first,
          let mostRecentDate = dateFormatter.date(from: mostRecentDateString) else {
      return 0
    }
    
    let today = calendar.startOfDay(for: Date())
    
    // If most recent completion is more than 1 day ago from today, streak is broken
    let daysBetween = calendar.dateComponents([.day], from: mostRecentDate, to: today).day ?? 0
    if daysBetween > 1 {
      return 0
    }
    
    // Count consecutive days backwards from most recent completion
    var streakCount = 0
    var checkDate = mostRecentDate
    
    while hasCompletedDateLocal(checkDate, gameType: gameType) {
      streakCount += 1
      guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
      checkDate = previousDay
    }
    
    return streakCount
  }
  
  private func calculateMaxStreakLocal(for gameType: GameType) -> Int {
    let gameCompletions = allCompletions.filter { $0.gameType == gameType }
    guard !gameCompletions.isEmpty else { return 0 }
    
    // Group completions by date
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    
    var completedDates = Set<String>()
    for completion in gameCompletions {
      let dateString = dateFormatter.string(from: completion.date)
      completedDates.insert(dateString)
    }
    
    // Sort dates and find longest consecutive sequence
    let sortedDates = completedDates.sorted()
    var maxStreak = 0
    var currentStreak = 0
    var lastDate: Date?
    
    for dateString in sortedDates {
      guard let date = dateFormatter.date(from: dateString) else { continue }
      
      if let last = lastDate,
         let daysDiff = calendar.dateComponents([.day], from: last, to: date).day,
         daysDiff == 1 {
        currentStreak += 1
      } else {
        currentStreak = 1
      }
      
      maxStreak = max(maxStreak, currentStreak)
      lastDate = date
    }
    
    return maxStreak
  }
  
  private func hasCompletedDateLocal(_ date: Date, gameType: GameType) -> Bool {
    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
    
    let hasCompleted = allCompletions.contains { completion in
      completion.gameType == gameType &&
      completion.date >= startOfDay &&
      completion.date < endOfDay
    }
    
    return hasCompleted
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
  
  // MARK: - Streak Data for StreakDisplayView
  
  private func getIndividualStreaks() -> [GameType: (current: Int, max: Int)] {
    var streaks: [GameType: (current: Int, max: Int)] = [:]
    
    for gameType in selectedGames {
      let current = calculateCurrentStreakLocal(for: gameType)
      let max = calculateMaxStreakLocal(for: gameType)
      streaks[gameType] = (current, max)
    }
    
    return streaks
  }
  
  private func getAllGamesStreakLocal() -> (current: Int, max: Int) {
    guard !selectedGames.isEmpty else { return (0, 0) }
    
    // For all-games streak, we need to find consecutive days where ALL selected games were completed
    let today = calendar.startOfDay(for: Date())
    
    // Get all unique completion dates
    let allDates = Set(allCompletions.map { calendar.startOfDay(for: $0.date) })
    let sortedDates = allDates.sorted(by: >)  // Most recent first
    
    // Find most recent date where all games were completed
    var mostRecentAllComplete: Date?
    
    for date in sortedDates {
      let completedGamesForDate = selectedGames.filter { gameType in
        hasCompletedDateLocal(date, gameType: gameType)
      }
      
      if completedGamesForDate.count == selectedGames.count {
        mostRecentAllComplete = date
        break
      }
    }
    
    guard let startDate = mostRecentAllComplete else {
      return (0, calculateMaxAllGamesStreakLocal())
    }
    
    // Check if there's a gap of more than 1 day
    let daysBetween = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
    if daysBetween > 1 {
      return (0, calculateMaxAllGamesStreakLocal())
    }
    
    // Count consecutive days where all games were completed
    var currentStreak = 0
    var checkDate = startDate
    
    while areAllGamesCompletedLocal(on: checkDate) {
      currentStreak += 1
      guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
      checkDate = previousDay
    }
    
    return (currentStreak, calculateMaxAllGamesStreakLocal())
  }
  
  private func areAllGamesCompletedLocal(on date: Date) -> Bool {
    for gameType in selectedGames {
      if !hasCompletedDateLocal(date, gameType: gameType) {
        return false
      }
    }
    return true
  }
  
  private func calculateMaxAllGamesStreakLocal() -> Int {
    guard !selectedGames.isEmpty else { return 0 }
    
    let allDates = Set(allCompletions.map { calendar.startOfDay(for: $0.date) })
    let sortedDates = allDates.sorted()
    
    var maxStreak = 0
    var currentStreak = 0
    var lastDate: Date?
    
    for date in sortedDates {
      // Check if all games completed on this date
      if areAllGamesCompletedLocal(on: date) {
        if let last = lastDate,
           let daysDiff = calendar.dateComponents([.day], from: last, to: date).day,
           daysDiff == 1 {
          currentStreak += 1
        } else {
          currentStreak = 1
        }
        
        maxStreak = max(maxStreak, currentStreak)
        lastDate = date
      } else {
        currentStreak = 0
        lastDate = nil
      }
    }
    
    return maxStreak
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

    return CalendarView()
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
                    // Tapped game type
                }
            }
        }
        .padding()
    }
}

extension Set where Element == GameType {
    /// Retourne un tableau des couleurs des jeux sélectionnés
    var colors: [Color] {
        return self.sorted(by: { $0.rawValue < $1.rawValue }).map { $0.color }
    }
}

