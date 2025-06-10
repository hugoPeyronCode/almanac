//
//  PipeLevelEditor.swift
//  almanac
//
//  Manual level editor for Pipe game
//

import SwiftUI

@Observable
class PipeLevelEditor {
  var gridSize: Int = 4
  var grid: [[PipePiece]] = []
  var sourcePosition: GridPosition = GridPosition(row: 2, col: 2)
  var selectedPipeType: PipeType = .straight
  var isPlacingSource: Bool = false

  init() {
    resetGrid()
  }

  func resetGrid() {
    sourcePosition = GridPosition(row: gridSize / 2, col: gridSize / 2)
    grid = Array(repeating: Array(repeating: PipePiece(type: .deadEnd, rotation: 0), count: gridSize), count: gridSize)
  }

  func setGridSize(_ size: Int) {
    // Valide la taille
    guard size >= 3 && size <= 10 else { return }

    // Met à jour de manière atomique
    gridSize = size
    sourcePosition = GridPosition(row: size / 2, col: size / 2)

    // Recrée complètement la grille
    var newGrid: [[PipePiece]] = []
    for _ in 0..<size {
      var row: [PipePiece] = []
      for _ in 0..<size {
        row.append(PipePiece(type: .deadEnd, rotation: 0))
      }
      newGrid.append(row)
    }
    grid = newGrid
  }

  func placePipe(at position: GridPosition) {
    guard isValidPosition(position) &&
            position.row < grid.count &&
            position.col < grid[position.row].count else {
      print("Position invalide: \(position), gridSize: \(gridSize), grid.count: \(grid.count)")
      return
    }

    if isPlacingSource {
      sourcePosition = position
      isPlacingSource = false
    } else {
      grid[position.row][position.col] = PipePiece(type: selectedPipeType, rotation: 0)
    }
  }

  func rotatePipe(at position: GridPosition) {
    guard isValidPosition(position) &&
            position.row < grid.count &&
            position.col < grid[position.row].count else {
      print("Rotation impossible à la position: \(position)")
      return
    }
    grid[position.row][position.col].rotate()
  }

  private func isValidPosition(_ position: GridPosition) -> Bool {
    return position.row >= 0 && position.row < gridSize &&
    position.col >= 0 && position.col < gridSize
  }

  func exportToJSON() -> String {
    let levelData = CustomPipeLevelData(
      id: "custom_level_\(Date().timeIntervalSince1970)",
      difficulty: 1,
      gridSize: gridSize,
      sourcePosition: sourcePosition,
      pipes: grid.enumerated().flatMap { rowIndex, row in
        row.enumerated().compactMap { colIndex, pipe in
          return CustomPipeLevelData.PipeData(
            row: rowIndex,
            col: colIndex,
            type: pipe.type,
            rotation: pipe.rotation
          )
        }
      }
    )

    do {
      let jsonData = try JSONEncoder().encode(levelData)
      return String(data: jsonData, encoding: .utf8) ?? "Error encoding JSON"
    } catch {
      return "Error: \(error.localizedDescription)"
    }
  }
}

// MARK: - Data Models for Export

struct CustomPipeLevelData: Codable {
  let id: String
  let difficulty: Int
  let gridSize: Int
  let sourcePosition: GridPosition
  let pipes: [PipeData]

  struct PipeData: Codable {
    let row: Int
    let col: Int
    let type: PipeType
    let rotation: Int
  }
}

// MARK: - Codable conformance handled in main Models file

// MARK: - Level Editor View

struct PipeLevelEditorView: View {
  @State private var editor = PipeLevelEditor()
  @State private var showingJSON = false
  @State private var jsonOutput = ""
  @State private var isGridReady = true
  @State private var showingTestLevel = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      VStack(spacing: 20) {
        // Header
        Text("Éditeur de Niveau Pipe")
          .font(.title2)
          .fontWeight(.bold)

        // Grid Size Selector
        gridSizeSelector

        // Tool Selector
        toolSelector

        Spacer()

        // Editor Grid
        editorGridView

        Spacer()

        // Actions
        actionButtons
      }
      .padding()
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Fermer") {
            dismiss()
          }
        }
      }
    }
    .sheet(isPresented: $showingJSON) {
      JSONExportView(jsonString: jsonOutput)
    }
    .fullScreenCover(isPresented: $showingTestLevel) {
      PipeLevelTestView(levelData: editor.exportToJSON())
    }
  }

  // MARK: - Components

  private var gridSizeSelector: some View {
    VStack(spacing: 8) {
      Text("Taille de la grille")
        .font(.headline)

      HStack(spacing: 12) {
        ForEach([4, 5, 6, 8], id: \.self) { size in
          Button("\(size)×\(size)") {
            isGridReady = false
            DispatchQueue.main.async {
              editor.setGridSize(size)
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isGridReady = true
              }
            }
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(editor.gridSize == size ? Color.blue : Color.gray.opacity(0.2))
          .foregroundStyle(editor.gridSize == size ? .white : .primary)
          .cornerRadius(8)
        }
      }
    }
  }

  private var toolSelector: some View {
    VStack(spacing: 12) {
      Text("Outils")
        .font(.headline)

      // Source Placer
      Button(action: {
        editor.isPlacingSource.toggle()
      }) {
        HStack {
          Text("💧")
          Text("Placer Source")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(editor.isPlacingSource ? Color.blue : Color.gray.opacity(0.2))
        .foregroundStyle(editor.isPlacingSource ? .white : .primary)
        .cornerRadius(8)
      }

      // Pipe Type Selector
      HStack(spacing: 8) {
        ForEach(PipeType.allCases, id: \.self) { pipeType in
          Button(action: {
            editor.selectedPipeType = pipeType
            editor.isPlacingSource = false
          }) {
            VStack(spacing: 4) {
              Text(pipeType.symbol(rotation: 0))
                .font(.title2)
              Text(pipeTypeName(pipeType))
                .font(.caption2)
            }
            .padding(8)
            .background(editor.selectedPipeType == pipeType ? Color.green : Color.gray.opacity(0.2))
            .foregroundStyle(editor.selectedPipeType == pipeType ? .white : .primary)
            .cornerRadius(8)
          }
        }
      }
    }
  }

  private var editorGridView: some View {
    VStack(spacing: 4) {
      if isGridReady && editor.grid.count == editor.gridSize &&
          editor.grid.allSatisfy({ $0.count == editor.gridSize }) {
        ForEach(0..<editor.gridSize, id: \.self) { row in
          HStack(spacing: 4) {
            ForEach(0..<editor.gridSize, id: \.self) { col in
              let position = GridPosition(row: row, col: col)
              let pipe = editor.grid[row][col]

              EditorCellView(
                pipe: pipe,
                isSource: position == editor.sourcePosition,
                isPlacingSource: editor.isPlacingSource,
                onTap: {
                  editor.placePipe(at: position)
                },
                onLongPress: {
                  editor.rotatePipe(at: position)
                }
              )
            }
          }
        }
      } else {
        // Placeholder pendant la reconstruction de la grille
        VStack {
          ProgressView()
          Text("Mise à jour de la grille...")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(width: 200, height: 200)
      }
    }
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(.gray.opacity(0.1))
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(.gray.opacity(0.3), lineWidth: 1)
        )
    )
  }

  private var actionButtons: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        Button("Réinitialiser") {
          editor.resetGrid()
        }
        .buttonStyle(.bordered)

        Button("🎮 Tester") {
          showingTestLevel = true
        }
        .buttonStyle(.borderedProminent)

        Button("Exporter JSON") {
          jsonOutput = editor.exportToJSON()
          showingJSON = true
        }
        .buttonStyle(.bordered)
      }

      Text("Tap = Placer • Long Press = Faire tourner")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private func pipeTypeName(_ type: PipeType) -> String {
    switch type {
    case .straight: return "Droit"
    case .corner: return "Coin"
    case .deadEnd: return "Cul-de-sac"
    case .tJunction: return "T-junction"
    }
  }
}

// MARK: - Editor Cell View

struct EditorCellView: View {
  let pipe: PipePiece
  let isSource: Bool
  let isPlacingSource: Bool
  let onTap: () -> Void
  let onLongPress: () -> Void

  var body: some View {
    Button(action: onTap) {
      ZStack {
        // Background
        RoundedRectangle(cornerRadius: 8)
          .fill(backgroundColor)
          .frame(width: cellSize, height: cellSize)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(borderColor, lineWidth: borderWidth)
          )

        // Pipe Symbol
        Text(pipe.symbol)
          .font(.system(size: 20, weight: .bold, design: .monospaced))
          .foregroundStyle(pipeColor)

        // Source Indicator
        if isSource {
          Text("💧")
            .font(.caption)
            .offset(x: -12, y: -12)
        }

        // Placement Guide
        if isPlacingSource {
          Text("📍")
            .font(.caption2)
            .offset(x: 12, y: 12)
        }
      }
    }
    .buttonStyle(.plain)
    .simultaneousGesture(
      LongPressGesture(minimumDuration: 0.5)
        .onEnded { _ in
          onLongPress()
        }
    )
  }

  private var cellSize: CGFloat {
    UIScreen.main.bounds.width / 8 // Adaptive size
  }

  private var backgroundColor: Color {
    if isSource {
      return .blue.opacity(0.3)
    } else if isPlacingSource {
      return .yellow.opacity(0.2)
    } else {
      return .gray.opacity(0.1)
    }
  }

  private var borderColor: Color {
    if isSource {
      return .blue
    } else if isPlacingSource {
      return .yellow
    } else {
      return .gray.opacity(0.4)
    }
  }

  private var borderWidth: CGFloat {
    isSource ? 2 : 1
  }

  private var pipeColor: Color {
    if isSource {
      return .blue
    } else {
      return .primary
    }
  }
}

// MARK: - JSON Export View

struct JSONExportView: View {
  let jsonString: String
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      VStack(spacing: 20) {
        Text("JSON du Niveau")
          .font(.headline)

        ScrollView {
          Text(jsonString)
            .font(.system(.caption, design: .monospaced))
            .padding()
            .background(.gray.opacity(0.1))
            .cornerRadius(8)
        }

        Button("Copier") {
          UIPasteboard.general.string = jsonString
        }
        .buttonStyle(.borderedProminent)
      }
      .padding()
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Fermer") {
            dismiss()
          }
        }
      }
    }
  }
}

// MARK: - Level Test View

struct PipeLevelTestView: View {
  let levelData: String
  @State private var game: PipeGame?
  @State private var gameTimer = GameTimer()
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      if let game = game {
        VStack(spacing: 20) {
          HStack {
            CloseButton {
              dismiss()
            }

            Spacer()

            Text("🎮 Test du Niveau")
              .font(.headline)
              .fontWeight(.medium)

            Spacer()

            Text(Duration.seconds(gameTimer.displayTime), format: .time(pattern: .minuteSecond))
              .contentTransition(.numericText())
              .font(.headline)
              .fontWeight(.medium)
          }
          .padding(.horizontal)

          // Instructions
          VStack(spacing: 8) {
            Text("Connectez tous les tuyaux à la source d'eau 💧")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)

            HStack(spacing: 16) {
              if game.totalLeaks > 0 {
                Text("\(game.totalLeaks) fuite\(game.totalLeaks > 1 ? "s" : "")")
                  .font(.caption)
                  .foregroundStyle(.red)
                  .fontWeight(.medium)
              }

              let connectedCount = game.connectedToPipes.count
              let totalPipes = (game.gridSize * game.gridSize) - 1

              if connectedCount == totalPipes && game.totalLeaks == 0 {
                Text("✅ Tous connectés !")
                  .font(.caption)
                  .foregroundStyle(.green)
                  .fontWeight(.medium)
              } else {
                Text("\(connectedCount)/\(totalPipes) connectés")
                  .font(.caption)
                  .foregroundStyle(.blue)
                  .fontWeight(.medium)
              }
            }
          }
          .padding(.horizontal)

          Spacer()

          // Game Grid
          VStack(spacing: 4) {
            ForEach(0..<game.gridSize, id: \.self) { row in
              HStack(spacing: 4) {
                ForEach(0..<game.gridSize, id: \.self) { col in
                  let position = GridPosition(row: row, col: col)
                  let pipe = game.grid[row][col]

                  PipeCellView(
                    pipe: pipe,
                    hasLeaks: game.hasLeaks(at: position),
                    isConnectedToSource: game.isConnectedToSource(at: position),
                    isSource: position == game.sourcePosition
                  ) {
                    game.rotatePipe(at: position)
                  }
                }
              }
            }
          }
          .padding()
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(.gray.opacity(0.1))
              .overlay(
                RoundedRectangle(cornerRadius: 16)
                  .stroke(.gray.opacity(0.3), lineWidth: 1)
              )
          )

          Spacer()

          // Controls
          VStack(spacing: 12) {
            if game.isComplete {
              Text("🎉 Niveau Complété !")
                .font(.headline)
                .foregroundStyle(.green)
                .fontWeight(.bold)
            }

            Button("Nouveau Test") {
              setupGame()
            }
            .buttonStyle(.borderedProminent)
          }
        }
        .padding()
      } else {
        ProgressView("Chargement du niveau...")
      }
    }
    .onAppear {
      setupGame()
      gameTimer.startTimer()
    }
    .onDisappear {
      gameTimer.stopTimer()
    }
  }

  private func setupGame() {
    guard let data = levelData.data(using: .utf8),
          let customLevel = try? JSONDecoder().decode(CustomPipeLevelData.self, from: data) else {
      print("Erreur: Impossible de décoder le niveau de test")
      return
    }

    // Crée un jeu temporaire avec ces données
    let tempGame = PipeGame(gridSize: customLevel.gridSize)
    tempGame.sourcePosition = customLevel.sourcePosition

    // Charge les tuyaux
    for pipeData in customLevel.pipes {
      if pipeData.row < tempGame.gridSize && pipeData.col < tempGame.gridSize {
        tempGame.grid[pipeData.row][pipeData.col] = PipePiece(type: pipeData.type, rotation: pipeData.rotation)
      }
    }

    // Mélange les rotations pour créer le défi
    tempGame.scrambleRotationsOnly()
    tempGame.validateSystem()

    game = tempGame
    gameTimer.reset()
  }
}
