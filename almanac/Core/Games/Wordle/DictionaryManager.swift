//
//  DictionaryManager.swift
//  almanac
//
//  Created by Hugo Peyron on 12/06/2025.
//


import SwiftUI

class DictionaryManager {
    static let shared = DictionaryManager()
    private var words: Set<String> = []
    private var fiveLetterWords: [String] = []
    private var isLoaded = false

    private init() {
        loadDictionary()
    }

    private func loadDictionary() {
        guard !isLoaded else { return }

        if let path = Bundle.main.path(forResource: "english_words", ofType: "txt"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {

            // Load all words
            let allWords = content.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
                .filter { !$0.isEmpty }

            words = Set(allWords)

            // Filter and sort 5-letter words for daily challenges
            fiveLetterWords = allWords
                .filter { $0.count == 5 && $0.rangeOfCharacter(from: CharacterSet.letters.inverted) == nil }
                .sorted() // Sort for consistent ordering across devices

            print("✅ Loaded \(words.count) total words, \(fiveLetterWords.count) 5-letter words")
            isLoaded = true
        } else {
            print("❌ Failed to load dictionary file")
            // Provide minimal fallback
            fiveLetterWords = ["SWIFT", "APPLE", "BREAD", "CRANE", "DELTA", "EAGLE",
                              "FLAME", "GRAPE", "HOUSE", "IVORY", "JUICE", "KNIFE",
                              "LEMON", "MOUSE", "NIGHT", "OCEAN", "PIANO", "QUEEN",
                              "RIVER", "STONE", "TIGER", "UNITY", "VOICE", "WATER",
                              "YOUTH", "ZEBRA"]
            words = Set(fiveLetterWords)
        }
    }

    func isValid(word: String) -> Bool {
        return words.contains(word.uppercased())
    }

    func getFiveLetterWords() -> [String] {
        // Ensure dictionary is loaded
        if !isLoaded {
            loadDictionary()
        }
        return fiveLetterWords
    }

    // Get a subset of common 5-letter words for easier daily challenges
    func getCommonFiveLetterWords() -> [String] {
        // Filter for more common words (you could enhance this with frequency data)
        let commonPatterns = ["ING", "ED", "ER", "LY", "AL", "EN", "AN", "OR", "AR", "IT"]

        return fiveLetterWords.filter { word in
            // Exclude words with uncommon letter combinations
            !word.contains("Q") && !word.contains("X") && !word.contains("Z") &&
            // Include words with common endings/patterns
            (commonPatterns.contains { pattern in word.contains(pattern) } ||
             // Or simple, recognizable words
             word.count == 5)
        }
    }
}