//
//  WordleStateManager.swift
//  almanac
//
//  State persistence for Wordle game
//

import SwiftUI
import SwiftData

class WordleStateManager: GameStateManager<WordleGameState> {

    func saveState(for session: GameSession, game: WordleGame) {
        let stateId = generateStateId(for: session)

        let descriptor = FetchDescriptor<WordleGameState>(
            predicate: #Predicate { state in
                state.sessionId == stateId
            }
        )

        let state: WordleGameState
        if let existingState = try? modelContext.fetch(descriptor).first {
            state = existingState
        } else {
            state = WordleGameState(
                sessionId: stateId,
                gameType: session.gameType,
                dateString: session.context.date?.ISO8601Format() ?? "",
                targetWord: game.targetWord
            )
            modelContext.insert(state)
        }

        // Update state
        state.setGuesses(game.guesses)
        state.currentAttempt = game.currentAttempt
        state.isCompleted = game.isGameComplete
        state.isWon = game.isGameWon
        state.lastUpdated = Date()

        try? modelContext.save()
    }

    func loadState(for session: GameSession, into game: WordleGame) -> Bool {
        let stateId = generateStateId(for: session)

        let descriptor = FetchDescriptor<WordleGameState>(
            predicate: #Predicate { state in
                state.sessionId == stateId
            }
        )

        guard let state = try? modelContext.fetch(descriptor).first else {
            return false
        }

        // Restore game state
        game.guesses = state.getGuesses()
        game.currentAttempt = state.currentAttempt

        return true
    }

    func clearState(for session: GameSession) {
        let stateId = generateStateId(for: session)

        let descriptor = FetchDescriptor<WordleGameState>(
            predicate: #Predicate { state in
                state.sessionId == stateId
            }
        )

        if let state = try? modelContext.fetch(descriptor).first {
            modelContext.delete(state)
            try? modelContext.save()
        }
    }

    func getDailyWord(for date: Date) -> String? {
        let stateId = generateDailyStateId(for: date)

        let descriptor = FetchDescriptor<WordleGameState>(
            predicate: #Predicate { state in
                state.sessionId == stateId
            }
        )

        return try? modelContext.fetch(descriptor).first?.targetWord
    }

    private func generateDailyStateId(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "wordle_daily_\(formatter.string(from: date))"
    }
}

// Extension to make WordleGame support state restoration
extension WordleGame {
    func restoreState(guesses: [String], currentAttempt: String) {
        self.guesses = guesses
        self.currentAttempt = currentAttempt
    }
}
