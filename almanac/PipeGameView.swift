//
//  PipeGameView.swift
//  Multi-Game Puzzle App
//
//  Simple pipe connection puzzle game
//

import SwiftUI

struct PipeGameView: View {
    @Environment(GameCoordinator.self) private var coordinator
    @State private var gameState = SimplePipeGame()
    @State private var showingWin = false

    private let session: GameSession

    init(session: GameSession) {
        self.session = session
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button("Exit") {
                    coordinator.dismissFullScreen()
                }
                .foregroundStyle(.blue)

                Spacer()

                Text("Pipe Game")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Text(session.formattedPlayTime)
                    .font(.headline)
                    .monospacedDigit()
            }
            .padding()

            // Instructions
            Text("Tap pipes to rotate them. Connect 💧 to 🎯")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()

            // Game Grid
            VStack(spacing: 8) {
                ForEach(0..<gameState.gridSize, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<gameState.gridSize, id: \.self) { col in
                            SimplePipeCell(
                                pipe: gameState.grid[row][col],
                                isConnected: gameState.isConnected[row][col],
                                isStart: row == 0 && col == 0,
                                isEnd: row == gameState.gridSize-1 && col == gameState.gridSize-1
                            ) {
                                gameState.rotatePipe(row: row, col: col)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.gray.opacity(0.1))
            )
            .padding()

            Spacer()

            // Debug and Controls
            VStack(spacing: 12) {
                // Debug button
                DebugCompleteButton(session: session, label: "Force Win")
                    .disabled(session.isCompleted)
                
                HStack(spacing: 20) {
                    Button("Reset") {
                        gameState.reset()
                    }
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    if gameState.isComplete {
                        Text("🎉 Complete!")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding()
        }
        .alert("Puzzle Complete!", isPresented: $showingWin) {
            Button("Continue") {
                session.complete()
                coordinator.dismissFullScreen()
            }
        }
        .onChange(of: gameState.isComplete) { _, complete in
            if complete {
                showingWin = true
            }
        }
    }
}

// MARK: - Simple Pipe Cell

struct SimplePipeCell: View {
    let pipe: SimplePipe
    let isConnected: Bool
    let isStart: Bool
    let isEnd: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .frame(width: 60, height: 60)

                // Pipe symbol
                Text(pipeSymbol)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(isConnected ? .green : .gray)

                // Start/End markers
                if isStart {
                    Text("💧")
                        .offset(x: -20, y: -20)
                }
                if isEnd {
                    Text("🎯")
                        .offset(x: 20, y: 20)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(1.0)
        .animation(.spring(duration: 0.2), value: pipe.rotation)
    }

    private var backgroundColor: Color {
        if isConnected {
            return .green.opacity(0.2)
        } else {
            return .gray.opacity(0.1)
        }
    }

    private var pipeSymbol: String {
        switch pipe.type {
        case .straight:
            return pipe.rotation % 2 == 0 ? "━" : "┃"
        case .corner:
            switch pipe.rotation % 4 {
            case 0: return "┏"
            case 1: return "┓"
            case 2: return "┛"
            case 3: return "┗"
            default: return "┏"
            }
        case .tJunction:
            switch pipe.rotation % 4 {
            case 0: return "┳"
            case 1: return "┫"
            case 2: return "┻"
            case 3: return "┣"
            default: return "┳"
            }
        case .cross:
            return "╋"
        case .deadEnd:
            switch pipe.rotation % 4 {
            case 0: return "╶" // connects right only
            case 1: return "╷" // connects up only
            case 2: return "╴" // connects left only
            case 3: return "╵" // connects down only
            default: return "╶"
            }
        }
    }
}

// MARK: - Simple Game Logic

@Observable
class SimplePipeGame {
    let gridSize = 4
    var grid: [[SimplePipe]] = []
    var isConnected: [[Bool]] = []
    var isComplete = false

    init() {
        generateSpecificLevel()
        checkConnections()
    }

    private func generateSpecificLevel() {
        // Create the exact level from the original screenshot - recreating the solvable puzzle
        grid = [
            // Row 0: [Corner, Straight, Corner, Straight] - from screenshot
            [
                SimplePipe(type: .corner, rotation: 0), // ┏ (connects down+right)
                SimplePipe(type: .straight, rotation: 0), // ━ (connects left+right)
                SimplePipe(type: .corner, rotation: 1), // ┓ (connects left+down)
                SimplePipe(type: .deadEnd, rotation: 0)  // ╶ (connects only left - cul-de-sac)
            ],
            // Row 1: [Straight, tJunction, Corner, Straight]
            [
                SimplePipe(type: .straight, rotation: 1), // ┃ (connects up+down)
                SimplePipe(type: .tJunction, rotation: 3), // ┣ (connects up+down+right)
                SimplePipe(type: .corner, rotation: 2), // ┛ (connects left+up)
                SimplePipe(type: .straight, rotation: 1)  // ┃ (connects up+down)
            ],
            // Row 2: [Corner, Cross, Corner, Corner]
            [
                SimplePipe(type: .corner, rotation: 0), // ┏ (connects down+right)
                SimplePipe(type: .cross, rotation: 0), // ╋ (connects all directions)
                SimplePipe(type: .corner, rotation: 3), // ┗ (connects up+right)
                SimplePipe(type: .corner, rotation: 2)  // ┛ (connects left+up)
            ],
            // Row 3: [deadEnd, Straight, deadEnd, Corner]
            [
                SimplePipe(type: .deadEnd, rotation: 1), // ╷ (connects only up - cul-de-sac)
                SimplePipe(type: .straight, rotation: 1), // ┃ (connects up+down)
                SimplePipe(type: .deadEnd, rotation: 1), // ╷ (connects only up - cul-de-sac)
                SimplePipe(type: .corner, rotation: 2)  // ┛ (connects left+up) - TARGET
            ]
        ]

        // Initialize connection matrix
        isConnected = Array(repeating: Array(repeating: false, count: gridSize), count: gridSize)

        // Scramble the pipes but keep some easier
        scramblePipes()
    }

    private func scramblePipes() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                // Don't scramble start position
                if row == 0 && col == 0 {
                    grid[row][col].rotation = Int.random(in: 0...1) // Light scrambling
                }
                // Don't completely scramble target
                else if row == gridSize-1 && col == gridSize-1 {
                    grid[row][col].rotation = Int.random(in: 0...2) // Medium scrambling
                }
                // Scramble others normally
                else {
                    grid[row][col].rotation = Int.random(in: 0...3)
                }
            }
        }
    }

    func rotatePipe(row: Int, col: Int) {
        print("🔄 Rotating pipe at (\(row), \(col))")
        grid[row][col].rotation = (grid[row][col].rotation + 1) % 4
        checkConnections()
    }

    func reset() {
        generateSpecificLevel()
        checkConnections()
    }

    private func checkConnections() {
        // Reset all connections
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                isConnected[row][col] = false
            }
        }

        // Start flood fill from (0,0)
        var visited: Set<String> = []
        floodFill(row: 0, col: 0, visited: &visited)

        // Check if end position is connected
        isComplete = isConnected[gridSize-1][gridSize-1]

        // Debug: Print current connections
        print("🔍 Current connections:")
        for row in 0..<gridSize {
            let rowString = (0..<gridSize).map { col in
                isConnected[row][col] ? "✅" : "❌"
            }.joined(separator: " ")
            print("Row \(row): \(rowString)")
        }
        print("🎯 End connected: \(isComplete)")
    }

    private func floodFill(row: Int, col: Int, visited: inout Set<String>) {
        let key = "\(row),\(col)"
        if visited.contains(key) || row < 0 || row >= gridSize || col < 0 || col >= gridSize {
            return
        }

        visited.insert(key)
        isConnected[row][col] = true

        let currentPipe = grid[row][col]
        let connections = getPipeConnections(pipe: currentPipe)

        print("🔧 Pipe at (\(row),\(col)) type:\(currentPipe.type) rotation:\(currentPipe.rotation) connects to: \(connections)")

        // Check each direction this pipe connects to
        for direction in connections {
            let (newRow, newCol) = getAdjacentPosition(row: row, col: col, direction: direction)

            if newRow >= 0 && newRow < gridSize && newCol >= 0 && newCol < gridSize && !visited.contains("\(newRow),\(newCol)") {
                let neighborPipe = grid[newRow][newCol]
                let neighborConnections = getPipeConnections(pipe: neighborPipe)
                let oppositeDirection = getOppositeDirection(direction)

                print("  🔗 Checking neighbor at (\(newRow),\(newCol)) - connects back via \(oppositeDirection)? \(neighborConnections.contains(oppositeDirection))")

                // Check if neighbor connects back to us
                if neighborConnections.contains(oppositeDirection) {
                    print("  ✅ Connection confirmed!")
                    floodFill(row: newRow, col: newCol, visited: &visited)
                } else {
                    print("  ❌ No connection back")
                }
            }
        }
    }

    private func getPipeConnections(pipe: SimplePipe) -> [Direction] {
        switch pipe.type {
        case .straight:
            return pipe.rotation % 2 == 0 ? [.left, .right] : [.up, .down]
        case .corner:
            switch pipe.rotation % 4 {
            case 0: return [.down, .right] // ┏
            case 1: return [.left, .down] // ┓
            case 2: return [.left, .up] // ┛
            case 3: return [.up, .right] // ┗
            default: return []
            }
        case .tJunction:
            switch pipe.rotation % 4 {
            case 0: return [.left, .right, .down] // ┳
            case 1: return [.up, .down, .left] // ┫
            case 2: return [.left, .right, .up] // ┻
            case 3: return [.up, .down, .right] // ┣
            default: return []
            }
        case .cross:
            return [.up, .down, .left, .right]
        case .deadEnd:
            switch pipe.rotation % 4 {
            case 0: return [.right] // ╶
            case 1: return [.up] // ╷
            case 2: return [.left] // ╴
            case 3: return [.down] // ╵
            default: return []
            }
        }
    }

    private func getAdjacentPosition(row: Int, col: Int, direction: Direction) -> (Int, Int) {
        switch direction {
        case .up: return (row - 1, col)
        case .down: return (row + 1, col)
        case .left: return (row, col - 1)
        case .right: return (row, col + 1)
        }
    }

    private func getOppositeDirection(_ direction: Direction) -> Direction {
        switch direction {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }
}

enum Direction {
    case up, down, left, right
}

// MARK: - Simple Data Models

struct SimplePipe {
    let type: PipeType
    var rotation: Int
}

enum PipeType: CaseIterable {
    case straight
    case corner
    case tJunction
    case cross
    case deadEnd
}
