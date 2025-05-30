//
//  GameCompletionView.swift
//  almanac
//
//  Created by Hugo Peyron on 30/05/2025.
//

import SwiftUI

struct GameCompletionView: View {

  let formattedDuration: String
  let coordinator: GameCoordinator
  let session: GameSession

  var body: some View {
    VStack(spacing: 20) {

      Spacer()

      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 48))
        .foregroundStyle(Color.primary)
        .padding(.top)

      Text("Solved in \(formattedDuration)")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding()

      Spacer()

      HStack {
        Button {
          coordinator.dismissFullScreen()
        } label: {
          Image(systemName: "house.fill")
          Text("Home")
            .font(.caption)
        }
        .fontWeight(.semibold)
        .foregroundStyle(Color.primary)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.primary, in: RoundedRectangle(cornerRadius: 12).stroke(lineWidth: 1))

        Button {
          // play again
        } label: {
          Image(systemName: "arrow.trianglehead.counterclockwise")
          Text("replay")
            .font(.caption)
        }
        .fontWeight(.semibold)
        .foregroundStyle(Color.primary)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.primary, in: RoundedRectangle(cornerRadius: 12).stroke(lineWidth: 1))

        Button {
          // Play next game logic. In practice mode would be to select a random level according to the selection done int he practice mode.
          // In the daily game it would open the calendar view as a modal
        } label: {
          Image(systemName: "chevron.forward.dotted.chevron.forward")
          Text("play next")
            .font(.caption)
        }
        .fontWeight(.semibold)
        .foregroundStyle(Color.primary)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.primary, in: RoundedRectangle(cornerRadius: 12).stroke(lineWidth: 1))
      }
      .padding(.horizontal)

      Spacer()
    }
    .sensoryFeedback(.success, trigger: session.game.isGameComplete)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    .transition(.opacity)
  }

}

