//
//  CalendarDateHeader.swift
//  almanac
//
//  Selected date header with progress
//

import SwiftUI

struct CalendarDateHeader: View {
  @Bindable var viewModel: CalendarViewModel
  let dayProgress: DayProgress?
  let completedCount: Int

  private let calendar = Calendar.current

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text(viewModel.selectedDateTitle)
            .font(.title2)
            .fontWeight(.medium)

          if calendar.isDateInToday(viewModel.selectedDate) {
            Image(systemName: "sun.max.fill")
              .font(.caption)
              .foregroundStyle(.orange)
          }
        }
      }
      .contentTransition(.numericText())

      Spacer()

      // Day progress bar
      if let progress = dayProgress {
        DayProgressBar(progress: progress)
      }
    }
  }
}

struct DayProgressBar: View {
  let progress: DayProgress

  var body: some View {
    HStack(spacing: 6) {
      // Progress bar
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          // Background
          RoundedRectangle(cornerRadius: 3)
            .fill(Color.gray.opacity(0.15))

          // Progress
          RoundedRectangle(cornerRadius: 3)
            .fill(
              Color.primary
            )
            .frame(width: geometry.size.width * progress.percentage)
            .animation(.spring(duration: 0.3), value: progress.percentage)
        }
      }
      .frame(width: 50, height: 4)

      // Fraction text
      Text("\(progress.completed)/\(progress.total)")
        .font(.caption2)
        .fontWeight(.medium)
        .foregroundStyle(.primary)
        .contentTransition(.numericText())
        .monospacedDigit()
    }
    .opacity(progress.total > 0 ? 1 : 0)
  }
}

struct CompletionBadge: View {
  let completedCount: Int
  let totalGames: Int

  var body: some View {
    HStack(spacing: 6) {
      if completedCount == totalGames {
        Image(systemName: "crown.fill")
          .font(.caption)
          .foregroundStyle(.yellow)
        Text("Perfect Day!")
          .font(.caption)
          .fontWeight(.medium)
          .foregroundStyle(.yellow)
      } else {
        Image(systemName: "checkmark.circle.fill")
          .font(.caption)
          .foregroundStyle(.green)

        Text("\(completedCount)/\(totalGames) completed")
          .font(.caption)
          .fontWeight(.medium)
          .foregroundStyle(.green)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(
      Capsule()
        .fill(completedCount == totalGames ? .yellow.opacity(0.1) : .green.opacity(0.1))
        .overlay(
          Capsule()
            .stroke(completedCount == totalGames ? .yellow.opacity(0.3) : .green.opacity(0.3), lineWidth: 1)
        )
    )
  }
}
