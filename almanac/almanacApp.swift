//
//  almanacApp.swift
//  almanac
//
//  Created by Hugo Peyron on 28/05/2025.
//

import SwiftUI
import SwiftData

@main
struct MultiGamePuzzleApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            GameLevel.self,
            GameProgress.self,
            DailyCompletion.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [GameLevel.self, GameProgress.self, DailyCompletion.self])
}
