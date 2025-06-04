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
    
    // Invalid word feedback
    @State private var showInvalidWordFeedback = false
    @State private var invalidWordShake = false
    
    // Completion animation
    @State private var showCompletionAnimation = false
    @State private var letterAnimationIndex = 0
    
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
                    
                    Spacer()
                    
                    // Debug button
                    DebugCompleteButton(session: session, label: "Force Win")
                        .disabled(session.isCompleted)
                        .padding(.bottom, 8)
                    
                    keyboardView
                        .frame(maxWidth: min(geometry.size.width - 32, 400)) // Limit keyboard width
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if session.wordleGame.isGameComplete {
                    GameCompletionView(
                        formattedDuration: session.formattedPlayTime,
                        coordinator: coordinator,
                        session: session
                    )
                    .ignoresSafeArea()
                }
                
                // Invalid word feedback overlay
                if showInvalidWordFeedback {
                    invalidWordOverlay
                }
                
                // Completion animation overlay
                if showCompletionAnimation {
                    completionAnimationOverlay
                }
            }
        }
        .navigationBarHidden(true)
        .onChange(of: session.wordleGame.isGameComplete) { _, isComplete in
            if isComplete && !session.isCompleted {
                triggerCompletionAnimation()
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
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                
                Text("Attempts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("\(session.wordleGame.maxAttempts)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                
                Text("Max Attempts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("\(session.wordleGame.targetWord.count)")
                    .font(.title2)
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
            
            VStack(spacing: 8) {
                ForEach(0..<session.wordleGame.maxAttempts, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<session.wordleGame.targetWord.count, id: \.self) { col in
                            WordleLetterView(
                                letter: getLetterForPosition(row: row, col: col),
                                state: getLetterState(row: row, col: col),
                                game: session.wordleGame,
                                size: letterSize
                            )
                        }
                    }
                    .offset(x: row == session.wordleGame.guesses.count && invalidWordShake ? 5 : 0)
                    .animation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true), value: invalidWordShake)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .frame(height: 280) // Fixed height for the grid
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
        GeometryReader { geometry in
            let keySize = calculateKeySize(in: geometry)
            
            VStack(spacing: 8) {
                // First row - 10 keys
                HStack(spacing: 4) {
                    ForEach(["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"], id: \.self) { letter in
                        KeyboardKeyView(letter: letter, game: session.wordleGame, size: keySize) {
                            session.wordleGame.addLetter(Character(letter))
                        }
                    }
                }
                
                // Second row - 9 keys
                HStack(spacing: 4) {
                    ForEach(["A", "S", "D", "F", "G", "H", "J", "K", "L"], id: \.self) { letter in
                        KeyboardKeyView(letter: letter, game: session.wordleGame, size: keySize) {
                            session.wordleGame.addLetter(Character(letter))
                        }
                    }
                }
                
                // Third row - ENTER + 7 keys + DELETE
                HStack(spacing: 4) {
                    Button {
                        if session.wordleGame.currentAttempt.count == session.wordleGame.targetWord.count {
                            submitCurrentGuess()
                        }
                    } label: {
                        Text("ENTER")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: keySize * 1.3, height: keySize)
                            .background(session.wordleGame.currentAttempt.count == session.wordleGame.targetWord.count ? .green : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .disabled(session.wordleGame.currentAttempt.count != session.wordleGame.targetWord.count)
                    
                    ForEach(["Z", "X", "C", "V", "B", "N", "M"], id: \.self) { letter in
                        KeyboardKeyView(letter: letter, game: session.wordleGame, size: keySize) {
                            session.wordleGame.addLetter(Character(letter))
                        }
                    }
                    
                    Button {
                        session.wordleGame.deleteLastLetter()
                    } label: {
                        Image(systemName: "delete.left")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .frame(width: keySize * 1.3, height: keySize)
                            .background(.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .frame(height: 150) // Fixed height for keyboard
    }
    
    private func calculateKeySize(in geometry: GeometryProxy) -> CGFloat {
        let availableWidth = geometry.size.width - 16 // Padding
        let spacing = 4.0 * 9 // 9 spaces for 10 keys in first row
        let keyWidth = (availableWidth - spacing) / 10 // 10 keys in longest row
        
        // Ensure keys are not too small or large
        return min(max(keyWidth, 28), 36)
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
            // Show invalid word feedback with animation
            showInvalidWordAnimation()
            return
        }
        
        session.wordleGame.submitGuess(guess)
    }
    
    private func showInvalidWordAnimation() {
        withAnimation {
            showInvalidWordFeedback = true
            invalidWordShake = true
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Hide feedback after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showInvalidWordFeedback = false
                invalidWordShake = false
            }
        }
    }
    
    // MARK: - Invalid Word Overlay
    
    private var invalidWordOverlay: some View {
        VStack {
            Spacer()
            
            Text("Mot invalide")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.orange.opacity(0.5), lineWidth: 1)
                )
                .scaleEffect(showInvalidWordFeedback ? 1.0 : 0.8)
                .opacity(showInvalidWordFeedback ? 1.0 : 0.0)
                .animation(.spring(duration: 0.4), value: showInvalidWordFeedback)
            
            Spacer()
                .frame(height: 200) // Position above keyboard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false) // Allow touches to pass through
    }
    
    private func triggerCompletionAnimation() {
        showCompletionAnimation = true
        
        // Animate each letter of the winning word
        let winningRow = session.wordleGame.guesses.count - 1
        animateWinningRow(row: winningRow)
        
        // Complete the session after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            handleGameCompletion()
        }
    }
    
    private func animateWinningRow(row: Int) {
        letterAnimationIndex = 0
        
        for i in 0..<session.wordleGame.targetWord.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                letterAnimationIndex = i + 1
                
                // Haptic feedback for each letter
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
        }
    }
    
    private func handleGameCompletion() {
        gameTimer.stopTimer()
        session.complete()
        showCompletionAnimation = false
    }
    
    // MARK: - Completion Animation Overlay
    
    private var completionAnimationOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                Text(session.wordleGame.isGameWon ? "Excellent!" : "Perdu!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(session.wordleGame.isGameWon ? .green : .red)
                    .scaleEffect(showCompletionAnimation ? 1.2 : 0.5)
                    .animation(.spring(duration: 0.6), value: showCompletionAnimation)
                
                if session.wordleGame.isGameWon {
                    Text("Le mot était: \(session.wordleGame.targetWord)")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .opacity(showCompletionAnimation ? 1 : 0)
                        .animation(.easeIn(duration: 0.4).delay(0.3), value: showCompletionAnimation)
                }
                
                // Animated winning row
                if session.wordleGame.isGameWon && !session.wordleGame.guesses.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(0..<session.wordleGame.targetWord.count, id: \.self) { col in
                            let shouldAnimate = col < letterAnimationIndex
                            
                            Text(String(session.wordleGame.targetWord[session.wordleGame.targetWord.index(session.wordleGame.targetWord.startIndex, offsetBy: col)]))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .background(.green)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .scaleEffect(shouldAnimate ? 1.1 : 1.0)
                                .rotationEffect(.degrees(shouldAnimate ? 360 : 0))
                                .animation(.spring(duration: 0.5), value: shouldAnimate)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(32)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.3))
        .allowsHitTesting(false)
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

struct KeyboardKeyView: View {
    let letter: String
    let game: WordleGame
    let size: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(letter)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(keyColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .disabled(game.isGameComplete)
        .sensoryFeedback(.impact(weight: .light), trigger: game.currentAttempt.count)
    }
    
    private var keyColor: Color {
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
            return .green
        } else if hasWrongPosition {
            return .orange
        } else if hasNotInWord {
            return .secondary
        } else {
            return .secondary.opacity(0.8)
        }
    }
    
    // Helper function to get letter state - shared with main view
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
        difficulty: 3,
        targetWord: "SWIFT",
        maxAttempts: 5
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
