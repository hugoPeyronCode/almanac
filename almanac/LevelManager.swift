//
//  LevelManager.swift
//  Multi-Game Puzzle App
//
//  Updated to work with simple JSON structure without gameType wrapper
//

import SwiftUI
import Foundation

@Observable
class LevelManager {
    static let shared = LevelManager()

    private var gameLevels: [GameType: [AnyGameLevel]] = [:]
    private let calendar = Calendar.current
    private let referenceDate = Date() // Today as reference point
    private var isLoaded = false

    private init() {
        loadAllGameLevels()
    }

    // MARK: - Level Loading

    private func loadAllGameLevels() {
        guard !isLoaded else { return }

        for gameType in GameType.allCases {
            loadLevelsForGame(gameType)
        }

        isLoaded = true
        print("✅ All game levels loaded successfully")
    }

    private func loadLevelsForGame(_ gameType: GameType) {
        guard let url = Bundle.main.url(forResource: gameType.rawValue + "_levels", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ No JSON file found for \(gameType.displayName), creating mock data")
            gameLevels[gameType] = createMockLevels(for: gameType)
            return
        }

        do {
            // Decode the simple JSON structure
            let levelsContainer = try JSONDecoder().decode(LevelsContainer.self, from: data)

            // Convert to AnyGameLevel based on game type
            let anyLevels = try convertToAnyGameLevels(levelsContainer.levels, for: gameType)
            gameLevels[gameType] = anyLevels

            print("✅ Loaded \(anyLevels.count) levels for \(gameType.displayName)")
        } catch {
            print("❌ Failed to decode \(gameType.displayName) levels: \(error)")
            print("🔄 Creating mock data for \(gameType.displayName)")
            gameLevels[gameType] = createMockLevels(for: gameType)
        }
    }

    // MARK: - JSON Conversion

    private func convertToAnyGameLevels(_ levels: [LevelData], for gameType: GameType) throws -> [AnyGameLevel] {
        return try levels.map { level in
            switch gameType {
            case .shikaku:
                let shikakuLevel = ShikakuLevelData(
                    id: level.id,
                    difficulty: level.difficulty,
                    gridRows: level.gridRows,
                    gridCols: level.gridCols,
                    clues: level.clues.map { clue in
                        ShikakuLevelData.ClueData(
                            row: clue.row,
                            col: clue.col,
                            value: clue.value
                        )
                    }
                )
                return try AnyGameLevel(shikakuLevel)

            case .pipe:
                let pipeLevel = PipeLevelData(
                    id: level.id,
                    difficulty: level.difficulty,
                    gridSize: max(level.gridRows, level.gridCols),
                    pipes: [] // Convert clues to pipes if needed
                )
                return try AnyGameLevel(pipeLevel)

            case .wordle:
                let wordleLevel = WordleLevelData(
                    id: level.id,
                    difficulty: level.difficulty,
                    targetWord: generateWordFromId(level.id),
                    maxAttempts: 6
                )
                return try AnyGameLevel(wordleLevel)

            case .sets:
                let setsLevel = SetsLevelData(
                    id: level.id,
                    difficulty: level.difficulty
                )
                return try AnyGameLevel(setsLevel)
            }
        }
    }

    // MARK: - Mock Level Creation

    private func createMockLevels(for gameType: GameType) -> [AnyGameLevel] {
        var levels: [AnyGameLevel] = []

        for i in 1...100 {
            let difficulty = ((i - 1) / 20) + 1 // 20 levels per difficulty
            do {
                let levelData: any GameLevelData

                switch gameType {
                case .shikaku:
                    levelData = ShikakuLevelData(
                        id: "shikaku_\(i)",
                        difficulty: difficulty,
                        gridRows: 6 + difficulty,
                        gridCols: 4 + difficulty,
                        clues: generateMockClues(gridRows: 6 + difficulty, gridCols: 4 + difficulty)
                    )
                case .pipe:
                    levelData = PipeLevelData(
                        id: "pipe_\(i)",
                        difficulty: difficulty,
                        gridSize: 4 + difficulty,
                        pipes: []
                    )
                case .wordle:
                    levelData = WordleLevelData(
                        id: "wordle_\(i)",
                        difficulty: difficulty,
                        targetWord: generateRandomWord(difficulty: difficulty),
                        maxAttempts: 6
                    )
                case .sets:
                    levelData = SetsLevelData(
                        id: "sets_\(i)",
                        difficulty: difficulty
                    )
                }

                let anyLevel = try AnyGameLevel(levelData)
                levels.append(anyLevel)
            } catch {
                print("❌ Failed to create mock level for \(gameType.displayName): \(error)")
            }
        }

        print("✅ Created \(levels.count) mock levels for \(gameType.displayName)")
        return levels
    }

    // Helper function to generate mock clues for Shikaku
    private func generateMockClues(gridRows: Int, gridCols: Int) -> [ShikakuLevelData.ClueData] {
        var clues: [ShikakuLevelData.ClueData] = []
        let numberOfClues = max(3, (gridRows * gridCols) / 8) // Roughly 1 clue per 8 cells

        for _ in 0..<numberOfClues {
            let row = Int.random(in: 0..<gridRows)
            let col = Int.random(in: 0..<gridCols)
            let value = Int.random(in: 2...8) // Rectangle sizes from 2 to 8

            clues.append(ShikakuLevelData.ClueData(row: row, col: col, value: value))
        }

        return clues
    }
    
    // Helper function to generate word from level ID for deterministic daily words
    private func generateWordFromId(_ id: String) -> String {
        // Use a large curated word list for better variety
        let wordList = [
            "ABOUT", "ABOVE", "ABUSE", "ACTOR", "ACUTE", "ADMIT", "ADOPT", "ADULT", "AFTER", "AGAIN",
            "AGENT", "AGREE", "AHEAD", "ALARM", "ALBUM", "ALERT", "ALIEN", "ALIGN", "ALIKE", "ALIVE",
            "ALLOW", "ALONE", "ALONG", "ALTER", "AMBER", "AMONG", "ANGER", "ANGLE", "ANGRY", "ANKLE",
            "APART", "APPLE", "APPLY", "ARENA", "ARGUE", "ARISE", "ARMED", "ARMOR", "ARRAY", "ARROW",
            "ASIDE", "ASSET", "AVOID", "AWAKE", "AWARD", "AWARE", "BADLY", "BAKER", "BASES", "BASIC",
            "BEACH", "BEGAN", "BEGIN", "BEING", "BELLY", "BELOW", "BENCH", "BILLY", "BIRTH", "BLACK",
            "BLADE", "BLAME", "BLANK", "BLAST", "BLIND", "BLOCK", "BLOOD", "BLOOM", "BOARD", "BOOST",
            "BOOTH", "BOUND", "BRAIN", "BRAND", "BRASS", "BRAVE", "BREAD", "BREAK", "BREED", "BRICK",
            "BRIEF", "BRING", "BROAD", "BROKE", "BROWN", "BUILD", "BUILT", "BUYER", "CABLE", "CHOSE",
            "CIVIC", "CIVIL", "CLAIM", "CLASS", "CLEAN", "CLEAR", "CLICK", "CLIMB", "CLOCK", "CLOSE",
            "CLOUD", "COACH", "COAST", "COULD", "COUNT", "COURT", "COVER", "CRAFT", "CRASH", "CRAZY",
            "CREAM", "CRIME", "CROSS", "CROWD", "CROWN", "CRUDE", "CURVE", "CYCLE", "DAILY", "DANCE",
            "DATED", "DEALT", "DEATH", "DEBUT", "DELAY", "DEPTH", "DOING", "DOUBT", "DOZEN", "DRAFT",
            "DRAMA", "DRANK", "DRAWN", "DREAM", "DRESS", "DRILL", "DRINK", "DRIVE", "DROVE", "DYING",
            "EAGER", "EARLY", "EARTH", "EIGHT", "ELITE", "EMPTY", "ENEMY", "ENJOY", "ENTER", "ENTRY",
            "EQUAL", "ERROR", "EVENT", "EVERY", "EXACT", "EXIST", "EXTRA", "FAITH", "FALSE", "FAULT",
            "FIBER", "FIELD", "FIFTH", "FIFTY", "FIGHT", "FINAL", "FIRST", "FIXED", "FLASH", "FLEET",
            "FLOOR", "FLUID", "FOCUS", "FORCE", "FORTH", "FORTY", "FORUM", "FOUND", "FRAME", "FRANK",
            "FRAUD", "FRESH", "FRONT", "FRUIT", "FULLY", "FUNNY", "GIANT", "GIVEN", "GLASS", "GLOBE",
            "GLORY", "GOODS", "GRACE", "GRADE", "GRAIN", "GRAND", "GRANT", "GRASS", "GRAVE", "GREAT",
            "GREEN", "GROSS", "GROUP", "GROWN", "GUARD", "GUESS", "GUEST", "GUIDE", "HAPPY", "HARRY",
            "HEART", "HEAVY", "HORSE", "HOTEL", "HOUSE", "HUMAN", "IDEAL", "IMAGE", "INDEX", "INNER",
            "INPUT", "ISSUE", "JAPAN", "JIMMY", "JOINT", "JONES", "JUDGE", "KNOWN", "LABEL", "LARGE",
            "LASER", "LATER", "LAUGH", "LAYER", "LEARN", "LEASE", "LEAST", "LEAVE", "LEGAL", "LEVEL",
            "LEWIS", "LIGHT", "LIMIT", "LINKS", "LIVES", "LOCAL", "LOOSE", "LOWER", "LUCKY", "LUNCH",
            "LYING", "MAGIC", "MAJOR", "MAKER", "MARCH", "MARIA", "MATCH", "MAYBE", "MAYOR", "MEANT",
            "MEDIA", "METAL", "MIGHT", "MINOR", "MINUS", "MIXED", "MODEL", "MONEY", "MONTH", "MORAL",
            "MOTOR", "MOUNT", "MOUSE", "MOUTH", "MOVED", "MOVIE", "MUSIC", "NEEDS", "NEVER", "NEWLY",
            "NIGHT", "NOISE", "NORTH", "NOTED", "NOVEL", "NURSE", "OCCUR", "OCEAN", "OFFER", "OFTEN",
            "ORDER", "OTHER", "OUGHT", "PAINT", "PANEL", "PAPER", "PARTY", "PEACE", "PETER", "PHASE",
            "PHONE", "PHOTO", "PIANO", "PIECE", "PILOT", "PITCH", "PLACE", "PLAIN", "PLANE", "PLANT",
            "PLATE", "POINT", "POUND", "POWER", "PRESS", "PRICE", "PRIDE", "PRIME", "PRINT", "PRIOR",
            "PRIZE", "PROOF", "PROUD", "PROVE", "QUEEN", "QUICK", "QUIET", "QUITE", "RADIO", "RAISE",
            "RANGE", "RAPID", "RATIO", "REACH", "READY", "REALM", "REBEL", "REFER", "RELAX", "ENTRY",
            "RIGHT", "RIVAL", "RIVER", "ROBIN", "ROGER", "ROMAN", "ROUGH", "ROUND", "ROUTE", "ROYAL",
            "RURAL", "SCALE", "SCENE", "SCOPE", "SCORE", "SENSE", "SERVE", "SEVEN", "SHALL", "SHAPE",
            "SHARE", "SHARP", "SHEET", "SHELF", "SHELL", "SHIFT", "SHINE", "SHIRT", "SHOCK", "SHOOT",
            "SHORT", "SHOWN", "SIGHT", "SINCE", "SIXTH", "SIXTY", "SIZED", "SKILL", "SLEEP", "SLIDE",
            "SMALL", "SMART", "SMILE", "SMITH", "SMOKE", "SNAKE", "SNOW", "SOCIAL", "SOLID", "SOLVE",
            "SORRY", "SOUND", "SOUTH", "SPACE", "SPARE", "SPEAK", "SPEED", "SPEND", "SPENT", "SPLIT",
            "SPOKE", "SPORT", "SQUAD", "STAFF", "STAGE", "STAKE", "STAND", "START", "STATE", "STEAM",
            "STEEL", "STICK", "STILL", "STOCK", "STONE", "STOOD", "STORE", "STORM", "STORY", "STRIP",
            "STUCK", "STUDY", "STUFF", "STYLE", "SUGAR", "SUITE", "SUPER", "SWEET", "SWIFT", "SWING",
            "SWISS", "TABLE", "TAKEN", "TASTE", "TAXES", "TEACH", "TEAM", "TERRY", "TEXAS", "THANK",
            "THEFT", "THEIR", "THEME", "THERE", "THESE", "THICK", "THING", "THINK", "THIRD", "THOSE",
            "THREE", "THREW", "THROW", "THUMB", "TIGHT", "TIRED", "TITLE", "TODAY", "TOPIC", "TOTAL",
            "TOUCH", "TOUGH", "TOWER", "TRACK", "TRADE", "TRAIN", "TREAT", "TREND", "TRIAL", "TRIBE",
            "TRICK", "TRIED", "TRIES", "TRUCK", "TRULY", "TRUNK", "TRUST", "TRUTH", "TWICE", "UNCLE",
            "UNDUE", "UNION", "UNITY", "UNTIL", "UPPER", "UPSET", "URBAN", "USAGE", "USUAL", "VALID",
            "VALUE", "VIDEO", "VIRUS", "VISIT", "VITAL", "VOCAL", "WASTE", "WATCH", "WATER", "WHEEL",
            "WHERE", "WHICH", "WHILE", "WHITE", "WHOLE", "WHOSE", "WOMAN", "WOMEN", "WORLD", "WORRY",
            "WORSE", "WORST", "WORTH", "WOULD", "WRITE", "WRONG", "WROTE", "YOUNG", "YOURS", "YOUTH"
        ]
        
        // Create a deterministic hash from the level ID
        // Use a simple hash that will be consistent across devices and app launches
        var hash: UInt32 = 5381
        for char in id.utf8 {
            hash = hash &* 33 &+ UInt32(char)
        }
        
        let index = Int(hash) % wordList.count
        return wordList[index]
    }
    
    // Helper function to generate random word based on difficulty
    private func generateRandomWord(difficulty: Int) -> String {
        let wordsByDifficulty = [
            1: ["APPLE", "HAPPY", "LIGHT", "MUSIC", "PEACE"],
            2: ["SWIFT", "BRAVE", "GRACE", "TRUST", "DANCE"],
            3: ["WORLD", "DREAM", "MAGIC", "POWER", "YOUTH"],
            4: ["PHONE", "SMILE", "HEART", "HONOR", "SHINE"],
            5: ["QUEST", "BLEND", "FROST", "SPARK", "STORM"]
        ]
        
        let words = wordsByDifficulty[difficulty] ?? wordsByDifficulty[3]!
        return words.randomElement() ?? "SWIFT"
    }

    // MARK: - Daily Level Distribution

    func getLevelForDate(_ date: Date, gameType: GameType) -> AnyGameLevel? {
        guard let levels = gameLevels[gameType], !levels.isEmpty else {
            print("❌ No levels available for \(gameType.displayName)")
            return nil
        }

        // For Wordle, create a special deterministic daily level based on date
        if gameType == .wordle {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            
            // Create deterministic level ID based on date
            let levelId = "wordle_daily_\(dateString)"
            
            // Generate deterministic word for this specific date
            let dailyWord = generateDeterministicWordForDate(date)
            
            do {
                let wordleLevel = WordleLevelData(
                    id: levelId,
                    difficulty: 3,
                    targetWord: dailyWord,
                    maxAttempts: 5
                )
                return try AnyGameLevel(wordleLevel)
            } catch {
                print("❌ Failed to create daily Wordle level: \(error)")
            }
        }

        // Calculate deterministic index based on date for other games
        let dayOffset = calendar.dateComponents([.day], from: referenceDate, to: date).day ?? 0
        let adjustedOffset = dayOffset + 100
        let levelIndex = ((adjustedOffset % levels.count) + levels.count) % levels.count

        return levels[levelIndex]
    }
    
    // Generate a deterministic word based on the specific date
    private func generateDeterministicWordForDate(_ date: Date) -> String {
        let wordList = [
            "ABOUT", "ABOVE", "ABUSE", "ACTOR", "ACUTE", "ADMIT", "ADOPT", "ADULT", "AFTER", "AGAIN",
            "AGENT", "AGREE", "AHEAD", "ALARM", "ALBUM", "ALERT", "ALIEN", "ALIGN", "ALIKE", "ALIVE",
            "ALLOW", "ALONE", "ALONG", "ALTER", "AMBER", "AMONG", "ANGER", "ANGLE", "ANGRY", "ANKLE",
            "APART", "APPLE", "APPLY", "ARENA", "ARGUE", "ARISE", "ARMED", "ARMOR", "ARRAY", "ARROW",
            "ASIDE", "ASSET", "AVOID", "AWAKE", "AWARD", "AWARE", "BADLY", "BAKER", "BASES", "BASIC",
            "BEACH", "BEGAN", "BEGIN", "BEING", "BELLY", "BELOW", "BENCH", "BILLY", "BIRTH", "BLACK",
            "BLADE", "BLAME", "BLANK", "BLAST", "BLIND", "BLOCK", "BLOOD", "BLOOM", "BOARD", "BOOST",
            "BOOTH", "BOUND", "BRAIN", "BRAND", "BRASS", "BRAVE", "BREAD", "BREAK", "BREED", "BRICK",
            "BRIEF", "BRING", "BROAD", "BROKE", "BROWN", "BUILD", "BUILT", "BUYER", "CABLE", "CHOSE",
            "CIVIC", "CIVIL", "CLAIM", "CLASS", "CLEAN", "CLEAR", "CLICK", "CLIMB", "CLOCK", "CLOSE",
            "CLOUD", "COACH", "COAST", "COULD", "COUNT", "COURT", "COVER", "CRAFT", "CRASH", "CRAZY",
            "CREAM", "CRIME", "CROSS", "CROWD", "CROWN", "CRUDE", "CURVE", "CYCLE", "DAILY", "DANCE",
            "DATED", "DEALT", "DEATH", "DEBUT", "DELAY", "DEPTH", "DOING", "DOUBT", "DOZEN", "DRAFT",
            "DRAMA", "DRANK", "DRAWN", "DREAM", "DRESS", "DRILL", "DRINK", "DRIVE", "DROVE", "DYING",
            "EAGER", "EARLY", "EARTH", "EIGHT", "ELITE", "EMPTY", "ENEMY", "ENJOY", "ENTER", "ENTRY",
            "EQUAL", "ERROR", "EVENT", "EVERY", "EXACT", "EXIST", "EXTRA", "FAITH", "FALSE", "FAULT",
            "FIBER", "FIELD", "FIFTH", "FIFTY", "FIGHT", "FINAL", "FIRST", "FIXED", "FLASH", "FLEET",
            "FLOOR", "FLUID", "FOCUS", "FORCE", "FORTH", "FORTY", "FORUM", "FOUND", "FRAME", "FRANK",
            "FRAUD", "FRESH", "FRONT", "FRUIT", "FULLY", "FUNNY", "GIANT", "GIVEN", "GLASS", "GLOBE",
            "GLORY", "GOODS", "GRACE", "GRADE", "GRAIN", "GRAND", "GRANT", "GRASS", "GRAVE", "GREAT",
            "GREEN", "GROSS", "GROUP", "GROWN", "GUARD", "GUESS", "GUEST", "GUIDE", "HAPPY", "HARRY",
            "HEART", "HEAVY", "HORSE", "HOTEL", "HOUSE", "HUMAN", "IDEAL", "IMAGE", "INDEX", "INNER",
            "INPUT", "ISSUE", "JAPAN", "JIMMY", "JOINT", "JONES", "JUDGE", "KNOWN", "LABEL", "LARGE",
            "LASER", "LATER", "LAUGH", "LAYER", "LEARN", "LEASE", "LEAST", "LEAVE", "LEGAL", "LEVEL",
            "LEWIS", "LIGHT", "LIMIT", "LINKS", "LIVES", "LOCAL", "LOOSE", "LOWER", "LUCKY", "LUNCH",
            "LYING", "MAGIC", "MAJOR", "MAKER", "MARCH", "MARIA", "MATCH", "MAYBE", "MAYOR", "MEANT",
            "MEDIA", "METAL", "MIGHT", "MINOR", "MINUS", "MIXED", "MODEL", "MONEY", "MONTH", "MORAL",
            "MOTOR", "MOUNT", "MOUSE", "MOUTH", "MOVED", "MOVIE", "MUSIC", "NEEDS", "NEVER", "NEWLY",
            "NIGHT", "NOISE", "NORTH", "NOTED", "NOVEL", "NURSE", "OCCUR", "OCEAN", "OFFER", "OFTEN",
            "ORDER", "OTHER", "OUGHT", "PAINT", "PANEL", "PAPER", "PARTY", "PEACE", "PETER", "PHASE",
            "PHONE", "PHOTO", "PIANO", "PIECE", "PILOT", "PITCH", "PLACE", "PLAIN", "PLANE", "PLANT",
            "PLATE", "POINT", "POUND", "POWER", "PRESS", "PRICE", "PRIDE", "PRIME", "PRINT", "PRIOR",
            "PRIZE", "PROOF", "PROUD", "PROVE", "QUEEN", "QUICK", "QUIET", "QUITE", "RADIO", "RAISE",
            "RANGE", "RAPID", "RATIO", "REACH", "READY", "REALM", "REBEL", "REFER", "RELAX", "REPLY",
            "RIGHT", "RIVAL", "RIVER", "ROBIN", "ROGER", "ROMAN", "ROUGH", "ROUND", "ROUTE", "ROYAL",
            "RURAL", "SCALE", "SCENE", "SCOPE", "SCORE", "SENSE", "SERVE", "SEVEN", "SHALL", "SHAPE",
            "SHARE", "SHARP", "SHEET", "SHELF", "SHELL", "SHIFT", "SHINE", "SHIRT", "SHOCK", "SHOOT",
            "SHORT", "SHOWN", "SIGHT", "SINCE", "SIXTH", "SIXTY", "SIZED", "SKILL", "SLEEP", "SLIDE",
            "SMALL", "SMART", "SMILE", "SMITH", "SMOKE", "SNAKE", "SOLID", "SOLVE", "SORRY", "SOUND",
            "SOUTH", "SPACE", "SPARE", "SPEAK", "SPEED", "SPEND", "SPENT", "SPLIT", "SPOKE", "SPORT",
            "SQUAD", "STAFF", "STAGE", "STAKE", "STAND", "START", "STATE", "STEAM", "STEEL", "STICK",
            "STILL", "STOCK", "STONE", "STOOD", "STORE", "STORM", "STORY", "STRIP", "STUCK", "STUDY",
            "STUFF", "STYLE", "SUGAR", "SUITE", "SUPER", "SWEET", "SWIFT", "SWING", "SWISS", "TABLE",
            "TAKEN", "TASTE", "TAXES", "TEACH", "TERMS", "TERRY", "TEXAS", "THANK", "THEFT", "THEIR",
            "THEME", "THERE", "THESE", "THICK", "THING", "THINK", "THIRD", "THOSE", "THREE", "THREW",
            "THROW", "THUMB", "TIGHT", "TIRED", "TITLE", "TODAY", "TOPIC", "TOTAL", "TOUCH", "TOUGH",
            "TOWER", "TRACK", "TRADE", "TRAIN", "TREAT", "TREND", "TRIAL", "TRIBE", "TRICK", "TRIED",
            "TRIES", "TRUCK", "TRULY", "TRUNK", "TRUST", "TRUTH", "TWICE", "UNCLE", "UNDUE", "UNION",
            "UNITY", "UNTIL", "UPPER", "UPSET", "URBAN", "USAGE", "USUAL", "VALID", "VALUE", "VIDEO",
            "VIRUS", "VISIT", "VITAL", "VOCAL", "WASTE", "WATCH", "WATER", "WHEEL", "WHERE", "WHICH",
            "WHILE", "WHITE", "WHOLE", "WHOSE", "WOMAN", "WOMEN", "WORLD", "WORRY", "WORSE", "WORST",
            "WORTH", "WOULD", "WRITE", "WRONG", "WROTE", "YOUNG", "YOURS", "YOUTH"
        ]
        
        // Use days since epoch as seed for maximum determinism
        let referenceDate = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let daysSinceReference = Calendar.current.dateComponents([.day], from: referenceDate, to: date).day ?? 0
        
        // Ensure the same word for the same date across all devices
        let index = abs(daysSinceReference) % wordList.count
        return wordList[index]
    }

    func getAllLevelsForGame(_ gameType: GameType) -> [AnyGameLevel] {
        return gameLevels[gameType] ?? []
    }

    func getRandomLevelForGame(_ gameType: GameType, excluding excludedIds: Set<String> = []) -> AnyGameLevel? {
        guard let levels = gameLevels[gameType], !levels.isEmpty else { return nil }

        let availableLevels = levels.filter { !excludedIds.contains($0.id) }

        if availableLevels.isEmpty {
            // If all levels completed, return random from all levels
            return levels.randomElement()
        }

        return availableLevels.randomElement()
    }

    func getLevelById(_ id: String, gameType: GameType) -> AnyGameLevel? {
        return gameLevels[gameType]?.first { $0.id == id }
    }

    // MARK: - Statistics

    func getTotalLevelsCount(for gameType: GameType) -> Int {
        return gameLevels[gameType]?.count ?? 0
    }

    func getDifficultyDistribution(for gameType: GameType) -> [Int: Int] {
        guard let levels = gameLevels[gameType] else { return [:] }

        var distribution: [Int: Int] = [:]
        for level in levels {
            distribution[level.difficulty, default: 0] += 1
        }
        return distribution
    }
}

// MARK: - JSON Data Structures for Parsing

struct LevelsContainer: Codable {
    let levels: [LevelData]
}

struct LevelData: Codable {
    let id: String
    let gridRows: Int
    let gridCols: Int
    let difficulty: Int
    let clues: [ClueData]
}

struct ClueData: Codable {
    let row: Int
    let col: Int
    let value: Int
}

// MARK: - Game Level Data Structures (Keep your existing ones, just remove estimatedTime)

struct ShikakuLevelData: GameLevelData {
    let id: String
    let difficulty: Int
    let gridRows: Int
    let gridCols: Int
    let clues: [ClueData]

    struct ClueData: Codable {
        let row: Int
        let col: Int
        let value: Int
    }
}

struct PipeLevelData: GameLevelData {
    let id: String
    let difficulty: Int
    let gridSize: Int
    let pipes: [PipeData]

    struct PipeData: Codable {
        let row: Int
        let col: Int
        let connections: [Direction]
    }

    enum Direction: String, Codable {
        case up, down, left, right
    }
}

struct BinarioLevelData: GameLevelData {
    let id: String
    let difficulty: Int
    let gridSize: Int
    let initialGrid: [[Int?]]

    init(id: String, difficulty: Int, gridSize: Int, initialGrid: [[Int?]]) {
        self.id = id
        self.difficulty = difficulty
        self.gridSize = gridSize
        self.initialGrid = initialGrid.isEmpty ? Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize) : initialGrid
    }
}

// MARK: - Sets Level Data Structure

struct SetsLevelData: GameLevelData {
    let id: String
    let difficulty: Int
    let targetSets: Int

    init(id: String, difficulty: Int) {
        self.id = id
        self.difficulty = difficulty

        // Target sets based on difficulty
        switch difficulty {
        case 1: self.targetSets = 5
        case 2: self.targetSets = 8
        case 3: self.targetSets = 12
        case 4: self.targetSets = 16
        case 5: self.targetSets = 20
        default: self.targetSets = 10
        }
    }
}

// MARK: - Legacy WordleLevelData (Remove this later)

struct WordleLevelData: GameLevelData {
    let id: String
    let difficulty: Int
    let targetWord: String
    let maxAttempts: Int
}
