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
    let gameTimer: GameTimer // 🔥 NOUVEAU : Utiliser le timer observable
    let subtitle: String?
    let onExit: () -> Void

    init(
        session: GameSession,
        showExitConfirmation: Binding<Bool>,
        gameTimer: GameTimer,
        subtitle: String? = nil,
        onExit: @escaping () -> Void
    ) {
        self.session = session
        self.showExitConfirmation = showExitConfirmation
        self.gameTimer = gameTimer
        self.subtitle = subtitle
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
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showExitConfirmation.wrappedValue)

            Spacer()

            // Center Info
            VStack(spacing: 4) {
                Text(contextTitle)
                    .font(.headline)
                    .fontWeight(.medium)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 8) {
                        Text(session.gameType.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Level \(session.level.difficulty)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Timer Display - 🔥 MAINTENANT RÉACTIF
            VStack(alignment: .trailing, spacing: 2) {
                Text(Duration.seconds(gameTimer.displayTime), format: .time(pattern: .minuteSecond))
                    .font(.headline)
                    .fontWeight(.medium)
                    .contentTransition(.numericText())
                    .monospacedDigit()
                    .foregroundStyle(gameTimer.isPaused ? .secondary : .primary)

                Text(formatEstimatedTime(session.level.estimatedTime))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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

    // MARK: - Private Helpers

    private var contextTitle: String {
        switch session.context {
        case .daily: return "Daily Puzzle"
        case .practice: return "Practice"
        case .random: return "Custom Level"
        }
    }

    private func formatEstimatedTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60

        if minutes > 0 {
            return "~\(minutes)m \(remainingSeconds)s"
        } else {
            return "~\(remainingSeconds)s"
        }
    }
}
