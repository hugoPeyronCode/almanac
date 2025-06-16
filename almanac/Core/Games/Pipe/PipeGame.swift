////
////  PipeGame.swift
////  almanac
////
////  Pipe game logic and state management
////
//
//import SwiftUI
//import Foundation
//
//// MARK: - Data Models
//enum PipeDirection: CaseIterable {
//    case up, down, left, right
//    
//    var opposite: PipeDirection {
//        switch self {
//        case .up: return .down
//        case .down: return .up
//        case .left: return .right
//        case .right: return .left
//        }
//    }
//}
//
//struct PipeConnection: Hashable {
//    let position: GridPosition
//    let direction: PipeDirection
//    
//    var adjacentPosition: GridPosition {
//        position.adjacent(in: direction)
//    }
//    
//    var returnDirection: PipeDirection {
//        direction.opposite
//    }
//}
//
//enum PipeTileType: String, CaseIterable, Codable {
//    case straight   
//    case corner     
//    case deadEnd    
//    case tJunction  
//    
//    func connections(rotation: Double) -> Set<PipeDirection> {
//        let normalizedRotation = Int(rotation / 90) % 4
//        
//        switch self {
//        case .straight:
//            return normalizedRotation % 2 == 0 ? [.left, .right] : [.up, .down]
//            
//        case .corner:
//            switch normalizedRotation {
//            case 0: return [.down, .right]
//            case 1: return [.left, .down]
//            case 2: return [.left, .up]
//            case 3: return [.up, .right]
//            default: return []
//            }
//            
//        case .tJunction:
//            switch normalizedRotation {
//            case 0: return [.left, .right, .down]
//            case 1: return [.up, .down, .left]
//            case 2: return [.left, .right, .up]
//            case 3: return [.up, .down, .right]
//            default: return []
//            }
//            
//        case .deadEnd:
//            switch normalizedRotation {
//            case 0: return [.right]
//            case 1: return [.up]
//            case 2: return [.left]
//            case 3: return [.down]
//            default: return []
//            }
//        }
//    }
//    
//    func symbol(rotation: Double) -> String {
//        let normalizedRotation = Int(rotation / 90) % 4
//        
//        switch self {
//        case .straight:
//            return normalizedRotation % 2 == 0 ? "━" : "┃"
//            
//        case .corner:
//            switch normalizedRotation {
//            case 0: return "┏"
//            case 1: return "┓"
//            case 2: return "┛"
//            case 3: return "┗"
//            default: return "┏"
//            }
//            
//        case .tJunction:
//            switch normalizedRotation {
//            case 0: return "┳"
//            case 1: return "┫"
//            case 2: return "┻"
//            case 3: return "┣"
//            default: return "┳"
//            }
//            
//        case .deadEnd:
//            switch normalizedRotation {
//            case 0: return "╶"
//            case 1: return "╷"
//            case 2: return "╴"
//            case 3: return "╵"
//            default: return "╶"
//            }
//        }
//    }
//}
//
//struct PipeTile {
//    let type: PipeTileType
//    let position: GridPosition
//    var rotation: Double = 0
//    var isLocked: Bool = false
//    
//    var connections: Set<PipeDirection> {
//        return type.connections(rotation: rotation)
//    }
//    
//    var symbol: String {
//        return type.symbol(rotation: rotation)
//    }
//    
//    mutating func rotate() {
//        rotation = (rotation + 90).truncatingRemainder(dividingBy: 360)
//    }
//}
//
//extension GridPosition {
//    func adjacent(in direction: PipeDirection) -> GridPosition {
//        switch direction {
//        case .up: return GridPosition(row: row - 1, col: col)
//        case .down: return GridPosition(row: row + 1, col: col)
//        case .left: return GridPosition(row: row, col: col - 1)
//        case .right: return GridPosition(row: row, col: col + 1)
//        }
//    }
//}
//
//// MARK: - Pipe Game Class
//@Observable
//class PipeGame {
//    var gridSize: (rows: Int, cols: Int) = (4, 4)
//    var tiles: [[PipeTile]] = []
//    var startPoint: GridPosition = GridPosition(row: 2, col: 2)
//    var endPoint: GridPosition = GridPosition(row: 0, col: 0)
//    private(set) var leakingConnections: Set<PipeConnection> = []
//    private(set) var connectedTiles: Set<GridPosition> = []
//    
//    init() {
//        initializeLevel(rows: 4, cols: 4)
//    }
//    
//    func initializeLevel(rows: Int, cols: Int) {
//        gridSize = (rows: rows, cols: cols)
//        startPoint = GridPosition(row: rows / 2, col: cols / 2)
//        endPoint = GridPosition(row: 0, col: 0)
//        generateLevel()
//        updateConnections()
//    }
//    
//    func loadLevel(from levelData: PipeLevelData) {
//        gridSize = (rows: levelData.gridRows, cols: levelData.gridCols)
//        startPoint = GridPosition(row: levelData.startRow, col: levelData.startCol)
//        endPoint = GridPosition(row: levelData.endRow, col: levelData.endCol)
//        
//        // Initialize tiles grid
//        tiles = Array(repeating: Array(repeating: PipeTile(type: .deadEnd, position: GridPosition(row: 0, col: 0)), count: gridSize.cols), count: gridSize.rows)
//        
//        // Load tiles from level data
//        for (rowIndex, row) in levelData.tiles.enumerated() {
//            for (colIndex, tileData) in row.enumerated() {
//                let position = GridPosition(row: rowIndex, col: colIndex)
//                tiles[rowIndex][colIndex] = PipeTile(
//                    type: PipeTileType(rawValue: tileData.type) ?? .deadEnd,
//                    position: position,
//                    rotation: tileData.rotation,
//                    isLocked: tileData.isLocked
//                )
//            }
//        }
//        
//        // Scramble non-locked tiles
//        scrambleRotations()
//        updateConnections()
//    }
//    
//    private func generateLevel() {
//        tiles = Array(repeating: Array(repeating: PipeTile(type: .deadEnd, position: GridPosition(row: 0, col: 0)), count: gridSize.cols), count: gridSize.rows)
//        
//        for row in 0..<gridSize.rows {
//            for col in 0..<gridSize.cols {
//                let position = GridPosition(row: row, col: col)
//                let tileType: PipeTileType = [.straight, .corner, .deadEnd, .tJunction].randomElement() ?? .straight
//                tiles[row][col] = PipeTile(type: tileType, position: position)
//            }
//        }
//        
//        // Set start point to a T-junction
//        tiles[startPoint.row][startPoint.col] = PipeTile(
//            type: .tJunction,
//            position: startPoint,
//            isLocked: true
//        )
//        
//        scrambleRotations()
//    }
//    
//    private func scrambleRotations() {
//        for row in 0..<gridSize.rows {
//            for col in 0..<gridSize.cols {
//                if !tiles[row][col].isLocked {
//                    let rotations = Int.random(in: 0...3)
//                    for _ in 0..<rotations {
//                        tiles[row][col].rotate()
//                    }
//                }
//            }
//        }
//    }
//    
//    func rotateTile(at position: GridPosition) {
//        guard isValidPosition(position) && !tiles[position.row][position.col].isLocked else { return }
//        
//        tiles[position.row][position.col].rotate()
//        updateConnections()
//    }
//    
//    private func isValidPosition(_ position: GridPosition) -> Bool {
//        return position.row >= 0 && position.row < gridSize.rows &&
//               position.col >= 0 && position.col < gridSize.cols
//    }
//    
//    func updateConnections() {
//        leakingConnections = []
//        connectedTiles = []
//        
//        findConnectedTiles()
//        findLeaks()
//    }
//    
//    private func findConnectedTiles() {
//        connectedTiles = []
//        var queue: [GridPosition] = [startPoint]
//        var visited: Set<GridPosition> = [startPoint]
//        
//        while !queue.isEmpty {
//            let currentPos = queue.removeFirst()
//            let currentTile = tiles[currentPos.row][currentPos.col]
//            
//            for direction in currentTile.connections {
//                let adjacentPos = currentPos.adjacent(in: direction)
//                
//                guard isValidPosition(adjacentPos) && !visited.contains(adjacentPos) else {
//                    continue
//                }
//                
//                let adjacentTile = tiles[adjacentPos.row][adjacentPos.col]
//                
//                if adjacentTile.connections.contains(direction.opposite) {
//                    visited.insert(adjacentPos)
//                    queue.append(adjacentPos)
//                    connectedTiles.insert(adjacentPos)
//                }
//            }
//        }
//    }
//    
//    private func findLeaks() {
//        for row in 0..<gridSize.rows {
//            for col in 0..<gridSize.cols {
//                let position = GridPosition(row: row, col: col)
//                let tile = tiles[row][col]
//                
//                for direction in tile.connections {
//                    let connection = PipeConnection(position: position, direction: direction)
//                    let adjacentPos = connection.adjacentPosition
//                    
//                    // Check if connection goes out of bounds
//                    guard isValidPosition(adjacentPos) else {
//                        leakingConnections.insert(connection)
//                        continue
//                    }
//                    
//                    let adjacentTile = tiles[adjacentPos.row][adjacentPos.col]
//                    
//                    // Check if adjacent tile connects back
//                    if !adjacentTile.connections.contains(connection.returnDirection) {
//                        leakingConnections.insert(connection)
//                    }
//                }
//            }
//        }
//    }
//    
//    func checkWin() -> Bool {
//        updateConnections()
//        
//        // Win if no leaks and the end point is connected
//        return leakingConnections.isEmpty && (connectedTiles.contains(endPoint) || endPoint == startPoint)
//    }
//    
//    func hasLeak(at position: GridPosition) -> Bool {
//        return leakingConnections.contains { connection in
//            connection.position == position
//        }
//    }
//    
//    func isConnectedToStart(at position: GridPosition) -> Bool {
//        return connectedTiles.contains(position) || position == startPoint
//    }
//}
//
//// MARK: - GameProtocol Implementation
//extension PipeGame: GameProtocol {
//    typealias StateData = PipeStateData
//    
//    var isCompleted: Bool {
//        return checkWin()
//    }
//    
//    func getStateData() -> PipeStateData {
//        let tilesData = tiles.map { row in
//            row.map { PipeTileData(from: $0) }
//        }
//        
//        return PipeStateData(
//            tiles: tilesData,
//            startPoint: startPoint,
//            endPoint: endPoint,
//            isCompleted: checkWin()
//        )
//    }
//    
//    func restoreFromStateData(_ data: PipeStateData) {
//        self.startPoint = data.startPoint
//        self.endPoint = data.endPoint
//        
//        // Restore tiles
//        self.tiles = data.tiles.map { row in
//            row.map { $0.toPipeTile() }
//        }
//        
//        // Update grid size
//        if !data.tiles.isEmpty {
//            self.gridSize = (rows: data.tiles.count, cols: data.tiles[0].count)
//        }
//        
//        // Update connections
//        updateConnections()
//    }
//    
//    func reset() {
//        // Reset all tiles to initial rotation
//        for row in 0..<gridSize.rows {
//            for col in 0..<gridSize.cols {
//                if !tiles[row][col].isLocked {
//                    tiles[row][col].rotation = 0
//                }
//            }
//        }
//        
//        // Update connections
//        updateConnections()
//    }
//}
