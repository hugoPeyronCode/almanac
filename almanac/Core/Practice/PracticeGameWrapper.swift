//
//  PracticeGameWrapper.swift
//  almanac
//
//  A wrapper view that manages practice session transitions
//

import SwiftUI

struct PracticeGameWrapper: View {
    @Environment(GameCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext
    
    let initialSession: GameSession
    @State private var currentSession: GameSession
    @State private var sessionKey = UUID()
    
    init(session: GameSession) {
        self.initialSession = session
        self._currentSession = State(initialValue: session)
    }
    
    var body: some View {
        Group {
            switch currentSession.gameType {
            case .pipe:
              Text("PipeGame View Working from old Repo")
            case .shikaku:
                ShikakuGameView(session: currentSession)
                    .id(sessionKey)
            case .sets:
                SetsGameView(session: currentSession)
                    .id(sessionKey)
            case .wordle:
                WordleGameView(session: currentSession)
                    .id(sessionKey)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .loadNewPracticeLevel)) { notification in
            if let newSession = notification.object as? GameSession,
               newSession.gameType == currentSession.gameType {
                // Update to new session and force view refresh
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentSession = newSession
                    sessionKey = UUID() // Force view recreation
                }
            }
        }
    }
}
