//
//  CalendarComponents.swift
//  Multi-Game Puzzle App
//
//  Supporting components for the calendar view
//

import SwiftUI

// MARK: - Calendar Day View

struct CalendarDayView: View {
  let day: CalendarDay
  let isSelected: Bool
  let completionStatus: DayCompletionStatus
  let selectedGamesColors: [Color]
  let isCompact: Bool
  let onTap: () -> Void

  private var isToday: Bool {
    Calendar.current.isDateInToday(day.date)
  }

  private var dayState: DayState {
    if !day.isCurrentMonth && !isCompact { return .inactive }
    if isToday { return .today }

    switch completionStatus {
    case .none: return .hasLevels
    case .partiallyCompleted: return .partiallyCompleted
    case .allCompleted: return .allCompleted
    }
  }

  enum DayState {
    case inactive, hasLevels, partiallyCompleted, allCompleted, today
  }

  var body: some View {
    Button(action: onTap) {
      if isCompact {
        compactDayView
          .padding(.vertical)
      } else {
        fullDayView
      }
    }
    .buttonStyle(.plain)
    .disabled(!day.isCurrentMonth && !isCompact)
    .sensoryFeedback(.impact(weight: .light), trigger: isSelected)
  }

  private var compactDayView: some View {
    VStack(spacing: 8) {
      ZStack {
        Circle()
          .fill(backgroundColor)
          .frame(width: 36, height: 36)
          .overlay(
            Circle()
              .stroke(isSelected ? Color.indigo : Color.clear, lineWidth: 2)
          )
          .overlay(progressRing)

        if dayState == .allCompleted {
          Image(systemName: "checkmark")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.background)
        } else if day.isCurrentMonth {
          Text("\(day.dayNumber)")
            .font(.system(size: 16, weight: isSelected ? .bold : .medium))
            .foregroundStyle(textColor)
        }
      }

      Text(dayLabel)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
    }
  }

  private var fullDayView: some View {
    VStack(spacing: 4) {
      ZStack {
        Circle()
          .foregroundStyle(.thinMaterial)
          .frame(width: 44, height: 44)
          .overlay(progressRing)
          .overlay(selectionHighlight)

        if dayState == .allCompleted {
          Image(systemName: "checkmark")
            .font(.title3)
            .fontWeight(.bold)
            .foregroundStyle(.background)
        } else if day.isCurrentMonth {
          Text("\(day.dayNumber)")
            .font(.system(size: 16, weight: dayState == .today ? .bold : .medium))
            .foregroundStyle(textColor)
        }
      }

      Text(dayLabel)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
    }
  }

  private var backgroundColor: Color {
    switch dayState {
    case .inactive:
      return Color.clear
    case .hasLevels:
      return Color.secondary.opacity(0.1)
    case .partiallyCompleted:
      return Color.primary.opacity(0.2)
    case .allCompleted:
      return Color.primary
    case .today:
      return Color.primary.opacity(0.4)
    }
  }

  private var textColor: Color {
    switch dayState {
    case .inactive:
      return .clear
    case .hasLevels:
      return .primary
    case .partiallyCompleted:
      return .primary
    case .allCompleted:
      return .primary
    case .today:
      return .primary
    }
  }

  private var progressRing: some View {
    Group {
      if case .partiallyCompleted(let completed, let total) = completionStatus, completed > 0 {
        let progress = Double(completed) / Double(total)

        Circle()
          .stroke(Color.clear, lineWidth: 3)
          .overlay(
            Circle()
              .trim(from: 0, to: progress)
              .stroke(
                LinearGradient(
                  colors: selectedGamesColors,
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
              )
              .rotationEffect(.degrees(-90))
              .animation(.easeInOut(duration: 0.5), value: progress)
          )
          .frame(width: isCompact ? 40 : 48, height: isCompact ? 40 : 48)
      }
    }
  }

  private var completionIndicator: some View {
    Group {
      if case .partiallyCompleted(let completed, let total) = completionStatus, !isCompact {
        VStack {
          HStack {
            Spacer()
            Text("\(completed)/\(total)")
              .font(.system(size: 8, weight: .bold))
              .foregroundStyle(.white)
              .padding(.horizontal, 4)
              .padding(.vertical, 2)
              .background(
                Capsule()
                  .fill(.primary.opacity(0.4))
              )
          }
          Spacer()
        }
        .frame(width: 44, height: 44)
      }
    }
  }

  private var selectionHighlight: some View {
    Group {
      if isSelected {
        Circle()
          .stroke(
            LinearGradient(
              colors: selectedGamesColors,
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 3
          )
          .frame(width: 48, height: 48)
          .shadow(color: .blue.opacity(0.3), radius: 4)
      }
    }
  }

  private var dayLabel: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "E"
    return day.isCurrentMonth || isCompact ? formatter.string(from: day.date) : ""
  }
}


#Preview {
  CalendarDayView(day: CalendarDay(date: Date(), dayNumber: 20, isCurrentMonth: true), isSelected: true, completionStatus: .partiallyCompleted(1, 5), selectedGamesColors: [.purple, .cyan, .brown, .orange], isCompact: false) {
    //
  }
}

// MARK: - Game Day Card

struct GameDayCard: View {
  let gameType: GameType
  let date: Date
  let level: AnyGameLevel?
  let isCompleted: Bool
  let progress: GameProgress?
  let onTap: () -> Void
  let onMarkComplete: (() -> Void)? = nil // Always nil now

  var body: some View {
    VStack(spacing: 0) {
      topSection
        .padding(.top, 16)
        .padding(.horizontal, 16)

      Spacer()

      bottomSection
        .padding(16)
        .background(gameType.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .frame(height: 100)
    .frame(maxWidth: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(.thinMaterial)
        .shadow(color: .primary.opacity(0.05), radius: 8, y: 4)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(
          isCompleted ? .gray.opacity(0.3) : gameType.color,
          lineWidth: isCompleted ? 0.5 : 1
        )
    )
    .overlay(
      Group {
        if isCompleted {
          VStack {
            HStack {
              Spacer()
              Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(gameType.color)
            }
            .padding(.top, 12)
            .padding(.trailing, 12)
            Spacer()
          }
        }
      }
    )
    .sensoryFeedback(.impact(weight: .medium), trigger: false)
  }

  private var topSection: some View {
    VStack(spacing: 12) {
      HStack {
        Image(systemName: gameType.icon)
          .font(.title2)
          .foregroundStyle(gameType.color)

        Text(gameType.displayName)
          .font(.headline)
          .fontWeight(.medium)
          .foregroundStyle(.primary)
          .frame(maxWidth: .infinity, alignment: .leading)

        Spacer()
      }
    }
  }

  private var bottomSection: some View {
    HStack(spacing: 12) {
      // Level info with stars and player time
      HStack {
        if let level = level {
          VStack(alignment: .leading, spacing: 4) {
            DifficultyStars(difficulty: level.difficulty, size: 10, spacing: 1)

            // Player's best time (if available)
            if let progress = progress, let bestTime = progress.bestTime {
              Text("\(formatTime(bestTime))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else {
              Text("No time yet")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
          }
        } else {
          VStack(alignment: .leading, spacing: 4) {
            DifficultyStars(difficulty: 1, size: 10, spacing: 1)

            Text("No level available")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }

        Spacer()

        if let progress = progress, progress.currentStreak > 0 {
          VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 2) {
              Image(systemName: "flame.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
              Text("\(progress.currentStreak)")
                .font(.caption)
                .foregroundStyle(.orange)
                .fontWeight(.medium)
            }

            Text("streak")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
        }
      }

      HStack {
        if isCompleted {
          HStack(spacing: 6) {
            Text("Completed")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundStyle(Color.primary)
          }
          .frame(maxWidth: 100)
          .padding(.vertical, 8)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(gameType.color.opacity(0.1))
          )
        } else {
          // Single Play button
          Button(action: onTap) {
            HStack(spacing: 4) {
              Image(systemName: "play.fill")
                .font(.caption)
              Text("Play")
                .font(.caption)
                .fontWeight(.medium)
            }
            .foregroundStyle(.background)
            .frame(minWidth: 100)
            .padding(.vertical, 8)
            .background(gameType.color, in: RoundedRectangle(cornerRadius: 8))
          }
          .sensoryFeedback(.impact(weight: .medium), trigger: false)
        }
      }
    }
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds) / 60
    let remainingSeconds = Int(seconds) % 60

    if minutes > 0 {
      return "\(minutes)m \(remainingSeconds)s"
    } else {
      return "\(remainingSeconds)s"
    }
  }
}

// MARK: - Stat Card

struct StatCard: View {
  let value: Int
  let label: String
  let icon: String
  let color: Color

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundStyle(.primary)

      Text("\(value)")
        .font(.title3)
        .fontWeight(.medium)
        .monospacedDigit()

      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(color.opacity(0.1))
    )
  }
}

#Preview("stats card") {
  StatCard(value: 150, label: "streak", icon: "fire.fill", color: .red)
}

#Preview("GameDayCard - All Game Types") {
  LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
    ForEach(GameType.allCases, id: \.self) { gameType in
      let mockLevel = createMockLevel(for: gameType)
      let mockProgress = createMockProgress(for: gameType)

      GameDayCard(
        gameType: gameType,
        date: Date(),
        level: mockLevel,
        isCompleted: Bool.random(),
        progress: mockProgress,
        onTap: {
          print("\(gameType.displayName) tapped")
        }
      )
    }
  }
  .padding()
}

private func createMockProgress(for gameType: GameType) -> GameProgress? {
  // 70% chance of having progress
  guard Bool.random() && Bool.random() else { return nil }

  let progress = GameProgress(gameType: gameType)
  progress.totalCompleted = Int.random(in: 1...30)
  progress.currentStreak = Int.random(in: 0...12)
  progress.maxStreak = max(progress.currentStreak, Int.random(in: 5...15))
  progress.bestTime = Double.random(in: 45...300)
  progress.averageTime = Double.random(in: 80...250)

  return progress
}


private func createMockLevel(for gameType: GameType) -> AnyGameLevel {
  do {
    let difficulty = Int.random(in: 1...5)
    let estimatedTime = TimeInterval(difficulty * 45 + Int.random(in: 30...90))

    switch gameType {
    case .shikaku:
      return try AnyGameLevel(MockShikakuLevel(
        id: "\(gameType.rawValue)_mock",
        difficulty: difficulty,
        estimatedTime: estimatedTime,
        gridRows: 4 + difficulty,
        gridCols: 4 + difficulty,
        clues: []
      ))
    case .pipe:
      return try AnyGameLevel(MockPipeLevel(
        id: "\(gameType.rawValue)_mock",
        difficulty: difficulty,
        estimatedTime: estimatedTime,
        gridSize: 3 + difficulty,
        pipes: []
      ))
    case .binario:
      return try AnyGameLevel(MockBinarioLevel(
        id: "\(gameType.rawValue)_mock",
        difficulty: difficulty,
        estimatedTime: estimatedTime,
        gridSize: 4 + (difficulty * 2),
        initialGrid: []
      ))
    case .sets:
      return try AnyGameLevel(MockWordleLevel(
        id: "\(gameType.rawValue)_mock",
        difficulty: difficulty,
        estimatedTime: estimatedTime,
        targetWord: ["SWIFT", "GAMES", "BRAIN", "TOUGH", "MAGIC"][difficulty - 1],
        maxAttempts: 6
      ))
    }
  } catch {
    fatalError("Failed to create mock level: \(error)")
  }
}


// MARK: - Star Difficulty Component

struct DifficultyStars: View {
  let difficulty: Int
  let maxStars: Int = 5
  let size: CGFloat
  let spacing: CGFloat

  init(difficulty: Int, size: CGFloat = 12, spacing: CGFloat = 2) {
    self.difficulty = max(1, min(5, difficulty)) // Clamp between 1-5
    self.size = size
    self.spacing = spacing
  }

  var body: some View {
    HStack(spacing: spacing) {
      ForEach(1...maxStars, id: \.self) { star in
        Image(systemName: star <= difficulty ? "star.fill" : "star")
          .font(.system(size: size))
          .foregroundStyle(star <= difficulty ? starColor(for: difficulty) : .secondary.opacity(0.3))
      }
    }
  }

  private func starColor(for difficulty: Int) -> Color {
    switch difficulty {
    case 1:
      return .green
    case 2:
      return .mint
    case 3:
      return .yellow
    case 4:
      return .orange
    case 5:
      return .red
    default:
      return .gray
    }
  }
}
