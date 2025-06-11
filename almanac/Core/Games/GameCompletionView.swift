//
//  GameCompletionView.swift
//  almanac
//
//  Created by Hugo Peyron on 30/05/2025.
//

import SwiftUI

struct GameCompletionView: View {
  let isGameLost: Bool
  let potentialRightAnswer: String
  let formattedDuration: String
  let coordinator: GameCoordinator
  let session: GameSession
  
  @State private var isVisible = false
  
  private var isPracticeMode: Bool {
    if case .practice = session.context {
      return true
    }
    return false
  }

  init(isGameLost: Bool, potentialRightAnswer: String, formattedDuration: String, coordinator: GameCoordinator, session: GameSession) {
    self.potentialRightAnswer = potentialRightAnswer
    self.isGameLost = isGameLost
    self.formattedDuration = formattedDuration
    self.coordinator = coordinator
    self.session = session
  }

  init(formattedDuration: String, coordinator: GameCoordinator, session: GameSession) {
    self.potentialRightAnswer = ""
    self.isGameLost = false
    self.formattedDuration = formattedDuration
    self.coordinator = coordinator
    self.session = session
  }

  var body: some View {
    ZStack {

      Rectangle()
        .fill(.black.opacity(0.3))
        .ignoresSafeArea()
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
      
      VStack {
        Spacer()
        
        // Main completion card
        VStack(spacing: 24) {
          // Icon with scale animation
          Image(systemName: isGameLost ? "xmark.octagon" : "checkmark.circle.fill")
            .font(.system(size: 64))
            .foregroundStyle(isGameLost ? Color.pink : Color.green)
            .scaleEffect(isVisible ? 1.0 : 0.3)
            .animation(.spring(duration: 0.6).delay(0.2), value: isVisible)

          VStack(alignment: isGameLost ?.leading : .center) {
            Text("\(isGameLost ? "Time played" : "Completed in") \(formattedDuration)")
              .font(.title2)
              .fontWeight(.medium)
              .foregroundStyle(.primary)
              .opacity(isVisible ? 1 : 0)
              .offset(y: isVisible ? 0 : 20)
              .animation(.easeOut(duration: 0.4).delay(0.4), value: isVisible)

            if isGameLost && potentialRightAnswer != "" {
              Text("Today's word was \(potentialRightAnswer)")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.4), value: isVisible)
            }
          }

          // Action buttons with stagger animation
          VStack(spacing: 12) {
            // Next button for practice mode only
            if case .practice = session.context {
              Button {
                // Start a new practice level
                if let level = LevelManager.shared.getRandomLevelForGame(session.gameType) {
                  // Create a new session and notify the parent view to reload
                  let newSession = GameSession(gameType: session.gameType, level: level, context: .practice())
                  NotificationCenter.default.post(name: .loadNewPracticeLevel, object: newSession)
                }
              } label: {
                HStack(spacing: 8) {
                  Image(systemName: "arrow.right.circle.fill")
                  Text("Next Level")
                }
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(session.gameType.color, in: RoundedRectangle(cornerRadius: 12))
              }
              .opacity(isVisible ? 1 : 0)
              .offset(y: isVisible ? 0 : 30)
              .animation(.easeOut(duration: 0.4).delay(0.5), value: isVisible)
            }
            
            HStack(spacing: 12) {
              Button {
                coordinator.dismissFullScreen()
              } label: {
                HStack(spacing: 8) {
                  Image(systemName: "house.fill")
                  Text("Home")
                }
                .fontWeight(.semibold)
                .foregroundStyle(isPracticeMode ? session.gameType.color : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isPracticeMode ? Color.clear : session.gameType.color, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                  isPracticeMode ?
                  RoundedRectangle(cornerRadius: 12)
                    .stroke(session.gameType.color, lineWidth: 2) : nil
                )
              }
              .opacity(isVisible ? 1 : 0)
              .offset(y: isVisible ? 0 : 30)
              .animation(.easeOut(duration: 0.4).delay(0.6), value: isVisible)
              
              Button {
                // replay logic
              } label: {
                HStack(spacing: 8) {
                  Image(systemName: "arrow.counterclockwise")
                  Text("Replay")
                }
                .fontWeight(.semibold)
                .foregroundStyle(session.gameType.color)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.clear)
                .overlay(
                  RoundedRectangle(cornerRadius: 12)
                    .stroke(session.gameType.color, lineWidth: 2)
                )
              }
              .opacity(isVisible ? 1 : 0)
              .offset(y: isVisible ? 0 : 30)
              .animation(.easeOut(duration: 0.4).delay(0.7), value: isVisible)
            }
          }
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 24)
        .offset(y: isVisible ? 0 : 300)
        .animation(.spring(duration: 0.8, bounce: 0.1), value: isVisible)
        
        Spacer()
          .frame(height: 50)
      }
    }
    .onAppear {
      // Delay to show completion animation first
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        withAnimation {
          isVisible = true
        }
      }
    }
    .sensoryFeedback(.success, trigger: isVisible)
  }
}

extension Notification.Name {
  static let loadNewPracticeLevel = Notification.Name("loadNewPracticeLevel")
  static let practiceSessionCompleted = Notification.Name("practiceSessionCompleted")
}
