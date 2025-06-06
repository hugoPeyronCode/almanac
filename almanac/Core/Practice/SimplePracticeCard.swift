//
//  SimplePracticeCard.swift
//  almanac
//
//  Created by Hugo Peyron on 06/06/2025.
//


import SwiftUI
import SwiftData

struct SimplePracticeCard: View {
  let gameType: GameType
  let progress: PracticeProgress?
  let todayCount: Int
  let totalLevels: Int
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 16) {
        HStack {
          Image(systemName: gameType.icon)
            .font(.title)
            .foregroundStyle(gameType.color)

          Text(gameType.displayName)
            .font(.title2)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)

          Spacer()

          if todayCount > 0 {
            VStack(alignment: .trailing, spacing: 2) {
              Text("\(todayCount)")
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()

              Text("today")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
        }

        // Play button
        HStack {
          Image(systemName: "play.fill")
            .font(.caption)
          Text("Practice")
            .font(.subheadline)
            .fontWeight(.medium)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(gameType.color, in: RoundedRectangle(cornerRadius: 10))
      }
      .padding()
      .frame(maxWidth: .infinity)
      .frame(height: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(.ultraThinMaterial)
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(gameType.color.opacity(0.3), lineWidth: 1)
          )
      )
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.impact(weight: .medium), trigger: false)
  }
}
