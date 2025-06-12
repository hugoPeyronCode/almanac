//
//  SetsGame.swift
//  almanac
//
//  Created by Hugo Peyron on 12/06/2025.
//

import SwiftUI

@Observable
class SetsGame {
  // Game state
  var deck: [SetCard] = []
  var visibleCards: [SetCard] = []
  var selectedCards: [SetCard] = []
  var foundSets: [[SetCard]] = []
  var hintCards: [SetCard] = []
  var possibleSets: [[SetCard]] = []

  // Game stats
  var lifes = 3
  var setsFound = 0
  var hintsUsed = 0
  var targetSets = 0  // Will be set dynamically based on possible sets
  var isGameComplete = false
  var isGameOver = false

  // For deterministic generation
  private var randomGenerator: SeededRandomGenerator?

  init() {
    // Default initialization without seed
    setupNewGame()
  }

  init(seed: Int) {
    // Initialize with seed for deterministic generation
    self.randomGenerator = SeededRandomGenerator(seed: seed)
    setupNewGame()
  }

  func setupNewGame() {
    generateValidDeck()
    selectedCards = []
    foundSets = []
    hintCards = []
    lifes = 3
    setsFound = 0
    hintsUsed = 0
    isGameComplete = false
    isGameOver = false
  }

  func setupWithSeed(_ seed: Int) {
    self.randomGenerator = SeededRandomGenerator(seed: seed)
    setupNewGame()
  }

  private func generateValidDeck() {
    var attempts = 0
    repeat {
      generateDeck()
      shuffleDeck()
      dealInitialCards()
      possibleSets = findAllPossibleSets()
      attempts += 1
    } while possibleSets.count < 6 && attempts < 100

    // Set target to total possible sets in the deck
    targetSets = possibleSets.count

    if attempts >= 100 {
      print("Warning: Could not generate deck with 6+ sets after 100 attempts. Found \(possibleSets.count) sets.")
    }
  }

  private func generateDeck() {
    deck = []

    for color in SetColor.allCases {
      for shape in SetShape.allCases {
        for shading in SetShading.allCases {
          for count in SetCount.allCases {
            deck.append(SetCard(
              color: color,
              shape: shape,
              shading: shading,
              count: count
            ))
          }
        }
      }
    }
  }

  private func shuffleDeck() {
    if var generator = randomGenerator {
      // Deterministic shuffle using seeded random
      for i in stride(from: deck.count - 1, through: 1, by: -1) {
        let j = generator.nextInt(in: 0..<(i + 1))
        deck.swapAt(i, j)
      }
      randomGenerator = generator
    } else {
      // Regular random shuffle
      deck.shuffle()
    }
  }

  private func dealInitialCards() {
    visibleCards = []

    // Deal 12 cards initially
    for i in 0..<12 {
      if i < deck.count {
        visibleCards.append(deck[i])
      }
    }
  }

  private func findAllPossibleSets() -> [[SetCard]] {
    var sets: [[SetCard]] = []

    for i in 0..<visibleCards.count {
      for j in (i+1)..<visibleCards.count {
        for k in (j+1)..<visibleCards.count {
          let cards = [visibleCards[i], visibleCards[j], visibleCards[k]]
          if isValidSet(cards) {
            sets.append(cards)
          }
        }
      }
    }

    return sets
  }

  func selectCard(_ card: SetCard) {
    if selectedCards.contains(card) {
      deselectCard(card)
      return
    }

    if selectedCards.count < 3 {
      selectedCards.append(card)
    }

    hintCards = []
  }

  func deselectCard(_ card: SetCard) {
    selectedCards.removeAll { $0.id == card.id }
    hintCards = []
  }

  func checkForSet() -> CheckResult {
    guard selectedCards.count == 3 else { return .none }

    if isValidSet(selectedCards) {
      // Check if this set has already been found
      let isAlreadyFound = foundSets.contains { foundSet in
        Set(foundSet.map { $0.id }) == Set(selectedCards.map { $0.id })
      }

      if !isAlreadyFound {
        foundSets.append(selectedCards)
        setsFound += 1

        // Check win condition
        checkWinCondition()

        // Clear selection after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
          self.selectedCards = []
        }

        return .validSet
      } else {
        // Clear selection after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
          self.selectedCards = []
        }

        return .alreadyFound
      }
    } else {
      // Invalid set - deduct life
      lifes -= 1
      if lifes <= 0 {
        isGameOver = true
        isGameComplete = true
      }

      // Clear selection after a brief delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        self.selectedCards = []
      }

      return .invalidSet
    }
  }

  enum CheckResult {
    case none
    case validSet
    case invalidSet
    case alreadyFound
  }

  func isValidSet(_ cards: [SetCard]) -> Bool {
    guard cards.count == 3 else { return false }

    let colors = Set(cards.map { $0.color })
    let shapes = Set(cards.map { $0.shape })
    let shadings = Set(cards.map { $0.shading })
    let counts = Set(cards.map { $0.count })

    // For each attribute, all three cards must be either all the same or all different
    let colorsValid = colors.count == 1 || colors.count == 3
    let shapesValid = shapes.count == 1 || shapes.count == 3
    let shadingsValid = shadings.count == 1 || shadings.count == 3
    let countsValid = counts.count == 1 || counts.count == 3

    return colorsValid && shapesValid && shadingsValid && countsValid
  }

  private func checkWinCondition() {
    if setsFound >= targetSets {
      isGameComplete = true
      let impact = UIImpactFeedbackGenerator(style: .heavy)
      impact.impactOccurred()
    }
  }

  func shuffleCards() {
    if var generator = randomGenerator {
      // Deterministic shuffle
      for i in stride(from: visibleCards.count - 1, through: 1, by: -1) {
        let j = generator.nextInt(in: 0..<(i + 1))
        visibleCards.swapAt(i, j)
      }
      randomGenerator = generator
    } else {
      // Regular shuffle
      visibleCards.shuffle()
    }
    selectedCards = []
    hintCards = []
  }

  func findHint() {
    guard hintsUsed < 3 else { return }

    hintCards = []

    // Find any valid set in visible cards that hasn't been found yet
    for i in 0..<visibleCards.count {
      for j in (i+1)..<visibleCards.count {
        for k in (j+1)..<visibleCards.count {
          let cards = [visibleCards[i], visibleCards[j], visibleCards[k]]
          if isValidSet(cards) {
            // Check if this set hasn't been found yet
            let isAlreadyFound = foundSets.contains { foundSet in
              Set(foundSet.map { $0.id }) == Set(cards.map { $0.id })
            }

            if !isAlreadyFound {
              hintCards = cards
              hintsUsed += 1
              return
            }
          }
        }
      }
    }

    // No unfound sets available
    let impact = UINotificationFeedbackGenerator()
    impact.notificationOccurred(.warning)
  }

  // MARK: - State Management

  func restoreState(foundSets: [[SetCard]], hintsUsed: Int, lifes: Int, isComplete: Bool) {
    self.foundSets = foundSets
    self.hintsUsed = hintsUsed
    self.lifes = lifes
    self.isGameComplete = isComplete
    self.isGameOver = lifes <= 0
    self.setsFound = foundSets.count

    // Clear any temporary state
    self.selectedCards = []
    self.hintCards = []
  }
}
