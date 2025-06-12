//
//  SetsGameViewModel.swift
//  almanac
//
//  Created by Hugo Peyron on 12/06/2025.
//

import SwiftUI
import SwiftData

@Observable
class SetsGameViewModel {
  private(set) var session: GameSession
  private(set) var game: SetsGame!
  private var modelContext: ModelContext?

  init(session: GameSession) {
    self.session = session
  }

  func setupGame(with modelContext: ModelContext) {
    self.modelContext = modelContext
    self.game = session.initializeSetsGame(with: modelContext)
  }

  // MARK: - Game Actions
  func selectCard(_ card: SetCard) {
    game.selectCard(card)
    autoSave()
  }

  func deselectCard(_ card: SetCard) {
    game.deselectCard(card)
    autoSave()
  }

  func shuffleCards() {
    game.shuffleCards()
    autoSave()
  }

  func findHint() {
    game.findHint()
    autoSave()
  }

  func resetSelection() {
    game.selectedCards = []
  }

  func checkSet() -> SetsGame.CheckResult {
    let result = game.checkForSet()
    autoSave()
    return result
  }

  private func autoSave() {
    guard let modelContext = modelContext else { return }
    session.saveSetsGameState(modelContext: modelContext)
  }

  // MARK: - Computed Properties

  var contextSubtitle: String {
    guard game != nil else { return "" }
    return "• Find \(game.targetSets) sets"
  }

  var formattedDuration: String {
    return session.formattedPlayTime
  }

  var isValidSetSelected: Bool {
    guard game != nil else { return false }
    guard game.selectedCards.count == 3 else { return false }
    return game.isValidSet(game.selectedCards)
  }

  var canUseHint: Bool {
    guard game != nil else { return false }
    return game.hintsUsed < 3
  }

  // MARK: - Game State

  var isGameComplete: Bool {
    game?.isGameComplete ?? false
  }

  var selectedCardsCount: Int {
    game?.selectedCards.count ?? 0
  }
}
