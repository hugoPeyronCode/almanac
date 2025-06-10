//
//  CalendarHorizontalView.swift
//  almanac
//
//  Created by Hugo Peyron on 09/06/2025.
//

import SwiftUI
import SwiftData

struct CalendarHorizontalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme

    @Query private var allCompletions: [DailyCompletion]

    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    let selectedGames: Set<GameType>
    let onDateSelected: (Date) -> Void

    @State private var weeks: [Week] = []
    @State private var currentWeekIndex: Int = 0

    private let calendar = Calendar.current
    private let weeksToLoad = 52 // Load a full year of weeks

    struct Week: Identifiable {
        let id = UUID()
        let days: [CalendarDay]
        let startDate: Date

        var month: Date {
            // Return the month that contains the most days of this week
            var monthCounts: [Date: Int] = [:]

            for day in days {
                let monthStart = Calendar.current.dateInterval(of: .month, for: day.date)?.start ?? day.date
                monthCounts[monthStart, default: 0] += 1
            }

            // Return the month with the most days in this week
            return monthCounts.max(by: { $0.value < $1.value })?.key ?? startDate
        }
    }

    var body: some View {
        TabView(selection: $currentWeekIndex) {
            ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                WeekView(
                    week: week,
                    selectedDate: selectedDate,
                    selectedGames: selectedGames,
                    allCompletions: allCompletions,
                    onDateSelected: { date in
                        selectDate(date)
                    }
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 80)
        .onAppear {
            setupWeeks()
            scrollToToday()
        }
        .onChange(of: currentWeekIndex) { _, newIndex in
            updateMonthForWeek(at: newIndex)
        }
        .onChange(of: selectedDate) { _, newDate in
            // If selected date changes externally, scroll to it
            if let weekIndex = findWeekIndex(for: newDate) {
                if weekIndex != currentWeekIndex {
                    currentWeekIndex = weekIndex
                }
            }
        }
        // Remove the onChange for currentMonth - we don't want to jump weeks
    }

    // MARK: - Week View

    struct WeekView: View {
        let week: Week
        let selectedDate: Date
        let selectedGames: Set<GameType>
        let allCompletions: [DailyCompletion]
        let onDateSelected: (Date) -> Void

        private let calendar = Calendar.current

        var body: some View {
            HStack(spacing: 12) {
                ForEach(week.days, id: \.date) { day in
                    CalendarDayView(
                        day: day,
                        isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                        completionStatus: getCompletionStatus(for: day.date),
                        selectedGamesColors: selectedGames.colors,
                        isCompact: true,
                        canPlay: canPlayGame(for: day.date)
                    ) {
                        onDateSelected(day.date)
                    }
                }
            }
            .padding(.horizontal)
        }

        private func canPlayGame(for date: Date) -> Bool {
            let today = calendar.startOfDay(for: Date())
            let selectedDay = calendar.startOfDay(for: date)
            return selectedDay <= today
        }

        private func getCompletionStatus(for date: Date) -> DayCompletionStatus {
            let completedGames = selectedGames.filter { gameType in
                isGameCompletedForDate(date, gameType: gameType)
            }

            if completedGames.count == selectedGames.count && !selectedGames.isEmpty {
                return .allCompleted
            } else if !completedGames.isEmpty {
                return .partiallyCompleted(completedGames.count, selectedGames.count)
            } else {
                return .none
            }
        }

        private func isGameCompletedForDate(_ date: Date, gameType: GameType) -> Bool {
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            return allCompletions.contains { completion in
                completion.gameType == gameType &&
                completion.date >= startOfDay &&
                completion.date < endOfDay
            }
        }
    }

    // MARK: - Setup

    private func setupWeeks() {
        var allWeeks: [Week] = []
        let today = Date()

        // Start from X weeks ago
        let weeksBack = weeksToLoad / 2
        guard let startDate = calendar.date(byAdding: .weekOfYear, value: -weeksBack, to: today) else { return }

        // Generate weeks
        for weekOffset in 0..<weeksToLoad {
            if let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startDate) {
                let week = generateWeek(startingFrom: weekStart)
                allWeeks.append(week)
            }
        }

        weeks = allWeeks
    }

    private func generateWeek(startingFrom date: Date) -> Week {
        var days: [CalendarDay] = []

        // Get the start of the week (Sunday or Monday depending on locale)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date

        // Generate 7 days
        for dayOffset in 0..<7 {
            if let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) {
                let dayNumber = calendar.component(.day, from: dayDate)
                let day = CalendarDay(date: dayDate, dayNumber: dayNumber, isCurrentMonth: true)
                days.append(day)
            }
        }

        return Week(days: days, startDate: startOfWeek)
    }

    // MARK: - Navigation

    private func scrollToToday() {
        let today = Date()
        if let weekIndex = findWeekIndex(for: today) {
            currentWeekIndex = weekIndex
            updateMonthForWeek(at: weekIndex)
        }
    }

    private func findWeekIndex(for date: Date) -> Int? {
        weeks.firstIndex { week in
            week.days.contains { calendar.isDate($0.date, inSameDayAs: date) }
        }
    }

    private func findBestWeekIndex(for month: Date) -> Int? {
        // Find the week that best represents this month
        // (i.e., the week with the most days in this month)
        var bestWeekIndex: Int?
        var maxDaysInMonth = 0

        for (index, week) in weeks.enumerated() {
            let daysInTargetMonth = week.days.filter { day in
                calendar.isDate(day.date, equalTo: month, toGranularity: .month)
            }.count

            if daysInTargetMonth > maxDaysInMonth {
                maxDaysInMonth = daysInTargetMonth
                bestWeekIndex = index
            }
        }

        return bestWeekIndex
    }

    private func updateMonthForWeek(at index: Int) {
        guard index >= 0 && index < weeks.count else { return }

        let week = weeks[index]
        let newMonth = week.month

        if !calendar.isDate(newMonth, equalTo: currentMonth, toGranularity: .month) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentMonth = newMonth
            }
        }
    }

    private func selectDate(_ date: Date) {
        withAnimation(.spring(duration: 0.2)) {
            selectedDate = date
        }
        onDateSelected(date)
    }
}


extension Set where Element == GameType {
    /// Returns an array of colors for the selected games
    var colors: [Color] {
        return self.sorted(by: { $0.rawValue < $1.rawValue }).map { $0.color }
    }
}
