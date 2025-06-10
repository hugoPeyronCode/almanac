//
//  CalendarDayView.swift
//  almanac
//
//  Created by Hugo Peyron on 09/06/2025.
//


import SwiftUI

struct CalendarDayView: View {
  let day: CalendarDay
  let isSelected: Bool
  let completionStatus: DayCompletionStatus
  let selectedGamesColors: [Color]
  let isCompact: Bool
  let canPlay: Bool
  let onTap: () -> Void

  private var isToday: Bool {
    Calendar.current.isDateInToday(day.date)
  }

  private var dayState: DayState {
    if !day.isCurrentMonth && !isCompact { return .inactive }
    if !canPlay { return .disabled }

    switch completionStatus {
    case .none: 
      return isToday ? .today : .hasLevels
    case .partiallyCompleted: 
      return isToday ? .todayPartiallyCompleted : .partiallyCompleted
    case .allCompleted: 
      return isToday ? .todayAllCompleted : .allCompleted
    }
  }

  enum DayState {
    case inactive, hasLevels, partiallyCompleted, allCompleted, today, disabled
    case todayPartiallyCompleted, todayAllCompleted
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
    .disabled((!day.isCurrentMonth && !isCompact) || !canPlay)
    .sensoryFeedback(.impact(weight: .light), trigger: isSelected)
  }

  private var compactDayView: some View {
    VStack(spacing: 8) {
      ZStack {
        Circle()
          .fill(isSelected ? .thickMaterial : .ultraThinMaterial)
          .frame(width: 36, height: 36)
          .overlay(
            Circle()
              .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
              .scaleEffect(-0.7)
          )
          .overlay(progressRing)
          .overlay(todayHighlight)

        if dayState == .allCompleted || dayState == .todayAllCompleted {
          Image(systemName: "checkmark")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.primary)
        } else if day.isCurrentMonth {
          Text("\(day.dayNumber)")
            .font(.system(size: 16, weight: isSelected ? .bold : .medium))
            .foregroundStyle(dayState == .inactive ? .clear : dayState == .disabled ? .secondary : .primary)
        }
      }

      Text(dayLabel)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
    }
    .opacity(dayState == .disabled ? 0.4 : 1.0)
  }

  private var fullDayView: some View {
    VStack(spacing: 4) {
      ZStack {
        Circle()
          .foregroundStyle(isToday ? .ultraThinMaterial : .thinMaterial)
          .frame(width: 44, height: 44)
          .overlay(progressRing)
          .overlay(selectionHighlight)
          .overlay(todayHighlight)

        if dayState == .allCompleted || dayState == .todayAllCompleted {
          Image(systemName: "checkmark")
            .font(.title3)
            .fontWeight(.bold)
            .foregroundStyle(.primary)
        } else if day.isCurrentMonth {
          Text("\(day.dayNumber)")
            .font(.system(size: 16, weight: dayState == .today || dayState == .todayPartiallyCompleted ? .bold : .medium))
            .foregroundStyle(dayState == .inactive ? . clear : .primary)
        }
      }

      Text(dayLabel)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
    }
  }
  private var progressRing: some View {
    Group {
      if case .partiallyCompleted(let completed, let total) = completionStatus, completed > 0 {
        let progress = Double(completed) / Double(total)
            Circle()
              .trim(from: 0, to: progress)
              .stroke(
                LinearGradient(
                  colors: [.primary],
                  startPoint: UnitPoint.topLeading,
                  endPoint: UnitPoint.bottomTrailing
                ),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
              )
              .rotationEffect(Angle.degrees(-90))
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
              colors: [Color.primary],
              startPoint: UnitPoint.top,
              endPoint: UnitPoint.bottom
            ),
            lineWidth: 2
          )
          .frame(width: 40, height: 40)
          .shadow(color: Color.blue.opacity(0.3), radius: 4)
      }
    }
  }
  
  private var todayHighlight: some View {
    Group {
      if isToday {
        Circle()
          .stroke(
            LinearGradient(
              colors: [Color.orange, Color.yellow],
              startPoint: UnitPoint.topLeading,
              endPoint: UnitPoint.bottomTrailing
            ),
            lineWidth: 2
          )
          .frame(width: isCompact ? 40 : 48, height: isCompact ? 40 : 48)
          .shadow(color: Color.orange.opacity(0.4), radius: 3)
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
  CalendarDayView(day: CalendarDay(date: Date(), dayNumber: 20, isCurrentMonth: true), isSelected: true, completionStatus: .partiallyCompleted(1, 5), selectedGamesColors: [.purple, .cyan, .brown, .orange], isCompact: false, canPlay: true) {
  }
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
    case .wordle:
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
