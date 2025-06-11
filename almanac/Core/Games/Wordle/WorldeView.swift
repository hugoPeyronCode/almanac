//
//  WorldeView.swift
//  almanac
//
//  Created by Hugo Peyron on 04/06/2025.
//

import SwiftUI

struct WordleGameView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(GameCoordinator.self) private var coordinator

  @State private var session: GameSession
  @State private var showExitConfirmation = false
  @State private var gameTimer = GameTimer()
  @State private var showInvalidWordAlert = false

  init(session: GameSession) {
    self._session = State(initialValue: session)
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        backgroundGradient

        VStack(spacing: 20) {
          GameHeaderView(
            session: session,
            showExitConfirmation: $showExitConfirmation,
            gameTimer: gameTimer
          ) {
            gameTimer.stopTimer()
            coordinator.dismissFullScreen()
          }

          Spacer()

          gameContent(in: geometry)

          keyboardView
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
        .padding(.top, 8)

        if session.wordleGame.isGameComplete {
          GameCompletionView(
            isGameLost: !session.wordleGame.isGameWon,
            potentialRightAnswer: session.wordleGame.targetWord,
            formattedDuration: session.formattedPlayTime,
            coordinator: coordinator,
            session: session
          )
          .ignoresSafeArea()
        }

        VStack {
          Text(session.wordleGame.targetWord)
          DebugCompleteButton(session: session, label: "Force Win")
            .disabled(session.isCompleted)
            .padding(.bottom, 8)
          Spacer()
        }
      }
    }
    .navigationBarHidden(true)
    .onChange(of: session.wordleGame.isGameComplete) { _, isComplete in
      if isComplete && !session.isCompleted {
        handleGameCompletion()
      }
    }
    .onAppear {
      gameTimer.displayTime = session.actualPlayTime
      gameTimer.startTimer()
    }
    .onDisappear {
      gameTimer.stopTimer()

      if !session.wordleGame.isGameComplete {
        session.pause()
        gameTimer.pause()
      }

      session.cleanupWordleGameInstance()
    }
    .confirmationDialog("Exit Game", isPresented: $showExitConfirmation) {
      Button("Exit", role: .destructive) {
        coordinator.dismissFullScreen()
      }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("Are you sure you want to exit? Progress will be lost.")
    }
    .alert("Invalid Word", isPresented: $showInvalidWordAlert) {
      Button("OK", role: .cancel) { }
    } message: {
      Text("'\(session.wordleGame.currentAttempt)' is not in the word list")
    }
  }

  // MARK: - Game Content

  private func gameContent(in geometry: GeometryProxy) -> some View {
    VStack(spacing: 16) {
      // Game stats
      gameStatsView

      // Word grid
      wordGridView
        .frame(maxWidth: min(geometry.size.width - 32, 350)) // Limit max width
    }
    .frame(maxWidth: .infinity)
  }

  private var gameStatsView: some View {
    HStack(spacing: 30) {
      VStack(spacing: 4) {
        Text("\(session.wordleGame.guesses.count)")
          .font(.title3)
          .fontWeight(.bold)
          .monospacedDigit()
          .foregroundStyle(.orange)

        Text("Attempts")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      VStack(spacing: 4) {
        Text("\(session.wordleGame.maxAttempts)")
          .font(.title3)
          .fontWeight(.bold)
          .monospacedDigit()
          .foregroundStyle(.secondary)

        Text("Max Attempts")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      VStack(spacing: 4) {
        Text("\(session.wordleGame.targetWord.count)")
          .font(.title3)
          .fontWeight(.bold)
          .monospacedDigit()
          .foregroundStyle(.blue)

        Text("Letters")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }

  private var wordGridView: some View {
    GeometryReader { geometry in
      let letterSize = calculateLetterSize(in: geometry)

      ScrollView {
        ForEach(0..<session.wordleGame.maxAttempts, id: \.self) { row in
          HStack(spacing: 0) {
            ForEach(0..<session.wordleGame.targetWord.count, id: \.self) { col in
              WordleLetterView(
                letter: getLetterForPosition(row: row, col: col),
                state: getLetterState(row: row, col: col),
                game: session.wordleGame,
                size: letterSize
              )
              .padding(.horizontal, 3)
              .padding(.vertical, 4)
            }
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.vertical)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
  }

  private func calculateLetterSize(in geometry: GeometryProxy) -> CGFloat {
    let availableWidth = geometry.size.width - 32 // Padding
    let spacing = 8.0 * 4 // 4 spaces between 5 letters
    let letterWidth = (availableWidth - spacing) / 5 // 5 letters per row

    // Ensure the letters are square and not too large or small
    return min(max(letterWidth, 40), 60)
  }

  // MARK: - Keyboard

  private var keyboardView: some View {
    WordleKeyboardView(
      game: session.wordleGame,
      onLetterTap: { letter in
        session.wordleGame.addLetter(letter)
      },
      onEnterTap: {
        if session.wordleGame.currentAttempt.count == session.wordleGame.targetWord.count {
          submitCurrentGuess()
        }
      },
      onDeleteTap: {
        session.wordleGame.deleteLastLetter()
      }
    )
  }

  // MARK: - Helper Methods

  private func getLetterForPosition(row: Int, col: Int) -> String {
    if row < session.wordleGame.guesses.count {
      let guess = session.wordleGame.guesses[row]
      if col < guess.count {
        return String(guess[guess.index(guess.startIndex, offsetBy: col)])
      }
    } else if row == session.wordleGame.guesses.count {
      // Current attempt row
      if col < session.wordleGame.currentAttempt.count {
        return String(session.wordleGame.currentAttempt[session.wordleGame.currentAttempt.index(session.wordleGame.currentAttempt.startIndex, offsetBy: col)])
      }
    }
    return ""
  }

  private func getLetterState(row: Int, col: Int) -> LetterState {
    if row < session.wordleGame.guesses.count {
      let guess = session.wordleGame.guesses[row]
      if col < guess.count {
        return getLetterStateForGuess(guess: guess, position: col, targetWord: session.wordleGame.targetWord)
      }
    } else if row == session.wordleGame.guesses.count && col < session.wordleGame.currentAttempt.count {
      return .current
    }
    return .empty
  }

  // Proper Wordle letter state calculation handling duplicate letters
  private func getLetterStateForGuess(guess: String, position: Int, targetWord: String) -> LetterState {
    let guessArray = Array(guess)
    let targetArray = Array(targetWord)

    guard position < guessArray.count && position < targetArray.count else { return .empty }

    let guessLetter = guessArray[position]
    let targetLetter = targetArray[position]

    // Check if letter is in correct position
    if guessLetter == targetLetter {
      return .correct
    }

    // Check if letter is in the word but wrong position
    // This is complex due to duplicate letter handling in Wordle
    let targetLetterCount = targetArray.filter { $0 == guessLetter }.count
    let correctPositions = zip(guessArray, targetArray).enumerated().filter { index, pair in
      pair.0 == guessLetter && pair.1 == guessLetter
    }.count

    let wrongPositionsSoFar = guessArray.prefix(position).enumerated().filter { index, letter in
      letter == guessLetter && targetArray[index] != guessLetter && targetArray.contains(guessLetter)
    }.count

    if wrongPositionsSoFar + correctPositions < targetLetterCount && targetArray.contains(guessLetter) {
      return .wrongPosition
    }

    return .notInWord
  }

  private func submitCurrentGuess() {
    let guess = session.wordleGame.currentAttempt
    guard DictionaryManager.shared.isValid(word: guess) else {
      return
    }
    session.wordleGame.submitGuess(guess)
  }

  private func handleGameCompletion() {
    gameTimer.stopTimer()
    session.complete()
  }

  private var backgroundGradient: some View {
    LinearGradient(
      colors: [.clear, .orange.opacity(0.05)],
      startPoint: .top,
      endPoint: .bottom
    )
    .ignoresSafeArea()
  }
}

// MARK: - Supporting Views

struct WordleLetterView: View {
  let letter: String
  let state: LetterState
  let game: WordleGame
  let size: CGFloat

  var body: some View {
    Text(letter)
      .font(.system(size: size * 0.5, weight: .bold))
      .foregroundStyle(textColor)
      .frame(width: size, height: size)
      .background(backgroundColor)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(borderColor, lineWidth: 2)
      )
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .scaleEffect(state == .current ? 1.05 : 1.0)
      .animation(.easeInOut(duration: 0.1), value: state)
  }

  private var backgroundColor: Color {
    switch state {
    case .empty:
      return .clear
    case .current:
      return .secondary.opacity(0.2)
    case .correct:
      return .green
    case .wrongPosition:
      return .orange
    case .notInWord:
      return .secondary
    }
  }

  private var textColor: Color {
    switch state {
    case .empty, .current:
      return .primary
    case .correct, .wrongPosition, .notInWord:
      return .white
    }
  }

  private var borderColor: Color {
    switch state {
    case .empty:
      return .secondary.opacity(0.3)
    case .current:
      return .primary
    case .correct, .wrongPosition, .notInWord:
      return .clear
    }
  }
}

enum LetterState {
  case empty
  case current
  case correct
  case wrongPosition
  case notInWord
}

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

class DictionaryManager {
  static let shared = DictionaryManager()
  private var words: Set<String> = []

  init() {
    if let path = Bundle.main.path(forResource: "english_words", ofType: "txt"),
       let content = try? String(contentsOfFile: path, encoding: .utf8) {
      words = Set(content.components(separatedBy: .newlines).map { $0.uppercased() })
    }
  }

  func isValid(word: String) -> Bool {
    words.contains(word.uppercased())
  }
}

// MARK: - Preview
#Preview("Wordle Game") {
  let mockLevel = try! AnyGameLevel(WordleLevelData(
    id: "wordle_daily_1",
    targetWord: "SWIFT",
    maxAttempts: 6  // Changed from 5 to 6
  ))

  let session = GameSession(
    gameType: .wordle,
    level: mockLevel,
    context: .daily(Date())
  )

  WordleGameView(session: session)
    .environment(GameCoordinator())
    .modelContainer(for: [DailyCompletion.self, GameProgress.self])
}
