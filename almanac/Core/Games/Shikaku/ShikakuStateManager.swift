////
////  ShikakuStateManager.swift
////  almanac
////
////  State persistence for Shikaku game
////
//
//import SwiftUI
//import SwiftData
//
//class ShikakuStateManager: GameStateManager<ShikakuGameState> {
//
//    func saveState(for session: GameSession, game: ShikakuGame) {
//        let stateId = generateStateId(for: session)
//
//        let descriptor = FetchDescriptor<ShikakuGameState>(
//            predicate: #Predicate { state in
//                state.sessionId == stateId
//            }
//        )
//
//        let state: ShikakuGameState
//        if let existingState = try? modelContext.fetch(descriptor).first {
//            state = existingState
//        } else {
//            state = ShikakuGameState(
//                sessionId: stateId,
//                gameType: session.gameType,
//                dateString: session.context.date?.ISO8601Format() ?? ""
//            )
//            modelContext.insert(state)
//        }
//
//        // Save rectangles with color indices
//        let savedRectangles = game.rectangles.enumerated().map { index, rect in
//            SavedRectangle(from: rect, colorIndex: index)
//        }
//        state.setRectangles(savedRectangles)
//
//        // Save level configuration for daily challenges
//        state.gridRows = game.gridSize.rows
//        state.gridCols = game.gridSize.cols
//        let savedClues = game.numberClues.map { SavedClue(from: $0) }
//        state.setClues(savedClues)
//
//        state.isCompleted = game.isGameComplete
//        state.lastUpdated = Date()
//
//        try? modelContext.save()
//    }
//
//    func loadState(for session: GameSession, into game: ShikakuGame) -> Bool {
//        let stateId = generateStateId(for: session)
//
//        let descriptor = FetchDescriptor<ShikakuGameState>(
//            predicate: #Predicate { state in
//                state.sessionId == stateId
//            }
//        )
//
//        guard let state = try? modelContext.fetch(descriptor).first else {
//            return false
//        }
//
//        // Restore grid configuration
//        game.gridSize = (rows: state.gridRows, cols: state.gridCols)
//
//        // Restore clues
//        game.numberClues = state.getClues().map { $0.toNumberClue() }
//
//        // Restore rectangles with colors
//        let savedRectangles = state.getRectangles()
//        game.rectangles = savedRectangles.map { saved in
//            saved.toGameRectangle(with: game.getColorPalette())
//        }
//
//        // Update color index to continue from where we left off
//        game.setColorIndex(savedRectangles.count)
//
//        // Validate the restored state
//        game.validateGame()
//
//        return true
//    }
//
//    func clearState(for session: GameSession) {
//        let stateId = generateStateId(for: session)
//
//        let descriptor = FetchDescriptor<ShikakuGameState>(
//            predicate: #Predicate { state in
//                state.sessionId == stateId
//            }
//        )
//
//        if let state = try? modelContext.fetch(descriptor).first {
//            modelContext.delete(state)
//            try? modelContext.save()
//        }
//    }
//
//    func saveLevelConfiguration(for session: GameSession, levelData: ShikakuLevelData) {
//        let stateId = generateStateId(for: session)
//
//        let descriptor = FetchDescriptor<ShikakuGameState>(
//            predicate: #Predicate { state in
//                state.sessionId == stateId
//            }
//        )
//
//        let state: ShikakuGameState
//        if let existingState = try? modelContext.fetch(descriptor).first {
//            state = existingState
//        } else {
//            state = ShikakuGameState(
//                sessionId: stateId,
//                gameType: session.gameType,
//                dateString: session.context.date?.ISO8601Format() ?? ""
//            )
//            modelContext.insert(state)
//        }
//
//        // Save level configuration
//        state.gridRows = levelData.gridRows
//        state.gridCols = levelData.gridCols
//
//        // Create SavedClue objects from level data
//        // Note: We need to convert ShikakuLevelData.ClueData to NumberClue first,
//        // then to SavedClue
//        let savedClues = levelData.clues.map { clueData in
//            let numberClue = NumberClue(
//                position: GridPosition(row: clueData.row, col: clueData.col),
//                value: clueData.value
//            )
//            return SavedClue(from: numberClue)
//        }
//        state.setClues(savedClues)
//
//        try? modelContext.save()
//    }
//}
