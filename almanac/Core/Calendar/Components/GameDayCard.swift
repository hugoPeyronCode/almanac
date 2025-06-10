//
//  GameDayCard.swift
//  almanac
//
//  Created by Hugo Peyron on 09/06/2025.
//

import SwiftUI

struct GameDayCard: View {
  let gameType: GameType
  let date: Date
  let level: AnyGameLevel?
  let isCompleted: Bool
  let progress: GameProgress?
  let canPlay: Bool
  let onTap: () -> Void
  let onMarkComplete: (() -> Void)? = nil // Always nil now

  var body: some View {
    ZStack {
      HStack(spacing: 0) {
        leftSection
        Spacer()
        rightSection
      }
      gameIcon
    }
    .padding(.leading, 16)
    .padding(.trailing, 8)
    .padding(.vertical, 12)
    .frame(height: 100)
    .frame(maxWidth: .infinity)
    .background(cardBackground)
    .overlay(cardBorder)
    .opacity(canPlay ? 1.0 : 0.6)
    .sensoryFeedback(.impact(weight: .medium), trigger: false)
  }

  // MARK: - Card Background & Border

  private var cardBackground: some View {
    RoundedRectangle(cornerRadius: 16)
      .foregroundStyle(gameType.color.opacity(0.15))
      .shadow(color: .primary.opacity(0.05), radius: 8, y: 4)
  }

  private var cardBorder: some View {
    RoundedRectangle(cornerRadius: 16)
      .stroke(
        !canPlay ? .orange.opacity(0.5) : isCompleted ? .gray.opacity(0.3) : gameType.color,
        lineWidth: !canPlay ? 1 : isCompleted ? 0.5 : 1
      )
  }

  // MARK: - Left Section

  private var leftSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      gameTitle
      Spacer()
      bottomLeftInfo
    }
  }

  private var gameTitle: some View {
    Text(gameType.displayName)
      .font(.headline)
      .fontWeight(.medium)
      .foregroundStyle(.primary)
  }

  private var bottomLeftInfo: some View {
    HStack(spacing: 20) {
      levelInfo
      streakIndicator
    }
  }

  // MARK: - Level Information

  private var levelInfo: some View {
    Group {
      if let level = level {
        VStack(alignment: .leading, spacing: 4) {
          difficultyStars(for: level.difficulty)
          bestTimeLabel
        }
      } else {
        VStack(alignment: .leading, spacing: 4) {
          difficultyStars(for: 1)
          noLevelLabel
        }
      }
    }
  }

  private func difficultyStars(for difficulty: Int) -> some View {
    DifficultyStars(difficulty: difficulty, size: 10, spacing: 1)
  }

  private var bestTimeLabel: some View {
    Group {
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
  }

  private var noLevelLabel: some View {
    Text("No level available")
      .font(.caption2)
      .foregroundStyle(.secondary)
  }

  // MARK: - Streak Indicator

  private var streakIndicator: some View {
    Group {
      if let progress = progress, progress.currentStreak > 0 {
        VStack(alignment: .leading, spacing: 2) {
          streakCount
          streakLabel
        }
      }
    }
  }

  private var streakCount: some View {
    HStack(spacing: 2) {
      Image(systemName: "flame.fill")
        .font(.system(size: 10))
      Text("\(progress?.currentStreak ?? 0)")
        .font(.caption)
        .fontWeight(.medium)
    }
    .foregroundStyle(.primary)
  }

  private var streakLabel: some View {
    Text("streak")
      .font(.caption2)
      .foregroundStyle(.secondary)
  }

  // MARK: - Right Section

  private var rightSection: some View {
    ZStack {
      actionButton
    }
    .frame(width: 80, height: 76)
  }

  private var gameIcon: some View {
    Image(systemName: gameType.icon)
      .font(.system(size: 50))
      .foregroundStyle(gameType.color.opacity(0.3))
  }

  // MARK: - Action Button

  private var actionButton: some View {
    Group {
      if isCompleted {
        completedButton
      } else {
        playButton
      }
    }
  }

  private var completedButton: some View {
    Image(systemName: "checkmark")
      .font(.system(size: 28))
      .foregroundStyle(gameType.color)
//      .background(
//        Circle()
//          .fill(gameType.color.opacity(0.5))
//          .frame(width: 50, height: 50)
//          .overlay(content: {
//            Circle()
//              .stroke(lineWidth: 1)
//              .foregroundStyle(gameType.color)
//          })
//      )
  }

  private var playButton: some View {
    Button(action: onTap) {
      Image(systemName: "play.fill")
        .font(.system(size: 16))
        .foregroundStyle(Color.primary)
        .frame(width: 50, height: 50)
        .background(
          Circle()
            .fill(gameType.color.opacity(0.5))
            .overlay(content: {
              Circle()
                .stroke(lineWidth: 1)
                .foregroundStyle(gameType.color)
            })
        )
    }
    .sensoryFeedback(.impact(weight: .medium), trigger: false)
  }

  // MARK: - Helper Functions

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

// MARK: - Previews

#Preview("GameDayCard - All Game Types") {
  LazyVStack(spacing: 12) {
    ForEach(GameType.allCases, id: \.self) { gameType in
      let mockLevel = createMockLevel(for: gameType)
      let mockProgress = createMockProgress(for: gameType)

      GameDayCard(
        gameType: gameType,
        date: Date(),
        level: mockLevel,
        isCompleted: Bool.random(),
        progress: mockProgress,
        canPlay: true,
        onTap: {
          print("\(gameType.displayName) tapped")
        }
      )
    }
  }
  .padding()
}

#Preview("GameDayCard - Future Date (Unavailable)") {
  VStack(spacing: 16) {
    GameDayCard(
      gameType: .wordle,
      date: Date().addingTimeInterval(86400), // Tomorrow
      level: createMockLevel(for: .wordle),
      isCompleted: false,
      progress: createMockProgress(for: .wordle),
      canPlay: false,
      onTap: {
        print("Future game tapped")
      }
    )
  }
  .padding()
}

// MARK: - Mock Data Helpers

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
