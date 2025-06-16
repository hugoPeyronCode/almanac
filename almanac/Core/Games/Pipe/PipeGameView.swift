////
////  PipeGameView.swift
////  Multi-Game Puzzle App
////
////  Simple pipe connection puzzle game
////
//
//import SwiftUI
//
//struct PipeGameView: View {
//    @Environment(GameCoordinator.self) private var coordinator
//    @State private var game: PipeGame
//    @State private var showExitConfirmation = false
//    @State private var gameTimer = GameTimer()
//    
//    private let session: GameSession
//    
//    init(session: GameSession) {
//        self.session = session
//        
//        // Initialise le jeu avec les données du niveau
//        if let levelInfo = PipeLevelInfo(from: session.level) {
//            self._game = State(initialValue: PipeGame(levelInfo: levelInfo))
//        } else {
//            // Fallback vers un jeu par défaut si le décodage échoue
//            self._game = State(initialValue: PipeGame(gridSize: 4))
//        }
//    }
//    
//    var body: some View {
//        ZStack {
//            VStack(spacing: 20) {
//                // En-tête avec timer temps réel
//                GameHeaderView(
//                    session: session,
//                    showExitConfirmation: $showExitConfirmation,
//                    gameTimer: gameTimer
//                ) {
//                    gameTimer.stopTimer()
//                    coordinator.dismissFullScreen()
//                }
//                
//                // Instructions et indicateur de connexion
//                VStack(spacing: 8) {
//                    Text("Connectez tous les tuyaux à la source d'eau 💧")
//                        .font(.subheadline)
//                        .foregroundStyle(.secondary)
//                        .multilineTextAlignment(.center)
//                    
//                    HStack(spacing: 16) {
//                        // Indicateur de fuites
//                        if game.totalLeaks > 0 {
//                            Text("\(game.totalLeaks) fuite\(game.totalLeaks > 1 ? "s" : "")")
//                                .font(.caption)
//                                .foregroundStyle(.red)
//                                .fontWeight(.medium)
//                        }
//                        
//                        // Indicateur de connexions
//                        let connectedCount = game.connectedToPipes.count
//                        let totalPipes = (game.gridSize * game.gridSize) - 1 // Tous sauf la source
//                        
//                        if connectedCount == totalPipes && game.totalLeaks == 0 {
//                            Text("✅ Tous connectés !")
//                                .font(.caption)
//                                .foregroundStyle(.green)
//                                .fontWeight(.medium)
//                        } else {
//                            Text("\(connectedCount)/\(totalPipes) connectés")
//                                .font(.caption)
//                                .foregroundStyle(.blue)
//                                .fontWeight(.medium)
//                        }
//                    }
//                }
//                .padding(.horizontal)
//                
//                Spacer()
//                
//                // Grille de jeu
//                gameGridView
//                
//                Spacer()
//                
//                // Boutons de contrôle
//                controlsView
//            }
//            .padding()
//            
//            // Vue de complétion
//            if game.isComplete && session.isCompleted {
//                GameCompletionView(
//                    formattedDuration: formattedDuration,
//                    coordinator: coordinator,
//                    session: session
//                )
//                .ignoresSafeArea()
//            }
//        }
//        .navigationBarHidden(true)
//        .onAppear {
//            gameTimer.startTimer()
//            // Force une validation au démarrage
//            game.validateSystem()
//        }
//        .onDisappear {
//            gameTimer.stopTimer()
//        }
//        .alert("Quitter le jeu ?", isPresented: $showExitConfirmation) {
//            Button("Annuler", role: .cancel) { }
//            Button("Quitter", role: .destructive) {
//                gameTimer.stopTimer()
//                coordinator.dismissFullScreen()
//            }
//        } message: {
//            Text("Votre progression sera perdue.")
//        }
//        .onChange(of: game.isComplete) { _, isComplete in
//            if isComplete && !session.isCompleted {
//                handleGameCompletion()
//            }
//        }
//    }
//    
//    // MARK: - Helpers
//    
//    private var formattedDuration: String {
//        session.formattedPlayTime
//    }
//    
//    private func handleGameCompletion() {
//        session.complete()
//    }
//    
//    // MARK: - Composants de l'Interface
//    
//    private var gameGridView: some View {
//        VStack(spacing: 4) {
//            ForEach(0..<game.gridSize, id: \.self) { row in
//                HStack(spacing: 4) {
//                    ForEach(0..<game.gridSize, id: \.self) { col in
//                        let position = GridPosition(row: row, col: col)
//                        let pipe = game.grid[row][col]
//                        
//                        PipeCellView(
//                            pipe: pipe,
//                            hasLeaks: game.hasLeaks(at: position),
//                            isConnectedToSource: game.isConnectedToSource(at: position),
//                            isSource: position == game.sourcePosition
//                        ) {
//                            game.rotatePipe(at: position)
//                        }
//                    }
//                }
//            }
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 16)
//                .fill(.gray.opacity(0.1))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 16)
//                        .stroke(.gray.opacity(0.3), lineWidth: 1)
//                )
//        )
//    }
//    
//    private var controlsView: some View {
//        VStack(spacing: 12) {
//            // Bouton debug
//            DebugCompleteButton(session: session, label: "Compléter")
//                .disabled(session.isCompleted)
//            
//            VStack(spacing: 12) {
//                HStack(spacing: 20) {
//                    Button("Nouveau Puzzle") {
//                        game.reset()
//                    }
//                    .buttonStyle(.borderedProminent)
//                    
//                    if game.isComplete {
//                        Text("🎉 Complété !")
//                            .font(.headline)
//                            .foregroundStyle(.green)
//                            .fontWeight(.bold)
//                    }
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Cellule de Tuyau
//
//struct PipeCellView: View {
//    let pipe: PipePiece
//    let hasLeaks: Bool
//    let isConnectedToSource: Bool
//    let isSource: Bool
//    let onTap: () -> Void
//    
//    var body: some View {
//        Button(action: onTap) {
//            ZStack {
//                // Arrière-plan de la cellule
//                RoundedRectangle(cornerRadius: 8)
//                    .fill(backgroundColor)
//                    .frame(width: cellSize, height: cellSize)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 8)
//                            .stroke(borderColor, lineWidth: borderWidth)
//                    )
//                
//                // Symbole du tuyau
//                Text(pipe.symbol)
//                    .font(.system(size: 24, weight: .bold, design: .monospaced))
//                    .foregroundStyle(pipeColor)
//                
//                // Indicateur de source d'eau
//                if isSource {
//                    Text("💧")
//                        .font(.title2)
//                        .offset(x: -15, y: -15)
//                        .shadow(color: .blue, radius: 2)
//                }
//                
//                // Indicateur de fuite
//                if hasLeaks && !isSource {
//                    Text("⚠️")
//                        .font(.caption)
//                        .offset(x: 20, y: -20)
//                        .shadow(color: .red, radius: 2)
//                }
//            }
//        }
//        .buttonStyle(.plain)
//        .scaleEffect(hasLeaks ? 1.05 : 1.0)
//        .animation(.spring(duration: 0.3), value: hasLeaks)
//        .animation(.easeInOut(duration: 0.2), value: pipe.rotation)
//    }
//    
//    // MARK: - Propriétés d'Affichage
//    
//    private var cellSize: CGFloat { 65 }
//    
//    private var backgroundColor: Color {
//        if isSource {
//            return .blue.opacity(0.3) // Source d'eau en bleu
//        } else if hasLeaks {
//            return .red.opacity(0.15)
//        } else if isConnectedToSource {
//            return .green.opacity(0.15) // Connecté à la source en vert
//        } else {
//            return .gray.opacity(0.1) // Non connecté en gris
//        }
//    }
//    
//    private var borderColor: Color {
//        if isSource {
//            return .blue.opacity(0.8) // Source d'eau en bleu
//        } else if hasLeaks {
//            return .red.opacity(0.6)
//        } else if isConnectedToSource {
//            return .green.opacity(0.6)
//        } else {
//            return .gray.opacity(0.4)
//        }
//    }
//    
//    private var borderWidth: CGFloat {
//        if isSource {
//            return 3
//        } else if hasLeaks {
//            return 2
//        } else {
//            return 1
//        }
//    }
//    
//    private var pipeColor: Color {
//        if isSource {
//            return .blue // Source d'eau en bleu
//        } else if hasLeaks {
//            return .red
//        } else if isConnectedToSource {
//            return .green
//        } else {
//            return .gray
//        }
//    }
//}
//
////// MARK: - Preview
////#Preview {
////    // Crée un mock level pour le preview
////    let mockLevel = AnyGameLevel(id: "pipe_preview", difficulty: 1, gameData: Data())
////    
////  PipeGameView(session: GameSession(
////        gameType: .pipe,
////        level: mockLevel,
////        context: .practice()
////    ))
////    .environment(GameCoordinator())
////}
