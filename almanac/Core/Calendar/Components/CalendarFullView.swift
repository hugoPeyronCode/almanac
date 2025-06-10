//
//  CalendarFullView.swift
//  almanac
//
//  Created by Hugo Peyron on 09/06/2025.
//

import SwiftUI
import SwiftData

struct CalendarFullView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @Query private var allCompletions: [DailyCompletion]
    
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    let selectedGames: Set<GameType>
    let onDateSelected: (Date) -> Void
    
    @State private var displayMonth: Date
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    
    init(selectedDate: Binding<Date>, currentMonth: Binding<Date>, selectedGames: Set<GameType>, onDateSelected: @escaping (Date) -> Void) {
        self._selectedDate = selectedDate
        self._currentMonth = currentMonth
        self.selectedGames = selectedGames
        self.onDateSelected = onDateSelected
        self._displayMonth = State(initialValue: currentMonth.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                monthNavigationHeader
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                
                weekdayHeader
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(generateCalendarDays(), id: \.date) { day in
                            CalendarDayView(
                                day: day,
                                isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                                completionStatus: getFilteredDayCompletionStatus(day.date),
                                selectedGamesColors: selectedGames.colors,
                                isCompact: false,
                                canPlay: canPlayGame(for: day.date)
                            ) {
                                selectDate(day.date)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background {
                Image(.dotsBackground)
                    .resizable()
                    .scaledToFill()
                    .overlay {
                        Rectangle()
                            .foregroundStyle(.ultraThinMaterial)
                            .ignoresSafeArea()
                    }
            }
            .navigationTitle("Calendrier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var monthNavigationHeader: some View {
        HStack {
            Button {
                navigateMonth(direction: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
            }
            
            Spacer()
            
            Text(monthTitle)
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button {
                focusOnToday()
            } label: {
                Image(systemName: "location")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
            }
            
            Button {
                navigateMonth(direction: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
            }
        }
    }
    
    private var weekdayHeader: some View {
        HStack(spacing: 8) {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func generateCalendarDays() -> [CalendarDay] {
        let startOfMonth = calendar.dateInterval(of: .month, for: displayMonth)?.start ?? displayMonth
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayMonth)?.count ?? 30
        
        var days: [CalendarDay] = []
        
        // Add empty days for the start of the week
        for i in 1..<firstWeekday {
            let emptyDate = calendar.date(byAdding: .day, value: -i, to: startOfMonth) ?? Date.distantPast
            days.append(CalendarDay(date: emptyDate, dayNumber: 0, isCurrentMonth: false))
        }
        
        // Add days of the month
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(CalendarDay(date: date, dayNumber: day, isCurrentMonth: true))
            }
        }
        
        return days
    }
    
    private func navigateMonth(direction: Int) {
        withAnimation(.spring(duration: 0.3)) {
            displayMonth = calendar.date(byAdding: .month, value: direction, to: displayMonth) ?? displayMonth
        }
    }
    
    private func selectDate(_ date: Date) {
        withAnimation(.spring(duration: 0.2)) {
            selectedDate = date
            currentMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        }
        onDateSelected(date)
    }
    
    private func focusOnToday() {
        let today = Date()
        withAnimation(.easeInOut(duration: 0.3)) {
            displayMonth = today
        }
    }
    
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayMonth)
    }
    
    private func canPlayGame(for date: Date) -> Bool {
        let today = calendar.startOfDay(for: Date())
        let selectedDay = calendar.startOfDay(for: date)
        
        // Can play today and past dates, but not future dates
        return selectedDay <= today
    }
    
    private func getFilteredDayCompletionStatus(_ date: Date) -> DayCompletionStatus {
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