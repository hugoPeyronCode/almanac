//
//  SetsGameView.swift
//  almanac
//
//

import SwiftUI

struct SetsGameView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(GameCoordinator.self) private var coordinator

  @State private var viewModel: SetsGameViewModel
  @State private var showExitConfirmation = false
  @State private var gameTimer = GameTimer()
  @State private var showAlreadyFoundAlert = false
  @State private var checkResult: SetsGame.CheckResult = .none

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
            isGameLost: viewModel.game?.isGameOver ?? false,
            potentialRightAnswer: "",
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
      // Initialize the game with model context
      viewModel.setupGame(with: modelContext)

      gameTimer.displayTime = viewModel.session.actualPlayTime
      gameTimer.startTimer()
    }
    .onDisappear {
      gameTimer.stopTimer()

      if !viewModel.isGameComplete {
        viewModel.session.pause()
        gameTimer.pause()
      }

    }
    .alert("Set Already Found", isPresented: $showAlreadyFoundAlert) {
      Button("OK", role: .cancel) { }
    } message: {
      Text("You've already found this set. Try finding a different combination!")
    }
    .onChange(of: checkResult) { oldValue, newValue in
      if newValue == .invalidSet {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
      } else if newValue == .validSet {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
      } else if newValue == .alreadyFound {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
      }
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
    VStack(spacing: 16) {
      // Lives as hearts
      HStack(spacing: 8) {
        ForEach(0..<3, id: \.self) { index in
          Image(systemName: index < (viewModel.game?.lifes ?? 3) ? "heart.fill" : "heart")
            .font(.title2)
            .foregroundStyle(index < (viewModel.game?.lifes ?? 3) ? .red : .gray.opacity(0.3))
        }
      }

      // Found sets display
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          // Show found sets
          ForEach(Array((viewModel.game?.foundSets ?? []).enumerated()), id: \.offset) { index, set in
            MiniSetCardView(cards: set)
          }

          // Show empty slots for remaining sets
          ForEach((viewModel.game?.foundSets.count ?? 0)..<(viewModel.game?.targetSets ?? 0), id: \.self) { index in
            EmptySetSlotView()
          }
        }
      }
      .frame(height: 60)
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
      ForEach(viewModel.game?.visibleCards ?? [], id: \.id) { card in
        SetCardView(
          card: card,
          isSelected: viewModel.game?.selectedCards.contains(card) ?? false,
          isHinted: viewModel.game?.hintCards.contains(card) ?? false,
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
    VStack(spacing: 12) {
      // Debug button
      DebugCompleteButton(session: viewModel.session, label: "Force Win")
        .disabled(viewModel.session.isCompleted)

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
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.game?.visibleCards.count ?? 0)

      // Submit button - centered and prominent
      Button {
        if viewModel.game?.selectedCards.count == 3 {
          checkResult = viewModel.checkSet()
          if checkResult == .alreadyFound {
            showAlreadyFoundAlert = true
          }
        }
      } label: {
        Text("Submit")
          .font(.headline)
          .foregroundStyle(submitButtonTextColor)
          .frame(width: 120, height: 50)
          .background(submitButtonBackgroundColor)
          .clipShape(RoundedRectangle(cornerRadius: 25))
          .overlay(
            RoundedRectangle(cornerRadius: 25)
              .stroke(submitButtonBorderColor, lineWidth: 2)
          )
      }
      .disabled(viewModel.game?.selectedCards.count != 3)
      .scaleEffect(viewModel.game?.selectedCards.count == 3 ? 1.0 : 0.95)
      .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.game?.selectedCards.count)

        Button {
          viewModel.findHint()
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "lightbulb")
            Text("Hint (\(3 - (viewModel.game?.hintsUsed ?? 0)))")
              .font(.subheadline)
          }
          .foregroundStyle(viewModel.canUseHint ? .yellow : .secondary)
          .frame(width: 100, height: 44)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.game?.hintCards.count ?? 0)
        .disabled(!viewModel.canUseHint)
      }
    }
  }

  // MARK: - Button State Properties
  private var submitButtonBackgroundColor: Color {
    viewModel.game?.selectedCards.count == 3 ? .green : .gray.opacity(0.2)
  }

  private var submitButtonTextColor: Color {
    viewModel.game?.selectedCards.count == 3 ? .white : .gray
  }

  private var submitButtonBorderColor: Color {
    viewModel.game?.selectedCards.count == 3 ? .green : .gray.opacity(0.3)
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

// COMPONENTS (rest of the components remain the same)
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

// Miniature set card view
struct MiniSetCardView: View {
  let cards: [SetCard]

  var body: some View {
    VStack(spacing: 2) {
      ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
        HStack(spacing: 2) {
          ForEach(0..<card.count.rawValue, id: \.self) { _ in
            MiniShapeView(card: card)
              .frame(width: 12, height: 12)
          }
        }
      }
    }
    .padding(8)
    .background(Color.green.opacity(0.2))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.green, lineWidth: 2)
    )
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

// Empty set slot view
struct EmptySetSlotView: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 8)
      .fill(Color.gray.opacity(0.1))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.gray.opacity(0.3), lineWidth: 1)
      )
      .frame(width: 50, height: 50)
  }
}

// Mini shape view for the found sets display
struct MiniShapeView: View {
  let card: SetCard

  var body: some View {
    Group {
      switch card.shading {
      case .solid:
        AnyShape(shape)
          .fill(color)
      case .striped:
        ZStack {
          AnyShape(shape)
            .fill(.clear)
          AnyShape(shape)
            .fill(miniStripedPattern)
            .stroke(color, lineWidth: 0.5)
        }
      case .outline:
        ZStack {
          AnyShape(shape)
            .fill(.clear)
          AnyShape(shape)
            .stroke(color, lineWidth: 1)
        }
      }
    }
  }

  private var shape: any Shape {
    switch card.shape {
    case .hourglass: return Hourglass()
    case .star: return Star()
    case .roundedSquare: return RoundedSquare()
    }
  }

  private var color: Color {
    switch card.color {
    case .red: return .red
    case .green: return .green
    case .purple: return .purple
    }
  }

  private var miniStripedPattern: some ShapeStyle {
    LinearGradient(
      stops: [
        .init(color: color, location: 0.0),
        .init(color: color, location: 0.25),
        .init(color: .clear, location: 0.25),
        .init(color: .clear, location: 0.5),
        .init(color: color, location: 0.5),
        .init(color: color, location: 0.75),
        .init(color: .clear, location: 0.75),
        .init(color: .clear, location: 1.0)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}


#Preview("Sets Game - Daily Challenge") {
  let mockLevel = try! AnyGameLevel(SetsLevelData(id: "sets_daily_1"))

  let session = GameSession(
    gameType: .sets,
    level: mockLevel,
    context: .daily(Date())
  )

  SetsGameView(session: session)
    .environment(GameCoordinator())
}
