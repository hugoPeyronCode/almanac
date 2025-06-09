//
//  GameFilterChip.swift
//  almanac
//
//  Created by Hugo Peyron on 09/06/2025.
//


import SwiftUI
import SwiftData

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
            .font(.subheadline)
            .foregroundStyle(gameType.color)

          Text(gameType.displayName)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
        }
      }
      .padding(.horizontal, 10)
      .frame(height: 25)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(gameType.color.opacity(0.1))
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(
                isSelected ? gameType.color : gameType.color.opacity(0.3),
                lineWidth: isSelected ? 1 : 0.5
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
