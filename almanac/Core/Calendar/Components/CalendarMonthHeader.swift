//
//  CalendarMonthHeader.swift
//  almanac
//
//  Month navigation header with week progress
//

import SwiftUI

struct CalendarMonthHeader: View {
    @Bindable var viewModel: CalendarViewModel
    let weekProgress: WeekProgress?

    var body: some View {
        HStack(spacing: 16) {
            // Month, Year and Week with Progress
            HStack(spacing: 12) {
                Text(viewModel.monthTitle)
                    .font(.headline)
                    .fontWeight(.medium)
                    .contentTransition(.numericText())

                Divider()
                    .frame(height: 16)
                    .opacity(0.3)

                // Week Progress Bar
                if let progress = weekProgress {
                    WeekProgressBar(
                        weekLabel: viewModel.weekOfMonth,
                        progress: progress
                    )
                }
            }

            Spacer()

            // Focus button with animated color
            Button {
                viewModel.focusOnToday()
            } label: {
                Image(systemName: "location")
                    .font(.title3)
                    .foregroundStyle(viewModel.isTodayVisible ? Color.primary : Color.gray)
                    .contentTransition(.symbolEffect)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isTodayVisible)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.isTodayVisible)

            // Calendar button
            Button {
                viewModel.showingFullCalendar = true
            } label: {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.showingFullCalendar)
        }
        .padding(.horizontal)
    }
}

struct WeekProgressBar: View {
    let weekLabel: String
    let progress: WeekProgress

    var body: some View {
        HStack(spacing: 8) {
            // Week label
            Text(weekLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 50)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: progress.percentage == 1.0
                                    ? [Color.green, Color.green.opacity(0.8)]
                                    : [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress.percentage)
                        .animation(.spring(duration: 0.5), value: progress.percentage)
                }
            }
            .frame(width: 60, height: 6)

            // Percentage text
            Text("\(Int(progress.percentage * 100))%")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(progress.percentage == 1.0 ? .green : .secondary)
                .monospacedDigit()
        }
        .opacity(progress.totalGames > 0 ? 1 : 0.5)
    }
}

#Preview {
    CalendarMonthHeader(
        viewModel: CalendarViewModel(),
        weekProgress: WeekProgress(completed: 3, total: 7, percentage: 0.43, totalGames: 4)
    )
}
