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
              .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
          )
          .overlay(progressRing)
          .overlay(completionIndicator)

        if dayState == .allCompleted {
          Image(systemName: "checkmark")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.white)
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
        RoundedRectangle(cornerRadius: 12)
          .fill(backgroundColor)
          .frame(width: 44, height: 44)
          .overlay(progressRing)
          .overlay(completionIndicator)
          .overlay(selectionHighlight)

        if dayState == .allCompleted {
          Image(systemName: "checkmark")
            .font(.title3)
            .fontWeight(.bold)
            .foregroundStyle(.white)
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
      return Color.orange.opacity(0.6)
    case .allCompleted:
      return Color.green
    case .today:
      return Color.blue.opacity(0.6)
    }
  }

  private var textColor: Color {
    switch dayState {
    case .inactive:
      return .clear
    case .hasLevels:
      return .primary
    case .partiallyCompleted:
      return .white
    case .allCompleted:
      return .white
    case .today:
      return .white
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
                  colors: [.orange, .yellow],
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
                  .fill(.black.opacity(0.4))
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
      if isSelected && !isCompact {
        RoundedRectangle(cornerRadius: 12)
          .stroke(
            LinearGradient(
              colors: [.blue, .cyan],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
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
  CalendarDayView(day: CalendarDay(date: Date(), dayNumber: 20, isCurrentMonth: true), isSelected: true, completionStatus: .partiallyCompleted(1, 5), isCompact: false) {
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
  let onMarkComplete: (() -> Void)?

  var body: some View {
    VStack(spacing: 0) {
      // Top section with game info
      topSection
        .padding(.top, 16)
        .padding(.horizontal, 16)

      Spacer()

      // Bottom section with level info and controls
      bottomSection
        .padding(16)
        .background(.ultraThinMaterial)
    }
    .containerRelativeFrame([.horizontal]) { length, _ in
      length * 0.45
    }
    .frame(height: 160) // Increased height for test button
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(.thinMaterial)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(
          isCompleted ? gameType.color : gameType.color.opacity(0.3),
          lineWidth: isCompleted ? 2 : 1
        )
    )
    .overlay(
      // Completion checkmark overlay
      Group {
        if isCompleted {
          VStack {
            HStack {
              Spacer()
              Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .background(
                  Circle()
                    .fill(gameType.color)
                    .frame(width: 28, height: 28)
                )
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
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

        Spacer()
      }

      Text(gameType.displayName)
        .font(.headline)
        .fontWeight(.medium)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var bottomSection: some View {
    VStack(spacing: 12) {
      // Level info
      HStack {
        if let level = level {
          VStack(alignment: .leading, spacing: 2) {
            Text("Difficulty \(level.difficulty)/5")
              .font(.caption)
              .foregroundStyle(.secondary)

            Text(formatTime(level.estimatedTime))
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
        } else {
          Text("No level available")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()
      }

      // Button controls
      HStack(spacing: 8) {
        if isCompleted {
          HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
              .font(.caption)
              .foregroundStyle(.green)
            Text("Completed")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundStyle(.green)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(.green.opacity(0.1))
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(.green.opacity(0.3), lineWidth: 1)
              )
          )
        } else {
          // Play button
          Button(action: onTap) {
            HStack(spacing: 4) {
              Image(systemName: "play.fill")
                .font(.caption)
              Text("Play")
                .font(.caption)
                .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(gameType.color, in: RoundedRectangle(cornerRadius: 8))
          }
          .sensoryFeedback(.impact(weight: .medium), trigger: false)

          // Test completion button
          if let onMarkComplete = onMarkComplete {
            Button(action: onMarkComplete) {
              HStack(spacing: 4) {
                Image(systemName: "checkmark")
                  .font(.caption)
                Text("Test")
                  .font(.caption)
                  .fontWeight(.medium)
              }
              .foregroundStyle(gameType.color)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 8)
              .background(
                RoundedRectangle(cornerRadius: 8)
                  .fill(gameType.color.opacity(0.1))
                  .overlay(
                    RoundedRectangle(cornerRadius: 8)
                      .stroke(gameType.color.opacity(0.5), lineWidth: 1)
                  )
              )
            }
            .sensoryFeedback(.success, trigger: false)
          }
        }
      }

      // Progress indicator
      if let progress = progress, progress.totalCompleted > 0 {
        HStack {
          Text("\(progress.totalCompleted) completed")
            .font(.caption2)
            .foregroundStyle(.tertiary)

          Spacer()

          if progress.currentStreak > 0 {
            HStack(spacing: 2) {
              Image(systemName: "flame.fill")
                .font(.system(size: 8))
                .foregroundStyle(.orange)
              Text("\(progress.currentStreak)")
                .font(.caption2)
                .foregroundStyle(.orange)
            }
          }
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
        .foregroundStyle(color)

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

#Preview {
  StatCard(value: 150, label: "streak", icon: "fire.fill", color: .red)
}
