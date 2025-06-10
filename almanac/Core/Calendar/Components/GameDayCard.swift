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
  let completionTime: TimeInterval? // New parameter for daily completion time
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
      completionTimeLabel
      streakIndicator
      Spacer()
    }
  }

  private var gameTitle: some View {
    Text(gameType.displayName)
      .font(.headline)
      .fontWeight(.medium)
      .foregroundStyle(.primary)
  }

  private var completionTimeLabel: some View {
    Group {
      if let time = completionTime {
        // Show completion time for this specific day
        Text("\(formatTime(time))")
          .contentTransition(.numericText())
          .font(.caption2)
          .foregroundStyle(.secondary)
      } else if isCompleted {
        // Completed but no time data (shouldn't happen in normal flow)
        Text("Completed")
          .font(.caption2)
          .foregroundStyle(.secondary)
      } else {
        // Not completed yet
        Text("Not completed")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
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

    return String(format: "%02d:%02d", minutes, remainingSeconds)
  }
}
