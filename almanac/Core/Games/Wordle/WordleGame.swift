//
//  WordleGame.swift
//  almanac
//
//  Wordle game logic and state management
//

import SwiftUI
import Foundation

// MARK: - Game Logic

@Observable
class WordleGame {
  let targetWord: String
  let maxAttempts: Int
  var guesses: [String] = []
  var currentAttempt: String = ""

  var isGameOver: Bool { guesses.count >= maxAttempts && !isGameWon }
  var isGameWon: Bool { guesses.contains(targetWord) }
  var isGameComplete: Bool { isGameWon || isGameOver }

  init(targetWord: String, maxAttempts: Int) {
    self.targetWord = targetWord.uppercased()
    self.maxAttempts = maxAttempts
  }

  func submitGuess(_ guess: String) {
    guard !isGameComplete, guess.count == targetWord.count else { return }
    guesses.append(guess.uppercased())
    currentAttempt = ""
  }

  func addLetter(_ letter: Character) {
    guard currentAttempt.count < targetWord.count, !isGameComplete else { return }
    currentAttempt.append(letter.uppercased())
  }

  func deleteLastLetter() {
    guard !currentAttempt.isEmpty, !isGameComplete else { return }
    currentAttempt.removeLast()
  }
}



