//
//  TabBar.swift
//  almanac
//
//  Created by Hugo Peyron on 30/05/2025.
//

import SwiftUI

struct TabBar: View {

  let leftButtonAction: () -> Void
  let middleButtonAction : () -> Void
  let rightButtonAction :() -> Void
//  let selectedGameColor: Color

  @State private var triggerHaptics: Bool = false

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 25)
        .foregroundStyle(.ultraThinMaterial)
        .overlay {
          RoundedRectangle(cornerRadius: 25)
            .stroke(lineWidth: 1)
            .foregroundStyle(.secondary)
        }

      HStack{
        Button {
          leftButtonAction()
          triggerHaptics.toggle()
        } label: {
          Image(systemName: "chart.xyaxis.line")
            .foregroundStyle(Color.primary)
        }

        Spacer()

        Button {
          rightButtonAction()
          triggerHaptics.toggle()
        } label: {
          Image(systemName: "dumbbell")
            .foregroundStyle(Color.primary)
        }
      }
      .padding(.horizontal)

      Button {
        middleButtonAction()
      } label: {
        Circle()
          .foregroundStyle(.thinMaterial)
          .overlay {
            Circle()
              .stroke(lineWidth: 1)
              .foregroundStyle(.mint)
          }
          .overlay(content: {
            Image(systemName: "play.fill")
              .foregroundStyle(.mint)
          })
          .scaleEffect(1.2)
      }
    }
    .sensoryFeedback(.impact(flexibility: .soft), trigger: triggerHaptics)
    .frame(width: 200, height: 60)

  }
}

#Preview {
  TabBar {
    //
  } middleButtonAction: {
    //
  } rightButtonAction: {
    //
  }

}
