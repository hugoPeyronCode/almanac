//
//  PracticeModeView.swift
//  Multi-Game Puzzle App
//
//  Simplified practice mode with game cards and basic stats
//

import SwiftUI
import SwiftData

struct PracticeModeView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(GameCoordinator.self) private var coordinator
  
  // SwiftData queries to observe changes
  @Query private var practiceSessions: [PracticeSession]
  @Query private var practiceProgress: [PracticeProgress]
  
  @State private var selectedMode: PracticeMode = .normal
  @State private var showingModeInfo = false
  
  // Marathon mode state
  @State private var marathonCount = 0
  @State private var isInMarathon = false
  
  // Sprint mode state
  @State private var sprintCount = 0
  @State private var sprintStartTime: Date?
  @State private var isInSprint = false
  
  private let levelManager = LevelManager.shared
  
  var body: some View {
    VStack(spacing: 0) {
      headerSection
        .padding(.horizontal)
        .padding(.top)
      
      ScrollView {
        VStack(spacing: 32) {
          modeSelectionSection
            .padding(.horizontal)
          
          if selectedMode == .normal {
            todayStatsSection
              .padding(.horizontal)
          } else {
            modeStatusSection
              .padding(.horizontal)
          }
          
          gameCardsSection
            .padding(.horizontal)
          
          overallStatsSection
            .padding(.horizontal)
          
          Spacer(minLength: 100)
        }
        .padding(.vertical, 32)
      }
    }
    .background(Color(.systemBackground))
    .navigationTitle("")
    .navigationBarBackButtonHidden(true)
    .onAppear {
      print("🔥 PracticeModeView appeared")
      print("🔥 Practice sessions count: \(practiceSessions.count)")
      print("🔥 Practice progress count: \(practiceProgress.count)")
    }
    .onReceive(NotificationCenter.default.publisher(for: .practiceSessionCompleted)) { notification in
      if let data = notification.object as? [String: Any],
         let mode = data["mode"] as? PracticeMode,
         mode == selectedMode {
        
        switch mode {
        case .marathon:
          marathonCount += 1
        case .sprint:
          sprintCount += 1
          if sprintCount >= 5 {
            endSprint()
          }
        case .normal:
          break
        }
      }
    }
  }
  
  // MARK: - Header Section
  
  private var headerSection: some View {
    VStack(spacing: 16) {
      Text("Practice Mode")
        .font(.largeTitle)
        .fontWeight(.bold)
      
      Text("Sharpen your skills with unlimited puzzles")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
  }
  
  // MARK: - Mode Selection Section
  
  private var modeSelectionSection: some View {
    VStack(spacing: 16) {
      HStack {
        Text("Practice Mode")
          .font(.headline)
          .fontWeight(.medium)
        
        Spacer()
        
        Button {
          showingModeInfo = true
        } label: {
          Image(systemName: "info.circle")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      
      HStack(spacing: 12) {
        ForEach(PracticeMode.allCases, id: \.self) { mode in
          ModeButton(
            mode: mode,
            isSelected: selectedMode == mode,
            isActive: isActiveMode(mode)
          ) {
            selectMode(mode)
          }
        }
      }
    }
    .sheet(isPresented: $showingModeInfo) {
      ModeInfoSheet()
        .presentationDetents([.medium])
    }
  }
  
  // MARK: - Mode Status Section
  
  private var modeStatusSection: some View {
    VStack(spacing: 20) {
      switch selectedMode {
      case .marathon:
        MarathonStatusCard(
          count: marathonCount,
          isActive: isInMarathon
        ) {
          // End marathon
          endMarathon()
        }
        
      case .sprint:
        SprintStatusCard(
          count: sprintCount,
          startTime: sprintStartTime,
          isActive: isInSprint
        ) {
          // End sprint
          endSprint()
        }
        
      case .normal:
        EmptyView()
      }
    }
  }
  
  // MARK: - Today Stats Section
  
  private var todayStatsSection: some View {
    VStack(spacing: 20) {
      HStack {
        Text("Today's Practice")
          .font(.headline)
          .fontWeight(.medium)
        
        Spacer()
      }
      
      let todayStats = getTodayPracticeStats()
      
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
        StatCard(
          value: todayStats.levelsPlayed,
          label: "Levels\nToday",
          icon: "calendar",
          color: .blue
        )
        
        StatCard(
          value: Int(todayStats.timePlayedMinutes),
          label: "Minutes\nToday",
          icon: "clock",
          color: .green
        )
      }
    }
  }
  
  // MARK: - Game Cards Section
  
  private var gameCardsSection: some View {
    VStack(spacing: 20) {
      HStack {
        Text("Choose Your Game")
          .font(.headline)
          .fontWeight(.medium)
        
        Spacer()
      }
      
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
        ForEach(GameType.allCases, id: \.self) { gameType in
          SimplePracticeCard(
            gameType: gameType,
            progress: getGameProgress(gameType),
            todayCount: getTodaySessionCount(for: gameType),
            totalLevels: levelManager.getTotalLevelsCount(for: gameType)
          ) {
            startPractice(gameType: gameType)
          }
        }
      }
    }
  }
  
  // MARK: - Overall Stats Section
  
  private var overallStatsSection: some View {
    VStack(spacing: 20) {
      HStack {
        Text("All Time Stats")
          .font(.headline)
          .fontWeight(.medium)
        
        Spacer()
      }
      
      let allTimeStats = getAllTimePracticeStats()
      
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
        StatCard(
          value: allTimeStats.totalLevels,
          label: "Total\nLevels",
          icon: "trophy",
          color: .yellow
        )
        
        StatCard(
          value: Int(allTimeStats.totalTimeHours),
          label: "Total\nHours",
          icon: "hourglass",
          color: .purple
        )
      }
    }
  }
  
  // MARK: - Helper Methods
  
  private func getGameProgress(_ gameType: GameType) -> PracticeProgress? {
    return practiceProgress.first { $0.gameType == gameType }
  }
  
  private func getTodaySessionCount(for gameType: GameType) -> Int {
    let today = Calendar.current.startOfDay(for: Date())
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
    
    return practiceSessions.filter { session in
      session.gameType == gameType &&
      session.startedAt >= today &&
      session.startedAt < tomorrow &&
      session.isCompleted
    }.count
  }
  
  private func startPractice(gameType: GameType) {
    guard let level = levelManager.getRandomLevelForGame(gameType) else {
      print("No available levels for \(gameType.displayName)")
      return
    }
    
    switch selectedMode {
    case .marathon:
      if !isInMarathon {
        startMarathon()
      }
    case .sprint:
      if !isInSprint {
        startSprint()
      }
    case .normal:
      break
    }
    
    coordinator.startGame(gameType: gameType, level: level, context: .practice(selectedMode))
  }
  
  // MARK: - Mode Management
  
  private func isActiveMode(_ mode: PracticeMode) -> Bool {
    switch mode {
    case .marathon: return isInMarathon
    case .sprint: return isInSprint
    case .normal: return false
    }
  }
  
  private func selectMode(_ mode: PracticeMode) {
    // End current mode if switching
    if selectedMode != mode {
      switch selectedMode {
      case .marathon:
        if isInMarathon { endMarathon() }
      case .sprint:
        if isInSprint { endSprint() }
      case .normal:
        break
      }
    }
    selectedMode = mode
  }
  
  private func startMarathon() {
    isInMarathon = true
    marathonCount = 0
  }
  
  private func endMarathon() {
    isInMarathon = false
    // Check for badge
    let badgeManager = BadgeManager(modelContext: modelContext)
    badgeManager.checkMarathonBadge(completedCount: marathonCount)
    marathonCount = 0
  }
  
  private func startSprint() {
    isInSprint = true
    sprintCount = 0
    sprintStartTime = Date()
  }
  
  private func endSprint() {
    isInSprint = false
    if let startTime = sprintStartTime {
      let duration = Date().timeIntervalSince(startTime)
      // Check for badge
      let badgeManager = BadgeManager(modelContext: modelContext)
      badgeManager.checkSprintBadge(totalTime: duration, completedCount: sprintCount)
    }
    sprintCount = 0
    sprintStartTime = nil
  }
  
  private func getTodayPracticeStats() -> (levelsPlayed: Int, timePlayedMinutes: Double) {
    let today = Calendar.current.startOfDay(for: Date())
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
    
    // Only count practice sessions from today
    let todaySessions = practiceSessions.filter { session in
      session.startedAt >= today && session.startedAt < tomorrow && session.isCompleted
    }
    
    let levelsPlayed = todaySessions.count
    let timePlayedSeconds = todaySessions.reduce(0) { $0 + $1.completionTime }
    let timePlayedMinutes = timePlayedSeconds / 60
    
    return (levelsPlayed, timePlayedMinutes)
  }
  
  private func getAllTimePracticeStats() -> (totalLevels: Int, totalTimeHours: Double) {
    let totalLevels = practiceProgress.reduce(0) { $0 + $1.completedSessions }
    let totalTimeSeconds = practiceProgress.reduce(0) { $0 + $1.totalPlayTime }
    let totalTimeHours = totalTimeSeconds / 3600
    
    return (totalLevels, totalTimeHours)
  }
}
