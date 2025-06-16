//
//  WorldeView.swift
//  almanac
//
//  Updated with state persistence
//

import SwiftUI

struct WordleGameView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(GameCoordinator.self) private var coordinator

  @State private var session: GameSession
  @State private var showExitConfirmation = false
  @State private var gameTimer = GameTimer()
  @State private var showInvalidWordAlert = false
  @State private var game: WordleGame?

  init(session: GameSession) {
    self._session = State(initialValue: session)
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        backgroundGradient

        if let game = game {
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

            gameContent(game: game, in: geometry)

            keyboardView(game: game)
              .padding(.bottom, 8)
          }
          .padding(.horizontal)
          .padding(.top, 8)

          if game.isGameComplete {
            GameCompletionView(
              isGameLost: !game.isGameWon,
              potentialRightAnswer: game.targetWord,
              formattedDuration: session.formattedPlayTime,
              coordinator: coordinator,
              session: session
            )
            .ignoresSafeArea()
          }

          VStack {
            Text(game.targetWord)
            DebugCompleteButton(session: session, label: "Force Win")
              .disabled(session.isCompleted)
              .padding(.bottom, 8)
            Spacer()
          }
        } else {
          ProgressView("Loading...")
        }
      }
    }
    .navigationBarHidden(true)
    .onChange(of: game?.isGameComplete ?? false) { _, isComplete in
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

      if !(game?.isGameComplete ?? true) {
        session.pause()
        gameTimer.pause()
      }

      // Don't cleanup if game is not complete - preserve instance
      if game?.isGameComplete ?? false {
        session.cleanupWordleGameInstance()
      }
    }
    .confirmationDialog("Exit Game", isPresented: $showExitConfirmation) {
      Button("Exit", role: .destructive) {
        coordinator.dismissFullScreen()
      }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("Are you sure you want to exit? Progress will be saved.")
    }
    .alert("Invalid Word", isPresented: $showInvalidWordAlert) {
      Button("OK", role: .cancel) { }
    } message: {
      Text("'\(game?.currentAttempt ?? "")' is not in the word list")
    }
  }

  // MARK: - Game Content

  private func gameContent(game: WordleGame, in geometry: GeometryProxy) -> some View {
    VStack(spacing: 16) {
      // Game stats
      gameStatsView(game: game)

      // Word grid
      wordGridView(game: game)
        .frame(maxWidth: min(geometry.size.width - 32, 350)) // Limit max width
    }
    .frame(maxWidth: .infinity)
  }

  private func gameStatsView(game: WordleGame) -> some View {
    HStack(spacing: 30) {
      VStack(spacing: 4) {
        Text("\(game.guesses.count)")
          .font(.title3)
          .fontWeight(.bold)
          .monospacedDigit()
          .foregroundStyle(.orange)

        Text("Attempts")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      VStack(spacing: 4) {
        Text("\(game.maxAttempts)")
          .font(.title3)
          .fontWeight(.bold)
          .monospacedDigit()
          .foregroundStyle(.secondary)

        Text("Max Attempts")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      VStack(spacing: 4) {
        Text("\(game.targetWord.count)")
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

  private func wordGridView(game: WordleGame) -> some View {
    GeometryReader { geometry in
      let letterSize = calculateLetterSize(in: geometry)

      ScrollView {
        ForEach(0..<game.maxAttempts, id: \.self) { row in
          HStack(spacing: 0) {
            ForEach(0..<game.targetWord.count, id: \.self) { col in
              WordleLetterView(
                letter: getLetterForPosition(game: game, row: row, col: col),
                state: getLetterState(game: game, row: row, col: col),
                game: game,
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

  private func keyboardView(game: WordleGame) -> some View {
    WordleKeyboardView(
      game: game,
      onLetterTap: { letter in
        game.addLetter(letter)
      },
      onEnterTap: {
        if game.currentAttempt.count == game.targetWord.count {
          submitCurrentGuess(game: game)
        }
      },
      onDeleteTap: {
        game.deleteLastLetter()
      }
    )
  }

  // MARK: - Helper Methods

  private func getLetterForPosition(game: WordleGame, row: Int, col: Int) -> String {
    if row < game.guesses.count {
      let guess = game.guesses[row]
      if col < guess.count {
        return String(guess[guess.index(guess.startIndex, offsetBy: col)])
      }
    } else if row == game.guesses.count {
      // Current attempt row
      if col < game.currentAttempt.count {
        return String(game.currentAttempt[game.currentAttempt.index(game.currentAttempt.startIndex, offsetBy: col)])
      }
    }
    return ""
  }

  private func getLetterState(game: WordleGame, row: Int, col: Int) -> LetterState {
    if row < game.guesses.count {
      let guess = game.guesses[row]
      if col < guess.count {
        return getLetterStateForGuess(guess: guess, position: col, targetWord: game.targetWord)
      }
    } else if row == game.guesses.count && col < game.currentAttempt.count {
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

  private func submitCurrentGuess(game: WordleGame) {
    let guess = game.currentAttempt
    guard DictionaryManager.shared.isValid(word: guess) else {
      showInvalidWordAlert = true
      return
    }
    game.submitGuess(guess)
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
