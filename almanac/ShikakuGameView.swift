//
//  ShikakuGameView.swift
//  shikaku
//
//  Updated game view with single tile selection and responsive grid
//

import SwiftUI

struct ShikakuGameView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(GameCoordinator.self) private var coordinator

  @State private var session: GameSession
  @State private var showExitConfirmation = false
  @State private var gameTimer = GameTimer()

  @State private var dragStart: GridPosition?
  @State private var dragEnd: GridPosition?
  @State private var isDragging = false


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
            gameTimer: gameTimer,
            subtitle: contextSubtitle
          ) {
            gameTimer.stopTimer()
            coordinator.dismissFullScreen()
          }

          Spacer()

          gameGrid(in: geometry)

          Spacer()

          controlsView
        }
        .padding()

        if session.game.isGameComplete {
          completionView
        }
      }
    }
    .navigationBarHidden(true)
    .onChange(of: session.game.isGameComplete) { _, isComplete in
      if isComplete && !session.isCompleted {
        handleGameCompletion()
      }
    }
    .confirmationDialog("Exit Game", isPresented: $showExitConfirmation) {
      Button("Exit", role: .destructive) {
        coordinator.dismissFullScreen()
      }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("Are you sure you want to exit? Progress will be lost.")
    }
    .onAppear {
//      session.game.generateReferenceLevel()
      gameTimer.displayTime = session.actualPlayTime
      gameTimer.startTimer()
    }
    .onDisappear {
      gameTimer.stopTimer()

      if !session.game.isGameComplete {
        session.pause()
        gameTimer.pause()
      }

      // Clean up the game instance to prevent memory leaks
      session.cleanupGameInstance()
    }


  }

  // MARK: - Views
  private func gameGrid(in geometry: GeometryProxy) -> some View {
    let cellSize = calculateCellSize(in: geometry)

    return VStack(spacing: 2) {
      ForEach(0..<session.game.gridSize.rows, id: \.self) { row in
        HStack(spacing: 2) {
          ForEach(0..<session.game.gridSize.cols, id: \.self) { col in
            ShikakuCellView(
              position: GridPosition(row: row, col: col),
              game: session.game,
              cellSize: cellSize,
              dragStart: dragStart,
              dragEnd: dragEnd,
              isDragging: isDragging
            )
          }
        }
      }
    }
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    .gesture(createDragGesture(cellSize: cellSize))
  }

  private var completionView: some View {
    VStack(spacing: 20) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 48))
        .foregroundStyle(Color.primary)

      Text("Solved in \(formattedDuration)")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      HStack {
        Button {
          coordinator.dismissFullScreen()
        } label: {
          Image(systemName: "house.fill")
          Text("Home")
            .font(.caption)
        }
        .fontWeight(.semibold)
        .foregroundStyle(Color.primary)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.primary, in: RoundedRectangle(cornerRadius: 12).stroke(lineWidth: 1))

        Button {
          // play again
        } label: {
          Image(systemName: "arrow.trianglehead.counterclockwise")
          Text("replay")
            .font(.caption)
        }
        .fontWeight(.semibold)
        .foregroundStyle(Color.primary)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.primary, in: RoundedRectangle(cornerRadius: 12).stroke(lineWidth: 1))

        Button {
          // Play next game logic. In practice mode would be to select a random level according to the selection done int he practice mode.
          // In the daily game it would open the calendar view as a modal
        } label: {
          Image(systemName: "chevron.forward.dotted.chevron.forward")
          Text("play next")
            .font(.caption)
        }
        .fontWeight(.semibold)
        .foregroundStyle(Color.primary)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.primary, in: RoundedRectangle(cornerRadius: 12).stroke(lineWidth: 1))
      }
    }
    .sensoryFeedback(.success, trigger: session.game.isGameComplete)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  private var controlsView: some View {
    HStack {
      Spacer()
      Button {
        withAnimation(.spring(duration: 0.3)) {
          session.game.clearBoard()
        }
      } label: {
        Text("Clear")
          .foregroundStyle(Color.secondary)
          .frame(width: 80, height: 44)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
      }
      .sensoryFeedback(.impact(weight: .medium), trigger: session.game.rectangles.isEmpty)

      Spacer()

    }
  }


  // MARK: - TIMER MANAGEMENT
  private func togglePause() {
    withAnimation(.easeInOut(duration: 0.3)) {
      if gameTimer.isPaused {
        session.resume()
        gameTimer.resume()
      } else {
        session.pause()
        gameTimer.pause()
      }
    }
  }

  private func handleGameCompletion() {
    gameTimer.stopTimer()
    session.complete()
  }


  // MARK: - Helper Methods

  private var contextTitle: String {
    switch session.context {
    case .daily: return "Daily Puzzle"
    case .practice: return "Practice"
    case .random: return "Custom Level"
    }
  }

  private var contextSubtitle: String {
    "\(session.game.gridSize.rows)×\(session.game.gridSize.cols) • \(session.game.numberClues.count) clues"
  }

  private var formattedDuration: String {
    return session.formattedPlayTime
  }

  private func calculateCellSize(in geometry: GeometryProxy) -> CGFloat {
    let availableWidth = geometry.size.width - 30
    let availableHeight = geometry.size.height * 0.7

    let cellWidth = availableWidth / CGFloat(session.game.gridSize.cols + 1)
    let cellHeight = availableHeight / CGFloat(session.game.gridSize.rows + 1)

    return min(cellWidth, cellHeight, 70)
  }

  // MARK: - Gesture Handling

  private func createDragGesture(cellSize: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        handleDragChanged(value, cellSize: cellSize)
      }
      .onEnded { _ in
        handleDragEnded()
      }
  }

  private func handleDragChanged(_ value: DragGesture.Value, cellSize: CGFloat) {
    if !isDragging {
      dragStart = positionFromLocation(value.startLocation, cellSize: cellSize)
      isDragging = true
    }

    dragEnd = positionFromLocation(value.location, cellSize: cellSize)
  }

  private func handleDragEnded() {
    guard let start = dragStart, let end = dragEnd else {
      resetDragState()
      return
    }

    let validation = session.game.validatePreviewRectangle(from: start, to: end)

    if validation.isValid {
      session.game.addOrUpdateRectangle(from: start, to: end)
    }

    resetDragState()
  }

  private func positionFromLocation(_ location: CGPoint, cellSize: CGFloat) -> GridPosition? {
    let col = Int(location.x / (cellSize + 2))
    let row = Int(location.y / (cellSize + 2))

    guard row >= 0 && row < session.game.gridSize.rows &&
            col >= 0 && col < session.game.gridSize.cols else {
      return nil
    }

    return GridPosition(row: row, col: col)
  }

  private func resetDragState() {
    dragStart = nil
    dragEnd = nil
    isDragging = false
  }

  private var backgroundGradient: some View {
    LinearGradient(
      colors: [.clear, .primary.opacity(0.05)],
      startPoint: .top,
      endPoint: .bottom
    )
    .ignoresSafeArea()
  }
}

// MARK: - Shikaku Cell View (Your exact implementation)

struct ShikakuCellView: View {
  let position: GridPosition
  let game: ShikakuGame
  let cellSize: CGFloat
  let dragStart: GridPosition?
  let dragEnd: GridPosition?
  let isDragging: Bool

  private var numberClue: NumberClue? {
    game.numberClues.first { $0.position == position }
  }

  private var containingRect: GameRectangle? {
    game.rectangles.first { $0.contains(position: position) }
  }

  private var isInPreview: Bool {
    guard let start = dragStart, let end = dragEnd, isDragging else { return false }

    let topLeft = GridPosition(
      row: min(start.row, end.row),
      col: min(start.col, end.col)
    )
    let bottomRight = GridPosition(
      row: max(start.row, end.row),
      col: max(start.col, end.col)
    )

    return position.row >= topLeft.row && position.row <= bottomRight.row &&
    position.col >= topLeft.col && position.col <= bottomRight.col
  }

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8)
        .fill(backgroundColor)
        .frame(width: cellSize, height: cellSize)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(borderColor, lineWidth: borderWidth)
        )

      if let clue = numberClue {
        Text("\(clue.value)")
          .font(.system(size: cellSize * 0.4, weight: .bold))
          .foregroundStyle(textColor)
      }
    }
  }

  private var backgroundColor: Color {
    if isInPreview && isDragging {
      return .primary.opacity(0.2)
    } else if let rect = containingRect, rect.isValid {
      return rect.color.opacity(0.6)
    } else {
      return .secondary.opacity(0.1)
    }
  }

  private var textColor: Color {
    if containingRect?.isValid == true {
      return .white
    } else {
      return .primary
    }
  }

  private var borderColor: Color {
    if isInPreview && isDragging {
      return .primary
    } else {
      return .clear
    }
  }

  private var borderWidth: CGFloat {
    isInPreview && isDragging ? 2 : 0
  }
}

// MARK: - Data Models (Your exact models preserved)

@Observable
class ShikakuGame {
  var gridSize: (rows: Int, cols: Int) = (5, 5)
  var rectangles: [GameRectangle] = []
  var numberClues: [NumberClue] = []
  var selectedRectangle: GameRectangle?
  var isGameComplete: Bool = false

  // Panel de couleurs distinctes et contrastées
  private let colorPalette: [Color] = [
    .blue,
    .red,
    .green,
    .orange,
    .purple,
    .pink,
    .yellow,
    .brown,
    .cyan,
    .indigo,
    .mint,
    .teal
  ]
  private var colorIndex = 0

  // Haptic generators
  private let lightImpact = UIImpactFeedbackGenerator(style: .soft)
  private let notificationFeedback = UINotificationFeedbackGenerator()

  init() {
    // Prepare haptics for better performance
    lightImpact.prepare()
    notificationFeedback.prepare()
  }

  func loadLevel(_ levelData: ShikakuLevelData) {
      gridSize = (rows: levelData.gridRows, cols: levelData.gridCols)

      // Convert level clues to NumberClue objects
      numberClues = levelData.clues.map { clueData in
          NumberClue(
              position: GridPosition(row: clueData.row, col: clueData.col),
              value: clueData.value
          )
      }

      rectangles = []
      colorIndex = 0
      validateGame()

      print("✅ Loaded Shikaku level: \(levelData.gridRows)x\(levelData.gridCols) with \(levelData.clues.count) clues")
  }

  func loadDefaultLevel() {
      // Fallback level if JSON loading fails
      gridSize = (rows: 5, cols: 5)
      numberClues = [
          NumberClue(position: GridPosition(row: 0, col: 0), value: 3),
          NumberClue(position: GridPosition(row: 0, col: 3), value: 4),
          NumberClue(position: GridPosition(row: 1, col: 0), value: 2),
          NumberClue(position: GridPosition(row: 3, col: 1), value: 4),
          NumberClue(position: GridPosition(row: 3, col: 2), value: 3),
          NumberClue(position: GridPosition(row: 2, col: 3), value: 2),
          NumberClue(position: GridPosition(row: 3, col: 4), value: 3),
          NumberClue(position: GridPosition(row: 4, col: 0), value: 2),
          NumberClue(position: GridPosition(row: 4, col: 2), value: 2)
      ]
      rectangles = []
      colorIndex = 0
      validateGame()

      print("⚠️ Loaded default Shikaku level")
  }


  // NEW: Function to validate a preview rectangle during dragging
  func validatePreviewRectangle(from start: GridPosition, to end: GridPosition) -> (isValid: Bool, color: Color) {
    let topLeft = GridPosition(
      row: min(start.row, end.row),
      col: min(start.col, end.col)
    )
    let bottomRight = GridPosition(
      row: max(start.row, end.row),
      col: max(start.col, end.col)
    )

    let previewRect = GameRectangle(topLeft: topLeft, bottomRight: bottomRight)

    // Check if this rectangle would be valid
    let containedClues = numberClues.filter { clue in
      previewRect.contains(position: clue.position)
    }

    let isValid = containedClues.count == 1 && containedClues.first?.value == previewRect.area

    // Return the next color from palette if valid, gray if invalid
    let nextColor = colorPalette[colorIndex % colorPalette.count]
    return (isValid: isValid, color: isValid ? nextColor : .gray)
  }

  func addOrUpdateRectangle(from start: GridPosition, to end: GridPosition) {
    let topLeft = GridPosition(
      row: min(start.row, end.row),
      col: min(start.col, end.col)
    )
    let bottomRight = GridPosition(
      row: max(start.row, end.row),
      col: max(start.col, end.col)
    )

    let nextColor = colorPalette[colorIndex % colorPalette.count]
    colorIndex += 1

    var newRect = GameRectangle(topLeft: topLeft, bottomRight: bottomRight)
    newRect.color = nextColor

    rectangles.removeAll { rect in
      overlaps(rect1: rect, rect2: newRect)
    }

    rectangles.append(newRect)
    validateGame()

    // Trigger haptic based on validation result
    if let lastRect = rectangles.last {
      triggerValidationHaptic(isValid: lastRect.isValid)
    }
  }

  func removeRectangle(at position: GridPosition) {
    rectangles.removeAll { rect in
      rect.contains(position: position)
    }
    validateGame()
  }

  private func overlaps(rect1: GameRectangle, rect2: GameRectangle) -> Bool {
    !(rect1.bottomRight.col < rect2.topLeft.col ||
      rect2.bottomRight.col < rect1.topLeft.col ||
      rect1.bottomRight.row < rect2.topLeft.row ||
      rect2.bottomRight.row < rect1.topLeft.row)
  }

  func validateGame() {
    for i in rectangles.indices {
      rectangles[i].isValid = validateRectangle(rectangles[i])
    }

    for i in numberClues.indices {
      numberClues[i].isSatisfied = isNumberClueSatisfied(numberClues[i])
    }

    isGameComplete = numberClues.allSatisfy { $0.isSatisfied } &&
    rectangles.allSatisfy { $0.isValid } &&
    isGridFullyCovered()
  }

  private func validateRectangle(_ rectangle: GameRectangle) -> Bool {
    let containedClues = numberClues.filter { clue in
      rectangle.contains(position: clue.position)
    }
    return containedClues.count == 1 && containedClues.first?.value == rectangle.area
  }

  private func isNumberClueSatisfied(_ clue: NumberClue) -> Bool {
    let containingRectangles = rectangles.filter { rect in
      rect.contains(position: clue.position)
    }
    return containingRectangles.count == 1 &&
    containingRectangles.first?.area == clue.value
  }

  func clearBoard() {
    rectangles = []
    colorIndex = 0
    validateGame()
  }

  func triggerSelectionHaptic() {
    lightImpact.impactOccurred()
  }

  func triggerValidationHaptic(isValid: Bool) {
    notificationFeedback.notificationOccurred(isValid ? .success : .error)
  }

  func triggerWinHaptic() {
    lightImpact.impactOccurred()
    lightImpact.impactOccurred()
  }

  private func isGridFullyCovered() -> Bool {
    for row in 0..<gridSize.rows {
      for col in 0..<gridSize.cols {
        let position = GridPosition(row: row, col: col)
        let coveringRectangles = rectangles.filter { $0.contains(position: position) }
        if coveringRectangles.count != 1 {
          return false
        }
      }
    }
    return true
  }
}

// MARK: - Supporting Data Models (Your exact models preserved)

struct GameRectangle {
  let topLeft: GridPosition
  let bottomRight: GridPosition
  var color: Color = .blue
  var isValid: Bool = false

  var area: Int {
    (bottomRight.row - topLeft.row + 1) * (bottomRight.col - topLeft.col + 1)
  }

  func contains(position: GridPosition) -> Bool {
    position.row >= topLeft.row && position.row <= bottomRight.row &&
    position.col >= topLeft.col && position.col <= bottomRight.col
  }
}

struct NumberClue {
  let position: GridPosition
  let value: Int
  var isSatisfied: Bool = false
}

struct GridPosition: Hashable {
  let row: Int
  let col: Int
}

extension GridPosition: Equatable {
  static func == (lhs: GridPosition, rhs: GridPosition) -> Bool {
    lhs.row == rhs.row && lhs.col == rhs.col
  }
}

// MARK: - GameSession Extension for Shikaku

extension GameSession {
    private static var gameInstances: [String: ShikakuGame] = [:]

    var game: ShikakuGame {
        // Use session ID as key to maintain unique game instances
        let sessionKey = "\(id.uuidString)"

        // Return existing game instance if it exists
        if let existingGame = Self.gameInstances[sessionKey] {
            return existingGame
        }

        // Create new game instance for this session
        let shikakuGame = ShikakuGame()

        // Load the actual level data if it's a Shikaku level
        if gameType == .shikaku {
            do {
                let levelData = try level.decode(as: ShikakuLevelData.self)
                shikakuGame.loadLevel(levelData)
                print("✅ Loaded Shikaku level: \(levelData.id)")
            } catch {
                print("❌ Failed to decode Shikaku level data: \(error)")
                // Fallback: create a default level
                shikakuGame.loadDefaultLevel()
            }
        } else {
            // For non-Shikaku games, load default
            shikakuGame.loadDefaultLevel()
        }

        // Store the game instance
        Self.gameInstances[sessionKey] = shikakuGame

        return shikakuGame
    }

    // Clean up game instance when session ends
    func cleanupGameInstance() {
        let sessionKey = "\(id.uuidString)"
        Self.gameInstances.removeValue(forKey: sessionKey)
    }
}
#Preview("Shikaku - Daily Challenge") {
  let mockLevel = try! AnyGameLevel(MockShikakuLevel(
    id: "shikaku_daily_1",
    difficulty: 3,
    estimatedTime: 180,
    gridRows: 5,
    gridCols: 5,
    clues: []
  ))

  let session = GameSession(
    gameType: .shikaku,
    level: mockLevel,
    context: .daily(Date())
  )

  ShikakuGameView(session: session)
    .environment(GameCoordinator())
}
