//
//  StatCard.swift
//  almanac
//
//  Created by Hugo Peyron on 09/06/2025.
//


import SwiftUI

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
