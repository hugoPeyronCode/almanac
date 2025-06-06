//
//  GameHeaderView.swift
//  almanac
//
//  Created by Hugo Peyron on 29/05/2025.
//

import SwiftUI

@Observable
class GameTimer {
  var displayTime: TimeInterval = 0
  var isPaused: Bool = false
  private var timer: Timer?

  func startTimer() {
    stopTimer() // Éviter les doublons
    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
      if !self.isPaused {
        self.displayTime += 0.1
      }
    }
  }

  func stopTimer() {
    timer?.invalidate()
    timer = nil
  }

  func pause() {
    isPaused = true
  }

  func resume() {
    isPaused = false
  }

  func reset() {
    displayTime = 0
    isPaused = false
  }
}

struct GameHeaderView: View {
  let session: GameSession
  let showExitConfirmation: Binding<Bool>
  let gameTimer: GameTimer
  let onExit: () -> Void

  init(
    session: GameSession,
    showExitConfirmation: Binding<Bool>,
    gameTimer: GameTimer,
    onExit: @escaping () -> Void
  ) {
    self.session = session
    self.showExitConfirmation = showExitConfirmation
    self.gameTimer = gameTimer
    self.onExit = onExit
  }

  var body: some View {
    HStack {
      // Exit Button
      Button {
        showExitConfirmation.wrappedValue = true
      } label: {
        Image(systemName: "xmark")
          .font(.title2)
          .foregroundStyle(Color.primary)
          .frame(width: 44, height: 44)
          .background(.ultraThinMaterial, in: Circle())
      }
      .sensoryFeedback(.impact(weight: .light), trigger: showExitConfirmation.wrappedValue)

      Spacer()

      // Center Info
      VStack(spacing: 4) {
        Text(session.gameType.displayName)
          .font(.headline)
          .fontWeight(.medium)

        if let date = session.context.date?.formatted(date: .abbreviated, time: .omitted){
          Text(date)
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text("•")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 2) {
        Text(Duration.seconds(gameTimer.displayTime), format: .time(pattern: .minuteSecond))
          .contentTransition(.numericText())
          .font(.headline)
          .fontWeight(.medium)
          .foregroundStyle(gameTimer.isPaused ? .secondary : .primary)
      }
    }
    .confirmationDialog("Exit Game", isPresented: showExitConfirmation) {
      Button("Exit", role: .destructive) {
        onExit()
      }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("Are you sure you want to exit? Progress will be lost.")
    }
  }
}
