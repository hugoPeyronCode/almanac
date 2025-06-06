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
    let difficulty: Int
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
        self.difficulty = level.difficulty
        self.gridSize = max(4, min(6, 3 + level.difficulty))
        self.pipes = [] // Sera généré procéduralement
    }
}

// MARK: - Modèle de Données Simple

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

/// Types de tuyaux avec leurs connexions possibles
enum PipeType: CaseIterable {
    case straight   // ━ ou ┃
    case corner     // ┏┓┛┗
    case tJunction  // ┳┫┻┣
    case cross      // ╋
    case deadEnd    // ╶╷╴╵
    
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
            
        case .cross:
            return [.up, .down, .left, .right]
            
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
            
        case .cross:
            return "╋"
            
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
    private(set) var grid: [[PipePiece]]
    private(set) var connectedPipes: Set<GridPosition>
    private(set) var isComplete: Bool = false
    
    let startPosition: GridPosition
    let endPosition: GridPosition
    
    init(gridSize: Int = 4) {
        self.gridSize = gridSize
        self.startPosition = GridPosition(row: 0, col: 0)
        self.endPosition = GridPosition(row: gridSize - 1, col: gridSize - 1)
        self.grid = []
        self.connectedPipes = []
        
        generateLevel()
        calculateConnections()
    }
    
    /// Initialise avec des données de niveau spécifiques
    init(levelInfo: PipeLevelInfo) {
        self.gridSize = levelInfo.gridSize
        self.startPosition = GridPosition(row: 0, col: 0)
        self.endPosition = GridPosition(row: gridSize - 1, col: gridSize - 1)
        self.grid = []
        self.connectedPipes = []
        
        loadLevel(levelInfo)
        calculateConnections()
    }
    
    /// Charge un niveau spécifique depuis les données JSON
    private func loadLevel(_ levelInfo: PipeLevelInfo) {
        // Si le niveau a des données de tuyaux spécifiques, les utilise
        if !levelInfo.pipes.isEmpty {
            loadLevelFromData(levelInfo)
        } else {
            // Sinon génère un niveau basé sur la difficulté
            generateLevelForDifficulty(levelInfo.difficulty)
        }
    }
    
    /// Charge un niveau depuis les données JSON
    private func loadLevelFromData(_ levelInfo: PipeLevelInfo) {
        grid = Array(repeating: Array(repeating: PipePiece(type: .straight), count: gridSize), count: gridSize)
        
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
    
    /// Génère un niveau basé sur la difficulté
    private func generateLevelForDifficulty(_ difficulty: Int) {
        switch difficulty {
        case 1:
            generateSimpleLevel()
        case 2:
            generateMediumLevel()
        case 3...:
            generateHardLevel()
        default:
            generateSimpleLevel()
        }
    }
    
    /// Niveau simple (difficulté 1)
    private func generateSimpleLevel() {
        grid = Array(repeating: Array(repeating: PipePiece(type: .straight), count: gridSize), count: gridSize)
        createSolvablePath()
        addRandomPipes()
        scrambleRotations()
    }
    
    /// Niveau moyen (difficulté 2)
    private func generateMediumLevel() {
        grid = Array(repeating: Array(repeating: PipePiece(type: .straight), count: gridSize), count: gridSize)
        createComplexPath()
        addMoreComplexPipes()
        scrambleRotations()
    }
    
    /// Niveau difficile (difficulté 3+)
    private func generateHardLevel() {
        grid = Array(repeating: Array(repeating: PipePiece(type: .straight), count: gridSize), count: gridSize)
        createVeryComplexPath()
        addComplexPipes()
        scrambleRotationsHeavily()
    }
    
    /// Détermine le type de tuyau basé sur les connexions
    private func determinePipeType(from connections: [PipeLevelInfo.PipeConnectionDirection]) -> PipeType {
        let count = connections.count
        
        switch count {
        case 1:
            return .deadEnd
        case 2:
            // Vérifie si c'est un coin ou une ligne droite
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
            return .cross
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
    
    /// Génère un niveau simple et solvable
    private func generateLevel() {
        grid = Array(repeating: Array(repeating: PipePiece(type: .straight), count: gridSize), count: gridSize)
        
        // Crée un chemin simple et solvable du coin supérieur gauche au coin inférieur droit
        createSolvablePath()
        
        // Ajoute quelques tuyaux aléatoires pour la complexité
        addRandomPipes()
        
        // Mélange les rotations pour créer le puzzle
        scrambleRotations()
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
                let randomType: PipeType = [.corner, .tJunction, .cross].randomElement()!
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
        // Ajoute des T-junctions et des croix partout
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if Bool.random() {
                    let complexType: PipeType = [.tJunction, .cross].randomElement()!
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
    
    /// Fait tourner un tuyau et recalcule les connexions
    func rotatePipe(at position: GridPosition) {
        guard isValidPosition(position) else { return }
        
        grid[position.row][position.col].rotate()
        calculateConnections()
    }
    
    /// Vérifie si une position est valide sur la grille
    private func isValidPosition(_ position: GridPosition) -> Bool {
        return position.row >= 0 && position.row < gridSize &&
               position.col >= 0 && position.col < gridSize
    }
    
    /// Calcule quels tuyaux sont connectés à partir du point de départ
    private func calculateConnections() {
        connectedPipes = []
        var toVisit: [GridPosition] = [startPosition]
        var visited: Set<GridPosition> = []
        
        while !toVisit.isEmpty {
            let currentPos = toVisit.removeFirst()
            
            if visited.contains(currentPos) {
                continue
            }
            
            visited.insert(currentPos)
            connectedPipes.insert(currentPos)
            
            let currentPipe = grid[currentPos.row][currentPos.col]
            
            // Vérifie chaque direction de connexion du tuyau actuel
            for direction in currentPipe.connections {
                let neighborPos = currentPos.adjacent(in: direction)
                
                guard isValidPosition(neighborPos) && !visited.contains(neighborPos) else {
                    continue
                }
                
                let neighborPipe = grid[neighborPos.row][neighborPos.col]
                
                // Vérifie si le voisin se connecte en retour
                if neighborPipe.connections.contains(direction.opposite) {
                    toVisit.append(neighborPos)
                }
            }
        }
        
        // Le jeu est complété si la position finale est connectée
        isComplete = connectedPipes.contains(endPosition)
    }
    
    /// Remet le jeu à zéro
    func reset() {
        generateLevel()
        calculateConnections()
    }
    
    /// Vérifie si une position est connectée
    func isConnected(_ position: GridPosition) -> Bool {
        return connectedPipes.contains(position)
    }
}

// MARK: - Interface Utilisateur

struct PipeGameView: View {
    @Environment(GameCoordinator.self) private var coordinator
    @State private var game: PipeGame
    @State private var showingWin = false
    
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
        VStack(spacing: 20) {
            // En-tête avec boutons de contrôle
            headerView
            
            // Instructions
            Text("Connectez 💧 à 🎯 en faisant tourner les tuyaux")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Grille de jeu
            gameGridView
            
            Spacer()
            
            // Boutons de contrôle
            controlsView
        }
        .padding()
        .alert("Puzzle Résolu!", isPresented: $showingWin) {
            Button("Continuer") {
                session.complete()
                coordinator.dismissFullScreen()
            }
        } message: {
            Text("Bravo ! Vous avez connecté toutes les tuyaux !")
        }
        .onChange(of: game.isComplete) { _, isComplete in
            if isComplete {
                showingWin = true
            }
        }
    }
    
    // MARK: - Composants de l'Interface
    
    private var headerView: some View {
        HStack {
            Button("Quitter") {
                coordinator.dismissFullScreen()
            }
            .foregroundStyle(.red)
            
            Spacer()
            
            Text("Pipe Game")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Text(session.formattedPlayTime)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(.blue)
        }
    }
    
    private var gameGridView: some View {
        VStack(spacing: 4) {
            ForEach(0..<game.gridSize, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<game.gridSize, id: \.self) { col in
                        let position = GridPosition(row: row, col: col)
                        let pipe = game.grid[row][col]
                        
                        PipeCellView(
                            pipe: pipe,
                            isConnected: game.isConnected(position),
                            isStart: position == game.startPosition,
                            isEnd: position == game.endPosition
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

// MARK: - Cellule de Tuyau

struct PipeCellView: View {
    let pipe: PipePiece
    let isConnected: Bool
    let isStart: Bool
    let isEnd: Bool
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
                
                // Marqueurs de départ et fin
                if isStart {
                    Text("💧")
                        .font(.caption)
                        .offset(x: -15, y: -15)
                }
                
                if isEnd {
                    Text("🎯")
                        .font(.caption)
                        .offset(x: 15, y: 15)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isConnected ? 1.05 : 1.0)
        .animation(.spring(duration: 0.3), value: isConnected)
        .animation(.easeInOut(duration: 0.2), value: pipe.rotation)
    }
    
    // MARK: - Propriétés d'Affichage
    
    private var cellSize: CGFloat { 65 }
    
    private var backgroundColor: Color {
        if isConnected {
            return .blue.opacity(0.2)
        } else {
            return .gray.opacity(0.05)
        }
    }
    
    private var borderColor: Color {
        if isConnected {
            return .blue.opacity(0.6)
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    private var borderWidth: CGFloat {
        isConnected ? 2 : 1
    }
    
    private var pipeColor: Color {
        if isConnected {
            return .blue
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
