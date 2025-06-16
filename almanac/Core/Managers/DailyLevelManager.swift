////
////  DailyLevelManager.swift
////  almanac
////
////  Manages daily level assignment and date-level linking
////
//
//import SwiftUI
//import SwiftData
//
//class DailyLevelManager {
//    private let stateManager: UnifiedGameStateManager
//    private let levelManager = LevelManager.shared
//    
//    init(modelContext: ModelContext) {
//        self.stateManager = UnifiedGameStateManager(modelContext: modelContext)
//    }
//    
//    // MARK: - Daily Level Assignment
//    
//    /// Gets the daily level for a specific game type and date
//    func getDailyLevel(for gameType: GameType, date: Date) -> AnyGameLevel {
//        // Check if we already have a stored level for this date
//        if let storedLevel = getStoredDailyLevel(for: gameType, date: date) {
//            return storedLevel
//        }
//        
//        // Generate and store new daily level
//        let newLevel = generateDailyLevel(for: gameType, date: date)
//        storeDailyLevel(newLevel, for: gameType, date: date)
//        return newLevel
//    }
//    
//    /// Generates a deterministic daily level based on the date
//    private func generateDailyLevel(for gameType: GameType, date: Date) -> AnyGameLevel {
//        let dailySeed = stateManager.generateDailySeed(for: date)
//        
//        switch gameType {
//        case .wordle:
//            return generateDailyWordleLevel(seed: dailySeed, date: date)
//        case .shikaku:
//            return generateDailyShikakuLevel(seed: dailySeed, date: date)
//        case .sets:
//            return generateDailySetsLevel(seed: dailySeed, date: date)
//        case .pipe:
//            return generateDailyPipeLevel(seed: dailySeed, date: date)
//        }
//    }
//    
//    // MARK: - Game-Specific Daily Level Generation
//    
//    private func generateDailyWordleLevel(seed: Int, date: Date) -> AnyGameLevel {
//        let word = generateWordForDate(date: date, seed: seed)
//        let level = WordleLevelData(
//            id: "wordle_daily_\(formatDate(date))",
//            word: word,
//            maxAttempts: 6
//        )
//        
//        do {
//            return try AnyGameLevel(level)
//        } catch {
//            // Fallback
//            let fallbackLevel = WordleLevelData(id: "wordle_fallback", word: "CRANE", maxAttempts: 6)
//            return try! AnyGameLevel(fallbackLevel)
//        }
//    }
//    
//    private func generateDailyShikakuLevel(seed: Int, date: Date) -> AnyGameLevel {
//        // Get available Shikaku levels and select one based on seed
//        let availableLevels = levelManager.getAllLevels(for: .shikaku)
//        let levelIndex = seed % availableLevels.count
//        let baseLevel = availableLevels[levelIndex]
//        
//        // Create a new level with daily ID
//        do {
//            let levelData = try baseLevel.decode(as: ShikakuLevelData.self)
//            let dailyLevel = ShikakuLevelData(
//                id: "shikaku_daily_\(formatDate(date))",
//                gridRows: levelData.gridRows,
//                gridCols: levelData.gridCols,
//                clues: levelData.clues
//            )
//            return try AnyGameLevel(dailyLevel)
//        } catch {
//            // Fallback to default level
//            let fallbackLevel = ShikakuLevelData(
//                id: "shikaku_fallback",
//                gridRows: 5,
//                gridCols: 5,
//                clues: [
//                    ShikakuLevelData.ClueData(row: 0, col: 0, value: 3),
//                    ShikakuLevelData.ClueData(row: 2, col: 2, value: 4),
//                    ShikakuLevelData.ClueData(row: 4, col: 4, value: 2)
//                ]
//            )
//            return try! AnyGameLevel(fallbackLevel)
//        }
//    }
//    
//    private func generateDailySetsLevel(seed: Int, date: Date) -> AnyGameLevel {
//        let level = SetsLevelData(
//            id: "sets_daily_\(formatDate(date))",
//            seed: seed
//        )
//        
//        do {
//            return try AnyGameLevel(level)
//        } catch {
//            let fallbackLevel = SetsLevelData(id: "sets_fallback", seed: 12345)
//            return try! AnyGameLevel(fallbackLevel)
//        }
//    }
//    
//    private func generateDailyPipeLevel(seed: Int, date: Date) -> AnyGameLevel {
//        // Generate a deterministic pipe level based on seed
//        var rng = SeededRandomGenerator(seed: seed)
//        let gridSize = 4 + (seed % 3) // 4x4 to 6x6
//        
//        let level = PipeLevelData(
//            id: "pipe_daily_\(formatDate(date))",
//            gridRows: gridSize,
//            gridCols: gridSize,
//            startRow: gridSize / 2,
//            startCol: gridSize / 2,
//            endRow: 0,
//            endCol: 0,
//            tiles: generatePipeTiles(gridSize: gridSize, rng: &rng)
//        )
//        
//        do {
//            return try AnyGameLevel(level)
//        } catch {
//            let fallbackLevel = PipeLevelData(
//                id: "pipe_fallback",
//                gridRows: 4,
//                gridCols: 4,
//                startRow: 2,
//                startCol: 2,
//                endRow: 0,
//                endCol: 0,
//                tiles: []
//            )
//            return try! AnyGameLevel(fallbackLevel)
//        }
//    }
//    
//    // MARK: - Helper Methods
//    
//    private func generateWordForDate(date: Date, seed: Int) -> String {
//        // Load word list and select based on seed
//        guard let path = Bundle.main.path(forResource: "english_words", ofType: "txt"),
//              let content = try? String(contentsOfFile: path),
//              !content.isEmpty else {
//            return "CRANE"
//        }
//        
//        let words = content.components(separatedBy: .newlines)
//            .filter { $0.count == 5 }
//            .map { $0.uppercased() }
//        
//        guard !words.isEmpty else { return "CRANE" }
//        
//        let wordIndex = seed % words.count
//        return words[wordIndex]
//    }
//    
//    private func generatePipeTiles(gridSize: Int, rng: inout SeededRandomGenerator) -> [[PipeLevelData.TileData]] {
//        var tiles: [[PipeLevelData.TileData]] = []
//        
//        for row in 0..<gridSize {
//            var rowTiles: [PipeLevelData.TileData] = []
//            for col in 0..<gridSize {
//                let tileTypes: [String] = ["straight", "corner", "deadEnd", "tJunction"]
//                let randomType = tileTypes[rng.nextInt(in: 0..<tileTypes.count)]
//                let rotation = Double(rng.nextInt(in: 0..<4) * 90)
//                
//                let tile = PipeLevelData.TileData(
//                    type: randomType,
//                    rotation: rotation,
//                    isLocked: (row == gridSize / 2 && col == gridSize / 2) // Lock the start position
//                )
//                rowTiles.append(tile)
//            }
//            tiles.append(rowTiles)
//        }
//        
//        return tiles
//    }
//    
//    private func formatDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd"
//        return formatter.string(from: date)
//    }
//    
//    // MARK: - Storage Methods
//    
//    private func getStoredDailyLevel(for gameType: GameType, date: Date) -> AnyGameLevel? {
//        guard let levelData = stateManager.getDailyLevel(for: gameType, date: date) else {
//            return nil
//        }
//        
//        // Decode the stored level data back to AnyGameLevel
//        do {
//            switch gameType {
//            case .wordle:
//                let wordleLevel = try JSONDecoder().decode(WordleLevelData.self, from: levelData)
//                return try AnyGameLevel(wordleLevel)
//            case .shikaku:
//                let shikakuLevel = try JSONDecoder().decode(ShikakuLevelData.self, from: levelData)
//                return try AnyGameLevel(shikakuLevel)
//            case .sets:
//                let setsLevel = try JSONDecoder().decode(SetsLevelData.self, from: levelData)
//                return try AnyGameLevel(setsLevel)
//            case .pipe:
//                let pipeLevel = try JSONDecoder().decode(PipeLevelData.self, from: levelData)
//                return try AnyGameLevel(pipeLevel)
//            }
//        } catch {
//            print("❌ Failed to decode stored daily level for \(gameType): \(error)")
//            return nil
//        }
//    }
//    
//    private func storeDailyLevel(_ level: AnyGameLevel, for gameType: GameType, date: Date) {
//        do {
//            let levelData = try JSONEncoder().encode(level)
//            stateManager.saveDailyLevel(for: gameType, date: date, levelData: levelData)
//        } catch {
//            print("❌ Failed to store daily level for \(gameType): \(error)")
//        }
//    }
//}
//
//// SeededRandomGenerator is defined in GamesStateManager.swift
