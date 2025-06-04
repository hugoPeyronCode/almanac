//
//  SetsGameView.swift
//  almanac
//
//

import SwiftUI

// SET GAMES VIEWMODEL
@Observable
class SetsGameViewModel {
  private(set) var session: GameSession

  var game: SetsGame {
    return session.setsGame
  }

  init(session: GameSession) {
    self.session = session
  }

  // MARK: - Game Actions

  func selectCard(_ card: SetCard) {
    game.selectCard(card)
  }

  func deselectCard(_ card: SetCard) {
    game.deselectCard(card)
  }

  func shuffleCards() {
    game.shuffleCards()
  }

  func findHint() {
    game.findHint()
  }

  func resetSelection() {
    game.selectedCards = []
  }

  // MARK: - Computed Properties

  var contextSubtitle: String {
    let difficulty = ["Easy", "Medium", "Hard", "Expert", "Master"][min(session.level.difficulty - 1, 4)]
    return "\(difficulty) • Find 6 sets"
  }

  var formattedDuration: String {
    return session.formattedPlayTime
  }

  var isValidSetSelected: Bool {
    guard game.selectedCards.count == 3 else { return false }
    return game.isValidSet(game.selectedCards)
  }

  var canUseHint: Bool {
    return game.hintsUsed < 3
  }

  // MARK: - Game State

  var isGameComplete: Bool {
    game.isGameComplete
  }

  var selectedCardsCount: Int {
    game.selectedCards.count
  }
}

// VIEW
struct SetsGameView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(GameCoordinator.self) private var coordinator

  @State private var viewModel: SetsGameViewModel
  @State private var showExitConfirmation = false
  @State private var gameTimer = GameTimer()

  init(session: GameSession) {
    self._viewModel = State(initialValue: SetsGameViewModel(session: session))
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        backgroundGradient

        VStack(spacing: 20) {
          GameHeaderView(
            session: viewModel.session,
            showExitConfirmation: $showExitConfirmation,
            gameTimer: gameTimer
          ) {
            gameTimer.stopTimer()
            coordinator.dismissFullScreen()
          }

          Spacer()

          gameContent(in: geometry)


          Spacer()

          controlsView
        }
        .padding()

        if viewModel.isGameComplete {
          GameCompletionView(
            isGameLost: viewModel.game.isGameOver,
            formattedDuration: viewModel.formattedDuration,
            coordinator: coordinator,
            session: viewModel.session
          )
          .ignoresSafeArea()
        }
      }
    }
    .navigationBarHidden(true)
    .onChange(of: viewModel.isGameComplete) { _, isComplete in
      if isComplete && !viewModel.session.isCompleted {
        handleGameCompletion()
      }
    }
    .onAppear {
      gameTimer.displayTime = viewModel.session.actualPlayTime
      gameTimer.startTimer()
    }
    .onDisappear {
      gameTimer.stopTimer()

      if !viewModel.isGameComplete {
        viewModel.session.pause()
        gameTimer.pause()
      }

      viewModel.session.cleanupSetsGameInstance()
    }
  }

  // MARK: - Game Content

  private func gameContent(in geometry: GeometryProxy) -> some View {
    VStack(spacing: 20) {
      gameStatsView
      cardGridView(in: geometry)
    }
  }

  private var gameStatsView: some View {
    HStack(spacing: 30) {
      VStack(spacing: 4) {
        Text("\(viewModel.game.setsFound)")
          .font(.title2)
          .fontWeight(.bold)
          .monospacedDigit()
          .foregroundStyle(.green)

        Text("Sets Found")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      VStack(spacing: 4) {
        Text("\(viewModel.game.lifes)")
          .font(.title2)
          .fontWeight(.bold)
          .monospacedDigit()
          .foregroundStyle(.primary)

        Text("Lifes")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      VStack(spacing: 4) {
        Text("6")
          .font(.title2)
          .fontWeight(.bold)
          .monospacedDigit()
          .foregroundStyle(.orange)

        Text("Target Sets")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }

  private func cardGridView(in geometry: GeometryProxy) -> some View {
    let cardSize = calculateCardSize(in: geometry)

    return LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
      spacing: 8
    ) {
      ForEach(viewModel.game.visibleCards, id: \.id) { card in
        SetCardView(
          card: card,
          isSelected: viewModel.game.selectedCards.contains(card),
          isHinted: viewModel.game.hintCards.contains(card),
          cardSize: cardSize
        ) {
          viewModel.selectCard(card)
        }
      }
    }
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }

  private var controlsView: some View {
    HStack(spacing: 20) {
      Button {
        viewModel.shuffleCards()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "shuffle")
          Text("Shuffle")
            .font(.subheadline)
        }
        .foregroundStyle(.secondary)
        .frame(width: 100, height: 44)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
      }
      .sensoryFeedback(.impact(weight: .light), trigger: viewModel.game.visibleCards.count)

      Button {
        viewModel.game.checkForSet()
      } label: {
        ZStack {
          Circle()
            .foregroundStyle(.green)
            .scaleEffect(0.99)

          Image(systemName: "checkmark.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.thinMaterial)
        }
        .frame(width: 100)
      }

      Button {
        viewModel.findHint()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "lightbulb")
          Text("Hint (\(3 - viewModel.game.hintsUsed))")
            .font(.subheadline)
        }
        .foregroundStyle(viewModel.canUseHint ? .yellow : .secondary)
        .frame(width: 100, height: 44)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
      }
      .sensoryFeedback(.impact(weight: .light), trigger: viewModel.game.hintCards.count)
      .disabled(!viewModel.canUseHint)
    }
  }

  // MARK: - Helper Methods
  private func calculateCardSize(in geometry: GeometryProxy) -> CGSize {
    let availableWidth = max(geometry.size.width - 60, 0)
    let availableHeight = max(geometry.size.height * 0.7, 0)
    let cardWidth = (availableWidth)
    let cardHeight = (availableHeight)

    return CGSize(width: min(cardWidth, 100), height: min(cardHeight, 60))
  }

  private func handleGameCompletion() {
    gameTimer.stopTimer()
    viewModel.session.complete()
  }

  private var backgroundGradient: some View {
    LinearGradient(
      colors: [.clear, .purple.opacity(0.05)],
      startPoint: .top,
      endPoint: .bottom
    )
    .ignoresSafeArea()
  }
}

// COMPONENTS
// Set Card View

struct SetCardView: View {
  let card: SetCard
  let isSelected: Bool
  let isHinted: Bool
  let cardSize: CGSize
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .fill(.background)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(borderColor, lineWidth: borderWidth)
          )
          .shadow(
            color: shadowColor,
            radius: isSelected ? 4 : 0
          )

        HStack(spacing: 4) {
          ForEach(0..<card.count.rawValue, id: \.self) { _ in
            shapeView
          }
        }
        .padding(4)
      }
      .frame(width: cardSize.width, height: cardSize.height)
    }
    .buttonStyle(.plain)
    .scaleEffect(isSelected ? 1.05 : 1.0)
    .animation(.spring(duration: 0.2), value: isSelected)
    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isHinted)
    .sensoryFeedback(.impact(weight: .light), trigger: isSelected)
  }

  private var borderColor: Color {
    if isHinted {
      return .yellow
    } else if isSelected {
      return .primary
    } else {
      return .secondary.opacity(0.3)
    }
  }

  private var borderWidth: CGFloat {
    if isHinted {
      return 3
    } else if isSelected {
      return 2
    } else {
      return 1
    }
  }

  private var shadowColor: Color {
    if isHinted {
      return .yellow.opacity(0.5)
    } else if isSelected {
      return .primary.opacity(0.3)
    } else {
      return .clear
    }
  }

  @ViewBuilder
  private var shapeView: some View {
    // Taille augmentée pour des formes plus grandes
    let shapeSize = min((cardSize.width * 0.5) - 10, cardSize.height * 0.5)
    Group {
      switch card.shading {
      case .solid:
        // Forme pleine - couleur saturée
        AnyShape(currentShape)
          .fill(baseColor)

      case .striped:
        // Forme avec rayures - background + stripes overlay + contour (gardé de vos changements)
        ZStack {
          AnyShape(currentShape)
            .fill(.clear)
          AnyShape(currentShape)
            .fill(stripedPattern)
            .stroke(baseColor, lineWidth: 2)
        }

      case .outline:
        ZStack {
          AnyShape(currentShape)
            .fill(.clear)
          AnyShape(currentShape)
            .stroke(baseColor, lineWidth: 2)
        }
      }
    }
    .frame(width: shapeSize - 10, height: shapeSize * 0.7)
  }

  private var currentShape: any Shape {
    switch card.shape {
    case .hourglass:
      return Hourglass()
    case .star:
      return Star()
    case .roundedSquare:
      return RoundedSquare()
    }
  }

  private var baseColor: Color {
    switch card.color {
    case .red: return .red
    case .green: return .green
    case .purple: return .purple
    }
  }

  private var stripedPattern: some ShapeStyle {
    // Pattern de rayures fines - 6 rayures
    LinearGradient(
      stops: [
        .init(color: baseColor, location: 0.0),
        .init(color: baseColor, location: 0.07),
        .init(color: .clear, location: 0.07),
        .init(color: .clear, location: 0.14),
        .init(color: baseColor, location: 0.14),
        .init(color: baseColor, location: 0.21),
        .init(color: .clear, location: 0.21),
        .init(color: .clear, location: 0.28),
        .init(color: baseColor, location: 0.28),
        .init(color: baseColor, location: 0.35),
        .init(color: .clear, location: 0.35),
        .init(color: .clear, location: 0.42),
        .init(color: baseColor, location: 0.42),
        .init(color: baseColor, location: 0.49),
        .init(color: .clear, location: 0.49),
        .init(color: .clear, location: 0.56),
        .init(color: baseColor, location: 0.56),
        .init(color: baseColor, location: 0.63),
        .init(color: .clear, location: 0.63),
        .init(color: .clear, location: 0.7),
        .init(color: baseColor, location: 0.7),
        .init(color: baseColor, location: 0.77),
        .init(color: .clear, location: 0.77),
        .init(color: .clear, location: 1.0)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}

// Shapes
struct AnyShape: Shape {
  private let _path: (CGRect) -> Path

  init<S: Shape>(_ shape: S) {
    _path = shape.path(in:)
  }

  func path(in rect: CGRect) -> Path {
    return _path(rect)
  }
}

struct Hourglass: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()

    let width = rect.width
    let height = rect.height

    // Top part
    path.move(to: CGPoint(x: 0, y: 0))
    path.addLine(to: CGPoint(x: width, y: 0))
    path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.4))
    path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.4))
    path.closeSubpath()

    // Bottom part
    path.move(to: CGPoint(x: width * 0.4, y: height * 0.6))
    path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.6))
    path.addLine(to: CGPoint(x: width, y: height))
    path.addLine(to: CGPoint(x: 0, y: height))
    path.closeSubpath()

    return path
  }
}

struct Star: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()

    let center = CGPoint(x: rect.midX, y: rect.midY)
    let outerRadius = min(rect.width, rect.height) / 2
    let innerRadius = outerRadius * 0.4

    for i in 0..<10 {
      let angle = Double(i) * .pi / 5
      let radius = i % 2 == 0 ? outerRadius : innerRadius
      let x = center.x + cos(angle - .pi / 2) * radius
      let y = center.y + sin(angle - .pi / 2) * radius

      if i == 0 {
        path.move(to: CGPoint(x: x, y: y))
      } else {
        path.addLine(to: CGPoint(x: x, y: y))
      }
    }

    path.closeSubpath()
    return path
  }
}

struct RoundedSquare: Shape {
  func path(in rect: CGRect) -> Path {
    let cornerRadius = min(rect.width, rect.height) * 0.2
    return Path(roundedRect: rect, cornerRadius: cornerRadius)
  }
}

// GAME VIEW MODEL

@Observable
class SetsGame {
  // Game state
  var deck: [SetCard] = []
  var visibleCards: [SetCard] = []
  var selectedCards: [SetCard] = []
  var foundSets: [[SetCard]] = []
  var hintCards: [SetCard] = []

  // Game stats
  var lifes = 999
  var setsFound = 0
  var hintsUsed = 0
  var targetSets = 6
  var isGameComplete = false
  var isGameOver = false

  init() {
    setupNewGame()
  }

  func loadLevel(_ levelData: SetsLevelData) {
    targetSets = 6
    setupNewGame()
    print("✅ Loaded Sets level: difficulty \(levelData.difficulty), target: 6 sets")
  }

  func setupNewGame() {
    generateDeck()
    deck.shuffle()
    dealInitialCards()
    selectedCards = []
    foundSets = []
    hintCards = []
    lifes = 5
    setsFound = 0
    hintsUsed = 0
    isGameComplete = false
    isGameOver = false
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

  private func dealInitialCards() {
    visibleCards = []

    // Deal 12 cards initially
    for _ in 0..<12 {
      if !deck.isEmpty {
        visibleCards.append(deck.removeFirst())
      }
    }
  }

  func selectCard(_ card: SetCard) {
    if selectedCards.contains(card) {
      deselectCard(card)
      return
    }

    if selectedCards.count < 3 {
      selectedCards.append(card)

      if selectedCards.count >= 3 {
        return
      }
    }

    // Clear hint when user selects cards
    hintCards = []
  }

  func deselectCard(_ card: SetCard) {
    selectedCards.removeAll { $0.id == card.id }
    hintCards = []
  }

  func checkForSet() {
    guard selectedCards.count == 3 else { return }

    if isValidSet(selectedCards) {
      // Valid set found!
      foundSets.append(selectedCards)
      setsFound += 1

      // Remove cards from visible deck
      for card in selectedCards {
        visibleCards.removeAll { $0.id == card.id }
      }

//      dealReplacementCards()

      // Check win condition
      checkWinCondition()

      // Haptic feedback for success
      let impact = UINotificationFeedbackGenerator()
      impact.notificationOccurred(.success)
    } else {
      // Invalid set - deduct points
      lifes -= 1
      if lifes <= 0 {
        isGameOver = true
        isGameComplete = true
      }
      let impact = UINotificationFeedbackGenerator()
      impact.notificationOccurred(.error)
    }

    // Clear selection after a brief delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
      self.selectedCards = []
    }
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

  private func calculateSetScore() -> Int {
    let baseScore = 10
    let hintPenalty = hintsUsed * 2
    return max(1, baseScore - hintPenalty)
  }

  private func dealReplacementCards() {
    while visibleCards.count < 12 && !deck.isEmpty {
      visibleCards.append(deck.removeFirst())
    }
  }

  private func checkWinCondition() {
    if setsFound >= targetSets {
      isGameComplete = true
      let impact = UIImpactFeedbackGenerator(style: .heavy)
      impact.impactOccurred()
    }
  }

  func shuffleCards() {
    visibleCards.shuffle()
    selectedCards = []
    hintCards = []
  }

  func findHint() {
    guard hintsUsed < 3 else { return }

    hintCards = []

    // Find any valid set in visible cards
    for i in 0..<visibleCards.count {
      for j in (i+1)..<visibleCards.count {
        for k in (j+1)..<visibleCards.count {
          let cards = [visibleCards[i], visibleCards[j], visibleCards[k]]
          if isValidSet(cards) {
            hintCards = cards
            hintsUsed += 1
            return
          }
        }
      }
    }

    // No sets found
    let impact = UINotificationFeedbackGenerator()
    impact.notificationOccurred(.warning)
  }
}

// MODELS

struct SetCard: Identifiable, Equatable {
  let id = UUID()
  let color: SetColor
  let shape: SetShape
  let shading: SetShading
  let count: SetCount
}

enum SetColor: CaseIterable {
  case red, green, purple
}

enum SetShape: CaseIterable {
  case hourglass, star, roundedSquare
}

enum SetShading: CaseIterable {
  case solid, striped, outline
}

enum SetCount: Int, CaseIterable {
  case one = 1, two = 2, three = 3
}

// Preview
#Preview("Sets Game - Daily Challenge") {
  let mockLevel = try! AnyGameLevel(SetsLevelData(id: "sets_daily_1", difficulty: 3))

  let session = GameSession(
    gameType: .sets,
    level: mockLevel,
    context: .daily(Date())
  )

  SetsGameView(session: session)
    .environment(GameCoordinator())
}
