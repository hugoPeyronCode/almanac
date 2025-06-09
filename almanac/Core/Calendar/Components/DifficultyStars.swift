//
//  DifficultyStars.swift
//  almanac
//
//  Created by Hugo Peyron on 09/06/2025.
//


import SwiftUI

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