//
//  CalendarMonthHeader.swift
//  almanac
//
//  Month navigation header with week progress
//

import SwiftUI

struct CalendarMonthHeader: View {
  @Bindable var viewModel: CalendarViewModel

  var body: some View {
    HStack(spacing: 16) {
      Text(viewModel.monthTitle)
        .font(.headline)
        .fontWeight(.medium)
        .contentTransition(.numericText())

      Spacer()

      Button {
        viewModel.focusOnToday()
      } label: {
        Image(systemName: "location")
          .font(.title3)
          .foregroundStyle(!viewModel.isTodayVisible ? Color.primary : Color.gray)
          .contentTransition(.symbolEffect)
          .animation(.easeInOut(duration: 0.3), value: viewModel.isTodayVisible)
      }
      .sensoryFeedback(.impact(weight: .light), trigger: viewModel.isTodayVisible)

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

#Preview {
  CalendarMonthHeader(
    viewModel: CalendarViewModel()
  )
}
