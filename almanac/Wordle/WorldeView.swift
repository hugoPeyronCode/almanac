//
//  WorldeView.swift
//  almanac
//
//  Created by Hugo Peyron on 04/06/2025.
//

import SwiftUI

@Observable
class WordleGameViewModel {
    private(set) var session: GameSession

    init(session: GameSession) {
        self.session = session
    }

    func submitGuess(_ guess: String) {
        guard DictionaryManager.shared.isValid(word: guess) else { return }
        game.submitGuess(guess)
    }

    func deleteLastLetter() {
        game.deleteLastLetter()
    }

    func addLetter(_ letter: Character) {
        game.addLetter(letter)
    }

    var isComplete: Bool { game.isGameOver || game.isGameWon }
    var guesses: [String] { game.guesses }
    var currentAttempt: String { game.currentAttempt }
}


@Observable
class WordleGame {
    let targetWord: String
    let maxAttempts: Int
    var guesses: [String] = []
    var currentAttempt: String = ""

    var isGameOver: Bool { guesses.count >= maxAttempts }
    var isGameWon: Bool { guesses.contains(targetWord) }

    init(targetWord: String, maxAttempts: Int) {
        self.targetWord = targetWord.uppercased()
        self.maxAttempts = maxAttempts
    }

    func submitGuess(_ guess: String) {
        guard !isGameOver, guess.count == targetWord.count else { return }
        guesses.append(guess.uppercased())
        currentAttempt = ""
    }

    func addLetter(_ letter: Character) {
        guard currentAttempt.count < targetWord.count else { return }
        currentAttempt.append(letter.uppercased())
    }

    func deleteLastLetter() {
        guard !currentAttempt.isEmpty else { return }
        currentAttempt.removeLast()
    }
}


class DictionaryManager {
    static let shared = DictionaryManager()
    private var words: Set<String> = []

    init() {
        if let path = Bundle.main.path(forResource: "english_words", ofType: "txt"),
           let content = try? String(contentsOfFile: path) {
            words = Set(content.components(separatedBy: .newlines).map { $0.uppercased() })
        }
    }

    func isValid(word: String) -> Bool {
        words.contains(word.uppercased())
    }
}
