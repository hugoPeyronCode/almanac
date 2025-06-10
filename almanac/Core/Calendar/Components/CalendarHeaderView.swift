//
//  CalendarHeaderView.swift
//  almanac
//
//  Created by Hugo Peyron on 09/06/2025.
//

import SwiftUI

struct CalendarHeaderView: View {
  @Bindable var viewModel: CalendarViewModel
  let coordinator: GameCoordinator

  var body: some View {
    HStack {
      Text("THE ALMANAC")
        .monospaced()
        .font(.title)
        .fontWeight(.black)

      Spacer()

      HStack(spacing: 16) {
        Button {
          coordinator.showProfile()
        } label: {
          Image(systemName: "person.circle.fill")
            .font(.title2)
            .foregroundStyle(Color.secondary)
        }

        Button {
          viewModel.showingPipeLevelEditor = true
        } label: {
          Image(systemName: "wrench.and.screwdriver")
            .font(.title2)
            .foregroundStyle(Color.secondary)
        }

        Button {
          viewModel.toggleFilters()
        } label: {
          Image(systemName: viewModel.showingFilters ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            .font(.title2)
            .foregroundStyle(Color.secondary)
        }
      }
    }
    .padding(.horizontal)
    .padding(.top, 8)
  }
}


#Preview {
  CalendarHeaderView(viewModel: CalendarViewModel(), coordinator:  GameCoordinator())
}
