//
//  WordleKeyboardView.swift
//  almanac
//
//  Extracted keyboard component for Wordle game
//

import SwiftUI


struct WordleKeyboardView: View {
    let game: WordleGame
    let onLetterTap: (Character) -> Void
    let onEnterTap: () -> Void
    let onDeleteTap: () -> Void

    private let firstRow = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    private let secondRow = ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    private let thirdRow = ["Z", "X", "C", "V", "B", "N", "M"]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(firstRow, id: \.self) { letter in
                    KeyboardKeyView(
                        letter: letter,
                        game: game
                    ) {
                        onLetterTap(Character(letter))
                    }
                }
            }

            // Second row - 9 keys with spacing to center
            HStack(spacing: 4) {
                Spacer()
                    .frame(width: 20)

                ForEach(secondRow, id: \.self) { letter in
                    KeyboardKeyView(
                        letter: letter,
                        game: game
                    ) {
                        onLetterTap(Character(letter))
                    }
                }

                Spacer()
                    .frame(width: 20)
            }

            // Third row - ENTER + 7 keys + DELETE
            HStack(spacing: 4) {
                // Enter button
                Button(action: onEnterTap) {
                    Text("ENTER")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(enterButtonColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(width: 60)
                .disabled(!canSubmit)
                .sensoryFeedback(.impact(weight: .medium), trigger: canSubmit)

                ForEach(thirdRow, id: \.self) { letter in
                    KeyboardKeyView(
                        letter: letter,
                        game: game
                    ) {
                        onLetterTap(Character(letter))
                    }
                }

                // Delete button
                Button(action: onDeleteTap) {
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.secondary.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(width: 60)
                .sensoryFeedback(.impact(weight: .light), trigger: game.currentAttempt)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var canSubmit: Bool {
        game.currentAttempt.count == game.targetWord.count
    }

    private var enterButtonColor: Color {
        canSubmit ? .green : .secondary.opacity(0.8)
    }
}

// Keep the KeyboardKeyView as part of this file since it's tightly coupled
struct KeyboardKeyView: View {
    let letter: String
    let game: WordleGame
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(letter)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(keyColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(borderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: shadowColor, radius: 0.5, x: 0, y: 1)
        }
        .disabled(game.isGameComplete)
        .sensoryFeedback(.impact(weight: .light), trigger: game.currentAttempt.count)
        .scaleEffect(game.isGameComplete ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: game.isGameComplete)
    }

    private var textColor: Color {
        switch keyState {
        case .correct, .wrongPosition, .notInWord:
            return .white
        default:
            return .primary
        }
    }

    private var borderColor: Color {
        switch keyState {
        case .correct, .wrongPosition, .notInWord:
            return .clear
        default:
            return .secondary.opacity(0.2)
        }
    }

    private var shadowColor: Color {
        switch keyState {
        case .correct:
            return .green.opacity(0.3)
        case .wrongPosition:
            return .orange.opacity(0.3)
        case .notInWord:
            return .clear
        default:
            return .black.opacity(0.1)
        }
    }

    private var keyState: LetterState {
        var hasCorrect = false
        var hasWrongPosition = false
        var hasNotInWord = false

        // Check all occurrences of this letter in all guesses
        for guess in game.guesses {
            for (index, char) in guess.enumerated() {
                if String(char) == letter {
                    let state = getLetterStateForGuess(guess: guess, position: index, targetWord: game.targetWord)
                    switch state {
                    case .correct:
                        hasCorrect = true
                    case .wrongPosition:
                        hasWrongPosition = true
                    case .notInWord:
                        hasNotInWord = true
                    default:
                        break
                    }
                }
            }
        }

        // Priority: correct > wrong position > not in word > unused
        if hasCorrect {
            return .correct
        } else if hasWrongPosition {
            return .wrongPosition
        } else if hasNotInWord {
            return .notInWord
        } else {
            return .empty
        }
    }

    private var keyColor: Color {
        switch keyState {
        case .correct:
            return .green
        case .wrongPosition:
            return .orange
        case .notInWord:
            return .secondary.opacity(0.6)
        default:
            return .secondary.opacity(0.15)
        }
    }

    // Helper function to get letter state
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
}

// MARK: - Preview
#Preview("Wordle Keyboard") {
    struct PreviewWrapper: View {
        @State private var game = WordleGame(targetWord: "SWIFT", maxAttempts: 6)

        var body: some View {
            VStack {
                Spacer()

                VStack(spacing: 8) {
                    Text("Current word:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Text(index < game.currentAttempt.count ? String(game.currentAttempt[game.currentAttempt.index(game.currentAttempt.startIndex, offsetBy: index)]) : "")
                                .font(.title2.monospaced())
                                .fontWeight(.bold)
                                .frame(width: 40, height: 40)
                                .background(Color.secondary.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.primary, lineWidth: index < game.currentAttempt.count ? 2 : 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .padding()

                WordleKeyboardView(
                    game: game,
                    onLetterTap: { letter in
                        game.addLetter(letter)
                    },
                    onEnterTap: {
                        if game.currentAttempt.count == game.targetWord.count {
                            game.submitGuess(game.currentAttempt)
                        }
                    },
                    onDeleteTap: {
                        game.deleteLastLetter()
                    }
                )
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
        }
    }

    return PreviewWrapper()
}
