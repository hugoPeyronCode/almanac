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
          !canPlay ? .orange.opacity(0.5) : isCompleted ? .gray.opacity(0.3) : gameType.color,
          lineWidth: !canPlay ? 1 : isCompleted ? 0.5 : 1
        )
    )
    .opacity(canPlay ? 1.0 : 0.6)
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

        if !canPlay {
          VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 2) {
              Image(systemName: "clock.badge.xmark")
                .font(.caption)
                .foregroundStyle(.orange)
            }
            Text("Non disponible")
              .font(.caption2)
              .foregroundStyle(.orange)
          }
        } else if let progress = progress, progress.currentStreak > 0 {
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

    GameDayCard(
      gameType: .shikaku,
      date: Date(),
      level: createMockLevel(for: .shikaku),
      isCompleted: true,
      progress: createMockProgress(for: .shikaku),
      canPlay: true,
      onTap: {
        print("Today game tapped")
      }
    )
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
