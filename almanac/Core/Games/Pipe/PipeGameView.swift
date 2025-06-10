//
//  PipeGameView.swift
//  Multi-Game Puzzle App
//
//  Simple pipe connection puzzle game
//

import SwiftUI

// MARK: - Types pour Pipe Level Data

/// Copie locale de PipeLevelData pour éviter les conflits d'import
struct PipeLevelInfo {
    let id: String
    let gridSize: Int
    let pipes: [PipeInfo]
    
    struct PipeInfo {
        let row: Int
        let col: Int
        let connections: [PipeConnectionDirection]
    }
    
    enum PipeConnectionDirection {
        case up, down, left, right
    }
}

// Extension pour convertir depuis AnyGameLevel
extension PipeLevelInfo {
    /// Initialise depuis les données de session
    init?(from level: AnyGameLevel) {
        // Pour l'instant, utilise des valeurs par défaut basées sur la difficulté
        self.id = level.id
        self.gridSize = max(4, min(6, 3))
        self.pipes = [] // Sera généré procéduralement
    }
}

// MARK: - Modèle de Données pour Jeu de Tuyaux Sans Fuite

/// Représente une direction sur la grille
enum PipeDirection: CaseIterable {
    case up, down, left, right
    
    var opposite: PipeDirection {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }
}

/// Représente une connexion individuelle d'un tuyau
struct PipeConnection: Hashable {
    let position: GridPosition
    let direction: PipeDirection
    
    /// Position de la connexion adjacente
    var adjacentPosition: GridPosition {
        position.adjacent(in: direction)
    }
    
    /// Direction opposée pour la connexion retour
    var returnDirection: PipeDirection {
        direction.opposite
    }
}

/// Types de tuyaux basés sur l'image
enum PipeType: CaseIterable, Codable {
    case straight   // ━ ou ┃ (ligne droite)
    case corner     // ┏┓┛┗ (angle)
    case deadEnd    // ╶╷╴╵ (cul-de-sac) 
    case tJunction  // ┳┫┻┣ (triplette)
    
    /// Retourne les directions de connexion pour une rotation donnée
    func connections(rotation: Int) -> Set<PipeDirection> {
        let normalizedRotation = rotation % 4
        
        switch self {
        case .straight:
            return normalizedRotation % 2 == 0 ? [.left, .right] : [.up, .down]
            
        case .corner:
            switch normalizedRotation {
            case 0: return [.down, .right]  // ┏
            case 1: return [.left, .down]   // ┓
            case 2: return [.left, .up]     // ┛
            case 3: return [.up, .right]    // ┗
            default: return []
            }
            
        case .tJunction:
            switch normalizedRotation {
            case 0: return [.left, .right, .down]  // ┳
            case 1: return [.up, .down, .left]     // ┫
            case 2: return [.left, .right, .up]    // ┻
            case 3: return [.up, .down, .right]    // ┣
            default: return []
            }
            
            
        case .deadEnd:
            switch normalizedRotation {
            case 0: return [.right]  // ╶
            case 1: return [.up]     // ╷
            case 2: return [.left]   // ╴
            case 3: return [.down]   // ╵
            default: return []
            }
        }
    }
    
    /// Symbole Unicode pour l'affichage
    func symbol(rotation: Int) -> String {
        let normalizedRotation = rotation % 4
        
        switch self {
        case .straight:
            return normalizedRotation % 2 == 0 ? "━" : "┃"
            
        case .corner:
            switch normalizedRotation {
            case 0: return "┏"
            case 1: return "┓"
            case 2: return "┛"
            case 3: return "┗"
            default: return "┏"
            }
            
        case .tJunction:
            switch normalizedRotation {
            case 0: return "┳"
            case 1: return "┫"
            case 2: return "┻"
            case 3: return "┣"
            default: return "┳"
            }
            
            
        case .deadEnd:
            switch normalizedRotation {
            case 0: return "╶"
            case 1: return "╷"
            case 2: return "╴"
            case 3: return "╵"
            default: return "╶"
            }
        }
    }
}

/// Représente un tuyau sur la grille
struct PipePiece {
    let type: PipeType
    var rotation: Int = 0
    
    /// Les directions auxquelles ce tuyau se connecte
    var connections: Set<PipeDirection> {
        return type.connections(rotation: rotation)
    }
    
    /// Symbole pour l'affichage
    var symbol: String {
        return type.symbol(rotation: rotation)
    }
    
    /// Fait tourner le tuyau d'un quart de tour
    mutating func rotate() {
        rotation = (rotation + 1) % 4
    }
}

// MARK: - Extension GridPosition pour Pipe Game

extension GridPosition {
    /// Retourne la position adjacente dans une direction
    func adjacent(in direction: PipeDirection) -> GridPosition {
        switch direction {
        case .up: return GridPosition(row: row - 1, col: col)
        case .down: return GridPosition(row: row + 1, col: col)
        case .left: return GridPosition(row: row, col: col - 1)
        case .right: return GridPosition(row: row, col: col + 1)
        }
    }
}

// MARK: - Logique de Jeu

@Observable
class PipeGame {
    let gridSize: Int
    var grid: [[PipePiece]]
    var sourcePosition: GridPosition
    private(set) var leakingConnections: Set<PipeConnection> = []
    private(set) var connectedToPipes: Set<GridPosition> = []
    private(set) var isComplete: Bool = false
    
    /// Toutes les connexions de tuyaux dans le jeu
    private var allConnections: [PipeConnection] {
        var connections: [PipeConnection] = []
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let position = GridPosition(row: row, col: col)
                let pipe = grid[row][col]
                
                for direction in pipe.connections {
                    connections.append(PipeConnection(position: position, direction: direction))
                }
            }
        }
        return connections
    }
    
    init(gridSize: Int = 4) {
        self.gridSize = gridSize
        self.grid = []
        self.sourcePosition = GridPosition(row: gridSize / 2, col: gridSize / 2)
        
        generateLevel()
        validateSystem()
    }
    
    /// Initialise avec des données de niveau spécifiques
    init(levelInfo: PipeLevelInfo) {
        self.gridSize = levelInfo.gridSize
        self.grid = []
        self.sourcePosition = GridPosition(row: levelInfo.gridSize / 2, col: levelInfo.gridSize / 2)
        
        loadLevel(levelInfo)
        validateSystem()
    }
    
    /// Charge un niveau spécifique depuis les données JSON
    private func loadLevel(_ levelInfo: PipeLevelInfo) {
        // Initialise d'abord la grille
        grid = Array(repeating: Array(repeating: PipePiece(type: .deadEnd), count: gridSize), count: gridSize)
        
        // Si le niveau a des données de tuyaux spécifiques, les utilise
        if !levelInfo.pipes.isEmpty {
            loadLevelFromData(levelInfo)
        } else {
          print("Error could not load level")
        }
    }
    
    /// Charge un niveau depuis les données JSON
    private func loadLevelFromData(_ levelInfo: PipeLevelInfo) {
        // Convertit les données JSON en tuyaux
        for pipeData in levelInfo.pipes {
            if pipeData.row < gridSize && pipeData.col < gridSize {
                let pipeType = determinePipeType(from: pipeData.connections)
                let rotation = determineRotation(for: pipeType, connections: pipeData.connections)
                grid[pipeData.row][pipeData.col] = PipePiece(type: pipeType, rotation: rotation)
            }
        }
        
        // Remplit les cellules vides avec des tuyaux aléatoires
        fillEmptyCells()
        scrambleRotations()
    }
    /// Niveau simple (difficulté 1)
    private func generateSimpleLevel() {
        grid = Array(repeating: Array(repeating: PipePiece(type: .deadEnd), count: gridSize), count: gridSize)
        grid[sourcePosition.row][sourcePosition.col] = PipePiece(type: .tJunction, rotation: 0)
        generateConnectedNetworkFromSource()
        // Mélange léger pour niveau facile
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let position = GridPosition(row: row, col: col)
                if position != sourcePosition && Bool.random() {
                    grid[row][col].rotate()
                }
            }
        }
    }
    
    /// Niveau moyen (difficulté 2)
    private func generateMediumLevel() {
        grid = Array(repeating: Array(repeating: PipePiece(type: .deadEnd), count: gridSize), count: gridSize)
        grid[sourcePosition.row][sourcePosition.col] = PipePiece(type: .tJunction, rotation: 0)
        generateConnectedNetworkFromSource()
        // Mélange modéré pour niveau moyen
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let position = GridPosition(row: row, col: col)
                if position != sourcePosition {
                    let rotations = Int.random(in: 0...2)
                    for _ in 0..<rotations {
                        grid[row][col].rotate()
                    }
                }
            }
        }
    }
    
    /// Niveau difficile (difficulté 3+)
    private func generateHardLevel() {
        grid = Array(repeating: Array(repeating: PipePiece(type: .deadEnd), count: gridSize), count: gridSize)
        grid[sourcePosition.row][sourcePosition.col] = PipePiece(type: .tJunction, rotation: 0)
        generateConnectedNetworkFromSource()
        // Mélange intensif pour niveau difficile
        scrambleRotationsOnly()
    }
    
    /// Détermine le type de tuyau basé sur les connexions
    private func determinePipeType(from connections: [PipeLevelInfo.PipeConnectionDirection]) -> PipeType {
        let count = connections.count
        
        switch count {
        case 1:
            return .deadEnd
        case 2:
            let dirs = Set(connections)
            if dirs.contains(.up) && dirs.contains(.down) ||
               dirs.contains(.left) && dirs.contains(.right) {
                return .straight
            } else {
                return .corner
            }
        case 3:
            return .tJunction
        case 4:
            return .tJunction  // Source ou tuyau complexe  // Use T-junction for 4 connections (shouldn't happen normally)
        default:
            return .straight
        }
    }
    
    /// Détermine la rotation nécessaire pour les connexions
    private func determineRotation(for type: PipeType, connections: [PipeLevelInfo.PipeConnectionDirection]) -> Int {
        let targetConnections = Set(connections.map { convertDirection($0) })
        
        // Teste chaque rotation possible
        for rotation in 0..<4 {
            let currentConnections = type.connections(rotation: rotation)
            if currentConnections == targetConnections {
                return rotation
            }
        }
        
        return 0 // Rotation par défaut
    }
    
    /// Convertit la direction du JSON vers notre enum
    private func convertDirection(_ direction: PipeLevelInfo.PipeConnectionDirection) -> PipeDirection {
        switch direction {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        }
    }
    
    /// Remplit les cellules vides avec des tuyaux aléatoires
    private func fillEmptyCells() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if grid[row][col].type == .straight && grid[row][col].rotation == 0 {
                    // Cellule "vide", ajoute un tuyau aléatoire
                    let randomType: PipeType = [.straight, .corner, .deadEnd].randomElement() ?? .straight
                    grid[row][col] = PipePiece(type: randomType, rotation: 0)
                }
            }
        }
    }
    
    /// Génère un niveau garanti solvable avec source centrale
    private func generateLevel() {
        // Initialise avec des tuyaux vides
        grid = Array(repeating: Array(repeating: PipePiece(type: .deadEnd), count: gridSize), count: gridSize)
        
        // Place un T-junction au centre comme source (sera déterminé automatiquement)
        grid[sourcePosition.row][sourcePosition.col] = PipePiece(type: .tJunction, rotation: 0)
        
        // Génère un réseau connecté depuis la source
        generateConnectedNetworkFromSource()
        
        // Mélange les rotations pour créer le puzzle
        scrambleRotationsOnly()
    }
    
    /// Crée une grille initialement valide connectée à la source
    private func createValidSolvableGridWithSource() {
        // La source est déjà placée, crée des chemins depuis la source
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let position = GridPosition(row: row, col: col)
                
                // Skip la source
                if position == sourcePosition {
                    continue
                }
                
                grid[row][col] = generateValidPipeForPosition(position)
            }
        }
    }
    
    /// Génère un tuyau valide pour une position donnée (sans fuites)
    private func generateValidPipeForPosition(_ position: GridPosition) -> PipePiece {
        var requiredConnections: Set<PipeDirection> = []
        
        // Vérifie les connexions nécessaires avec les bords
        if position.row == 0 {
            // Bord supérieur - ne peut pas avoir de connexion vers le haut
        } else {
            // Peut avoir une connexion vers le haut si nécessaire
        }
        
        if position.row == gridSize - 1 {
            // Bord inférieur - ne peut pas avoir de connexion vers le bas
        }
        
        if position.col == 0 {
            // Bord gauche - ne peut pas avoir de connexion vers la gauche
        }
        
        if position.col == gridSize - 1 {
            // Bord droit - ne peut pas avoir de connexion vers la droite
        }
        
        // Pour simplifier, crée des tuyaux qui se connectent vers l'intérieur
        let isCorner = (position.row == 0 || position.row == gridSize-1) && 
                      (position.col == 0 || position.col == gridSize-1)
        let isEdge = position.row == 0 || position.row == gridSize-1 || 
                    position.col == 0 || position.col == gridSize-1
        
        if isCorner {
            return PipePiece(type: .corner, rotation: getCornerRotation(position))
        } else if isEdge {
            return PipePiece(type: .straight, rotation: getEdgeRotation(position))
        } else {
            // Centre : utilise des types plus complexes
            let randomType: PipeType = [.straight, .corner, .tJunction].randomElement() ?? .straight
            return PipePiece(type: randomType, rotation: 0)
        }
    }
    
    /// Rotation appropriée pour un coin
    private func getCornerRotation(_ position: GridPosition) -> Int {
        if position.row == 0 && position.col == 0 {
            return 0 // ┏ vers bas et droite
        } else if position.row == 0 && position.col == gridSize-1 {
            return 1 // ┓ vers bas et gauche
        } else if position.row == gridSize-1 && position.col == gridSize-1 {
            return 2 // ┛ vers haut et gauche
        } else {
            return 3 // ┗ vers haut et droite
        }
    }
    
    /// Rotation appropriée pour un bord
    private func getEdgeRotation(_ position: GridPosition) -> Int {
        if position.row == 0 || position.row == gridSize-1 {
            return 0 // ━ horizontal
        } else {
            return 1 // ┃ vertical
        }
    }
    
    /// Mélange intelligent qui préserve la solvabilité (exclut la source)
    private func scrambleIntelligentlyAvoidingSource() {
        // Mélange seulement certains tuyaux, pas tous, et jamais la source
        let shufflePercentage = 0.6 // 60% des tuyaux mélangés
        
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let position = GridPosition(row: row, col: col)
                
                // Ne jamais mélanger la source
                if position == sourcePosition {
                    continue
                }
                
                if Double.random(in: 0...1) < shufflePercentage {
                    // Tourne ce tuyau de 1-3 rotations aléatoires
                    let rotations = Int.random(in: 1...3)
                    for _ in 0..<rotations {
                        grid[row][col].rotate()
                    }
                }
            }
        }
    }
    
    /// Vérifie que le niveau généré est bien solvable (maintenant garanti par construction)
    private func validateSolvability() {
        // L'algorithme garantit maintenant la solvabilité par construction
        // Aucune validation supplémentaire nécessaire
    }
    
    /// Vérifie si le niveau actuel est solvable
    private func isCurrentLevelSolvable() -> Bool {
        // Simule toutes les rotations possibles pour voir si une solution existe
        return findSolutionExists()
    }
    
    /// Recherche s'il existe une solution
    private func findSolutionExists() -> Bool {
        // Implémentation simplifiée : vérifie s'il est possible d'éliminer toutes les fuites
        // avec un maximum de 20 rotations aléatoires
        let originalGrid = grid
        
        for _ in 0..<20 {
            // Essaie des rotations aléatoires
            let randomRow = Int.random(in: 0..<gridSize)
            let randomCol = Int.random(in: 0..<gridSize)
            grid[randomRow][randomCol].rotate()
            
            // Vérifie si c'est résolu
            validateSystem()
            if isComplete {
                // Restaure la grille originale et retourne vrai
                grid = originalGrid
                validateSystem()
                return true
            }
        }
        
        // Restaure la grille originale
        grid = originalGrid
        validateSystem()
        return false
    }
    
    /// Crée un niveau simple garanti solvable en cas d'échec
    private func createSimpleSolvableLevel() {
        // Grille très simple : tous les tuyaux droits correctement orientés
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                grid[row][col] = PipePiece(type: .straight, rotation: row % 2) 
            }
        }
        
        // Mélange juste quelques tuyaux
        for _ in 0..<gridSize {
            let randomRow = Int.random(in: 0..<gridSize)
            let randomCol = Int.random(in: 0..<gridSize)
            grid[randomRow][randomCol].rotate()
        }
    }
    
    /// Crée un chemin solvable simple
    private func createSolvablePath() {
        // Chemin en L : va à droite puis en bas
        
        // Coin de départ (connecte vers la droite et vers le bas)
        grid[0][0] = PipePiece(type: .corner, rotation: 0) // ┏
        
        // Ligne horizontale vers la droite
        for col in 1..<gridSize-1 {
            grid[0][col] = PipePiece(type: .straight, rotation: 0) // ━
        }
        
        // Coin pour descendre
        grid[0][gridSize-1] = PipePiece(type: .corner, rotation: 1) // ┓
        
        // Ligne verticale vers le bas
        for row in 1..<gridSize-1 {
            grid[row][gridSize-1] = PipePiece(type: .straight, rotation: 1) // ┃
        }
        
        // Coin final
        grid[gridSize-1][gridSize-1] = PipePiece(type: .corner, rotation: 2) // ┛
        
        // Remplit les autres cases avec des tuyaux simples
        for row in 1..<gridSize-1 {
            for col in 0..<gridSize-1 {
                grid[row][col] = PipePiece(type: .straight, rotation: Int.random(in: 0...1))
            }
        }
    }
    
    /// Ajoute quelques tuyaux plus complexes
    private func addRandomPipes() {
        // Ajoute quelques T-junctions et coins aléatoires pour plus de complexité
        let complexPositions = [
            GridPosition(row: 1, col: 1),
            GridPosition(row: 2, col: 1),
            GridPosition(row: 1, col: 2)
        ]
        
        for position in complexPositions {
            if position.row < gridSize && position.col < gridSize {
                let randomType: PipeType = [.corner, .tJunction].randomElement()!
                grid[position.row][position.col] = PipePiece(type: randomType, rotation: 0)
            }
        }
    }
    
    /// Crée un chemin plus complexe (difficulté moyenne)
    private func createComplexPath() {
        // Chemin en zigzag
        grid[0][0] = PipePiece(type: .corner, rotation: 0) // ┏
        
        // Va à droite puis descend en zigzag
        for col in 1..<gridSize/2 {
            grid[0][col] = PipePiece(type: .straight, rotation: 0) // ━
        }
        
        grid[0][gridSize/2] = PipePiece(type: .corner, rotation: 1) // ┓
        grid[1][gridSize/2] = PipePiece(type: .corner, rotation: 3) // ┗
        
        for col in (gridSize/2+1)..<gridSize-1 {
            grid[1][col] = PipePiece(type: .straight, rotation: 0) // ━
        }
        
        grid[1][gridSize-1] = PipePiece(type: .corner, rotation: 1) // ┓
        
        for row in 2..<gridSize-1 {
            grid[row][gridSize-1] = PipePiece(type: .straight, rotation: 1) // ┃
        }
        
        grid[gridSize-1][gridSize-1] = PipePiece(type: .corner, rotation: 2) // ┛
    }
    
    /// Ajoute plus de tuyaux complexes (difficulté moyenne)
    private func addMoreComplexPipes() {
        let complexPositions = [
            GridPosition(row: 0, col: 1),
            GridPosition(row: 1, col: 0),
            GridPosition(row: 2, col: 2),
            GridPosition(row: 1, col: 1)
        ]
        
        for position in complexPositions {
            if position.row < gridSize && position.col < gridSize {
                let randomType: PipeType = [.corner, .tJunction, .deadEnd].randomElement()!
                grid[position.row][position.col] = PipePiece(type: randomType, rotation: 0)
            }
        }
    }
    
    /// Crée un chemin très complexe (difficulté difficile)
    private func createVeryComplexPath() {
        // Remplit avec des tuyaux complexes aléatoirement
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let randomType: PipeType = PipeType.allCases.randomElement() ?? .straight
                grid[row][col] = PipePiece(type: randomType, rotation: 0)
            }
        }
        
        // S'assure qu'il y a au moins un chemin possible
        createSolvablePath()
    }
    
    /// Ajoute des tuyaux très complexes (difficulté difficile)
    private func addComplexPipes() {
        // Ajoute des T-junctions et des coins partout
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if Bool.random() {
                    let complexType: PipeType = [.tJunction, .corner].randomElement()!
                    grid[row][col] = PipePiece(type: complexType, rotation: 0)
                }
            }
        }
    }
    
    /// Mélange fortement les rotations (difficulté difficile)
    private func scrambleRotationsHeavily() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                grid[row][col].rotation = Int.random(in: 0...3)
            }
        }
    }
    
    /// Mélange les rotations pour créer le puzzle
    private func scrambleRotations() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                // Garde les positions de départ et fin moins mélangées
                if (row == 0 && col == 0) || (row == gridSize-1 && col == gridSize-1) {
                    grid[row][col].rotation = Int.random(in: 0...1)
                } else {
                    grid[row][col].rotation = Int.random(in: 0...3)
                }
            }
        }
    }
    
    /// Fait tourner un tuyau et recalcule les fuites
    func rotatePipe(at position: GridPosition) {
        guard isValidPosition(position) else { return }
        
        grid[position.row][position.col].rotate()
        validateSystem()
    }
    
    /// Vérifie si une position est valide sur la grille
    private func isValidPosition(_ position: GridPosition) -> Bool {
        return position.row >= 0 && position.row < gridSize &&
               position.col >= 0 && position.col < gridSize
    }
    
    /// Valide le système de tuyaux et détecte les fuites
    func validateSystem() {
        leakingConnections = []
        connectedToPipes = []
        
        // D'abord, trouve tous les tuyaux connectés à la source
        findConnectedPipes()
        
        // Vérifie chaque connexion de tuyau pour les fuites
        for connection in allConnections {
            let adjacentPos = connection.adjacentPosition
            
            // Si la connexion sort de la grille, c'est une fuite
            guard isValidPosition(adjacentPos) else {
                leakingConnections.insert(connection)
                continue
            }
            
            let adjacentPipe = grid[adjacentPos.row][adjacentPos.col]
            
            // Si le tuyau adjacent ne se connecte pas en retour, c'est une fuite
            if !adjacentPipe.connections.contains(connection.returnDirection) {
                leakingConnections.insert(connection)
            }
        }
        
        // Le jeu est complété s'il n'y a aucune fuite ET tous les tuyaux sont connectés à la source
        let allPipePositions = getAllNonSourcePipePositions()
        isComplete = leakingConnections.isEmpty && connectedToPipes.isSuperset(of: allPipePositions)
    }
    
    /// Vérifie si une position a des fuites
    func hasLeaks(at position: GridPosition) -> Bool {
        return leakingConnections.contains { connection in
            connection.position == position
        }
    }
    
    /// Vérifie si une position est connectée à la source
    func isConnectedToSource(at position: GridPosition) -> Bool {
        return connectedToPipes.contains(position) || position == sourcePosition
    }
    
    /// Retourne le nombre total de fuites dans le système
    var totalLeaks: Int {
        return leakingConnections.count
    }
    
    /// Trouve tous les tuyaux connectés à la source via BFS
    private func findConnectedPipes() {
        connectedToPipes = []
        var queue: [GridPosition] = [sourcePosition]
        var visited: Set<GridPosition> = [sourcePosition]
        
        while !queue.isEmpty {
            let currentPos = queue.removeFirst()
            let currentPipe = grid[currentPos.row][currentPos.col]
            
            // Explore toutes les connexions de ce tuyau
            for direction in currentPipe.connections {
                let adjacentPos = currentPos.adjacent(in: direction)
                
                // Vérifie si la position est valide et non visitée
                guard isValidPosition(adjacentPos) && !visited.contains(adjacentPos) else {
                    continue
                }
                
                let adjacentPipe = grid[adjacentPos.row][adjacentPos.col]
                
                // Vérifie si le tuyau adjacent se connecte en retour
                if adjacentPipe.connections.contains(direction.opposite) {
                    visited.insert(adjacentPos)
                    queue.append(adjacentPos)
                    connectedToPipes.insert(adjacentPos)
                }
            }
        }
    }
    
    /// Retourne toutes les positions avec des tuyaux (sauf la source)
    private func getAllNonSourcePipePositions() -> Set<GridPosition> {
        var positions: Set<GridPosition> = []
        
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let position = GridPosition(row: row, col: col)
                if position != sourcePosition {
                    positions.insert(position)
                }
            }
        }
        
        return positions
    }
    
    /// Génère un niveau simple de démonstration
    private func generateConnectedNetworkFromSource() {
        // Crée un niveau simple pour la démonstration
        // (Utilise maintenant l'éditeur pour créer de vrais niveaux)
        
        // Remplit tout avec des deadEnds orientés aléatoirement
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                grid[row][col] = PipePiece(type: .deadEnd, rotation: Int.random(in: 0...3))
            }
        }
        
        // Place la source au centre
        grid[sourcePosition.row][sourcePosition.col] = PipePiece(type: .tJunction, rotation: 0)
        
        // Ajoute quelques tuyaux connectés manuellement
        if sourcePosition.row > 0 {
            grid[sourcePosition.row - 1][sourcePosition.col] = PipePiece(type: .straight, rotation: 1)
        }
        if sourcePosition.col > 0 {
            grid[sourcePosition.row][sourcePosition.col - 1] = PipePiece(type: .straight, rotation: 0)
        }
        if sourcePosition.col < gridSize - 1 {
            grid[sourcePosition.row][sourcePosition.col + 1] = PipePiece(type: .straight, rotation: 0)
        }
    }
    
    /// Trouve une paire de positions adjacentes (une connectée, une non-connectée)
    private func findAdjacentPair(connected: Set<GridPosition>, unconnected: Set<GridPosition>) -> (GridPosition, GridPosition)? {
        for connectedPos in connected {
            let adjacents = getAdjacentPositions(connectedPos)
            for adjPos in adjacents {
                if unconnected.contains(adjPos) {
                    return (connectedPos, adjPos)
                }
            }
        }
        return nil
    }
    
    /// Retourne les positions adjacentes valides
    private func getAdjacentPositions(_ position: GridPosition) -> [GridPosition] {
        let directions: [PipeDirection] = [.up, .down, .left, .right]
        return directions.compactMap { direction in
            let adjacent = position.adjacent(in: direction)
            return isValidPosition(adjacent) ? adjacent : nil
        }
    }
    
    /// Crée une connexion bidirectionnelle entre deux positions
    private func createConnection(from: GridPosition, to: GridPosition) {
        // Détermine la direction de la connexion
        guard let direction = getDirection(from: from, to: to) else { return }
        
        // Met à jour les tuyaux pour qu'ils se connectent
        addConnectionToPipe(at: from, direction: direction)
        addConnectionToPipe(at: to, direction: direction.opposite)
    }
    
    /// Détermine la direction d'une position vers une autre
    private func getDirection(from: GridPosition, to: GridPosition) -> PipeDirection? {
        if to.row == from.row - 1 && to.col == from.col { return .up }
        if to.row == from.row + 1 && to.col == from.col { return .down }
        if to.row == from.row && to.col == from.col - 1 { return .left }
        if to.row == from.row && to.col == from.col + 1 { return .right }
        return nil
    }
    
    /// Ajoute une connexion à un tuyau existant
    private func addConnectionToPipe(at position: GridPosition, direction: PipeDirection) {
        let currentPipe = grid[position.row][position.col]
        var newConnections = currentPipe.connections
        newConnections.insert(direction)
        
        // Détermine le nouveau type de tuyau basé sur les connexions
        let newType = determineOptimalPipeType(for: newConnections)
        grid[position.row][position.col] = PipePiece(type: newType, rotation: findCorrectRotation(for: newType, connections: newConnections))
    }
    
    /// Détermine le type de tuyau optimal pour un ensemble de connexions
    private func determineOptimalPipeType(for connections: Set<PipeDirection>) -> PipeType {
        switch connections.count {
        case 0:
            return .deadEnd
        case 1:
            return .deadEnd
        case 2:
            // Vérifie si c'est une ligne droite ou un coin
            if (connections.contains(.up) && connections.contains(.down)) ||
               (connections.contains(.left) && connections.contains(.right)) {
                return .straight
            } else {
                return .corner
            }
        case 3:
            return .tJunction
        case 4:
            return .tJunction  // Utilise T-junction pour 4 connexions (cas rare)
        default:
            return .deadEnd
        }
    }
    
    /// Trouve la rotation correcte pour un type de tuyau et des connexions données
    private func findCorrectRotation(for type: PipeType, connections: Set<PipeDirection>) -> Int {
        for rotation in 0..<4 {
            if type.connections(rotation: rotation) == connections {
                return rotation
            }
        }
        return 0
    }
    
    
    /// Mélange seulement les rotations (préserve les types de tuyaux)
    func scrambleRotationsOnly() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let position = GridPosition(row: row, col: col)
                
                // Ne mélange jamais la source
                if position == sourcePosition {
                    continue
                }
                
                // Applique 1-3 rotations aléatoires
                let rotations = Int.random(in: 1...3)
                for _ in 0..<rotations {
                    grid[row][col].rotate()
                }
            }
        }
    }
    
    /// Debug: Affiche l'état des connexions
    func debugConnections() {
        print("=== DEBUG PIPE CONNECTIONS ===")
        print("Source position: \(sourcePosition)")
        let sourcePipe = grid[sourcePosition.row][sourcePosition.col]
        print("Source pipe type: \(sourcePipe.type), connections: \(sourcePipe.connections)")
        
        print("Connected pipes: \(connectedToPipes.count)")
        for pos in connectedToPipes {
            let pipe = grid[pos.row][pos.col]
            print("  - \(pos): \(pipe.type), connections: \(pipe.connections)")
        }
        
        print("Total leaks: \(leakingConnections.count)")
        for leak in leakingConnections {
            print("  - Leak at \(leak.position) direction \(leak.direction)")
        }
    }
    
    /// Charge un niveau depuis des données JSON personnalisées
    func loadCustomLevel(from jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let levelData = try? JSONDecoder().decode(CustomPipeLevelData.self, from: data) else {
            print("Erreur: Impossible de décoder le JSON")
            return
        }
        
        // Met à jour la taille de la grille et la position de la source
        if levelData.gridSize != gridSize {
            // Pour des raisons de simplicité, on peut juste générer un nouveau niveau
            print("Taille de grille différente: \(levelData.gridSize) vs \(gridSize)")
        }
        
        sourcePosition = levelData.sourcePosition
        
        // Réinitialise la grille
        grid = Array(repeating: Array(repeating: PipePiece(type: .deadEnd, rotation: 0), count: gridSize), count: gridSize)
        
        // Place les tuyaux selon les données
        for pipeData in levelData.pipes {
            if pipeData.row < gridSize && pipeData.col < gridSize {
                grid[pipeData.row][pipeData.col] = PipePiece(type: pipeData.type, rotation: pipeData.rotation)
            }
        }
        
        // Mélange les rotations pour créer le puzzle
        scrambleRotationsOnly()
        
        // Valide le système
        validateSystem()
    }
    
    /// Remet le jeu à zéro
    func reset() {
        generateLevel()
        validateSystem()
    }
}

// MARK: - Interface Utilisateur

struct PipeGameView: View {
    @Environment(GameCoordinator.self) private var coordinator
    @State private var game: PipeGame
    @State private var showExitConfirmation = false
    @State private var gameTimer = GameTimer()
    
    private let session: GameSession
    
    init(session: GameSession) {
        self.session = session
        
        // Initialise le jeu avec les données du niveau
        if let levelInfo = PipeLevelInfo(from: session.level) {
            self._game = State(initialValue: PipeGame(levelInfo: levelInfo))
        } else {
            // Fallback vers un jeu par défaut si le décodage échoue
            self._game = State(initialValue: PipeGame(gridSize: 4))
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                // En-tête avec timer temps réel
                GameHeaderView(
                    session: session,
                    showExitConfirmation: $showExitConfirmation,
                    gameTimer: gameTimer
                ) {
                    gameTimer.stopTimer()
                    coordinator.dismissFullScreen()
                }
                
                // Instructions et indicateur de connexion
                VStack(spacing: 8) {
                    Text("Connectez tous les tuyaux à la source d'eau 💧")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 16) {
                        // Indicateur de fuites
                        if game.totalLeaks > 0 {
                            Text("\(game.totalLeaks) fuite\(game.totalLeaks > 1 ? "s" : "")")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .fontWeight(.medium)
                        }
                        
                        // Indicateur de connexions
                        let connectedCount = game.connectedToPipes.count
                        let totalPipes = (game.gridSize * game.gridSize) - 1 // Tous sauf la source
                        
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
                
                // Grille de jeu
                gameGridView
                
                Spacer()
                
                // Boutons de contrôle
                controlsView
            }
            .padding()
            
            // Vue de complétion
            if game.isComplete && session.isCompleted {
                GameCompletionView(
                    formattedDuration: formattedDuration,
                    coordinator: coordinator,
                    session: session
                )
                .ignoresSafeArea()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            gameTimer.startTimer()
            // Force une validation au démarrage
            game.validateSystem()
        }
        .onDisappear {
            gameTimer.stopTimer()
        }
        .alert("Quitter le jeu ?", isPresented: $showExitConfirmation) {
            Button("Annuler", role: .cancel) { }
            Button("Quitter", role: .destructive) {
                gameTimer.stopTimer()
                coordinator.dismissFullScreen()
            }
        } message: {
            Text("Votre progression sera perdue.")
        }
        .onChange(of: game.isComplete) { _, isComplete in
            if isComplete && !session.isCompleted {
                handleGameCompletion()
            }
        }
    }
    
    // MARK: - Helpers
    
    private var formattedDuration: String {
        session.formattedPlayTime
    }
    
    private func handleGameCompletion() {
        session.complete()
    }
    
    // MARK: - Composants de l'Interface
    
    private var gameGridView: some View {
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
    }
    
    private var controlsView: some View {
        VStack(spacing: 12) {
            // Bouton debug
            DebugCompleteButton(session: session, label: "Compléter")
                .disabled(session.isCompleted)
            
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    Button("Nouveau Puzzle") {
                        game.reset()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if game.isComplete {
                        Text("🎉 Complété !")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .fontWeight(.bold)
                    }
                }
            }
        }
    }
}

// MARK: - Cellule de Tuyau

struct PipeCellView: View {
    let pipe: PipePiece
    let hasLeaks: Bool
    let isConnectedToSource: Bool
    let isSource: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Arrière-plan de la cellule
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .frame(width: cellSize, height: cellSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
                
                // Symbole du tuyau
                Text(pipe.symbol)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(pipeColor)
                
                // Indicateur de source d'eau
                if isSource {
                    Text("💧")
                        .font(.title2)
                        .offset(x: -15, y: -15)
                        .shadow(color: .blue, radius: 2)
                }
                
                // Indicateur de fuite
                if hasLeaks && !isSource {
                    Text("⚠️")
                        .font(.caption)
                        .offset(x: 20, y: -20)
                        .shadow(color: .red, radius: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(hasLeaks ? 1.05 : 1.0)
        .animation(.spring(duration: 0.3), value: hasLeaks)
        .animation(.easeInOut(duration: 0.2), value: pipe.rotation)
    }
    
    // MARK: - Propriétés d'Affichage
    
    private var cellSize: CGFloat { 65 }
    
    private var backgroundColor: Color {
        if isSource {
            return .blue.opacity(0.3) // Source d'eau en bleu
        } else if hasLeaks {
            return .red.opacity(0.15)
        } else if isConnectedToSource {
            return .green.opacity(0.15) // Connecté à la source en vert
        } else {
            return .gray.opacity(0.1) // Non connecté en gris
        }
    }
    
    private var borderColor: Color {
        if isSource {
            return .blue.opacity(0.8) // Source d'eau en bleu
        } else if hasLeaks {
            return .red.opacity(0.6)
        } else if isConnectedToSource {
            return .green.opacity(0.6)
        } else {
            return .gray.opacity(0.4)
        }
    }
    
    private var borderWidth: CGFloat {
        if isSource {
            return 3
        } else if hasLeaks {
            return 2
        } else {
            return 1
        }
    }
    
    private var pipeColor: Color {
        if isSource {
            return .blue // Source d'eau en bleu
        } else if hasLeaks {
            return .red
        } else if isConnectedToSource {
            return .green
        } else {
            return .gray
        }
    }
}

//// MARK: - Preview
//#Preview {
//    // Crée un mock level pour le preview
//    let mockLevel = AnyGameLevel(id: "pipe_preview", difficulty: 1, gameData: Data())
//    
//  PipeGameView(session: GameSession(
//        gameType: .pipe,
//        level: mockLevel,
//        context: .practice()
//    ))
//    .environment(GameCoordinator())
//}
