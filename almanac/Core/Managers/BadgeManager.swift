//
//  BadgeManager.swift
//  almanac
//
//  Manages badge unlocking and progress tracking
//

import SwiftUI
import SwiftData

@Observable
class BadgeManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // Check and unlock badges based on current stats
    func checkAndUnlockBadges(profile: PlayerProfile) {
        checkFirstWin()
        checkStreakBadges()
        checkSpeedBadge()
        checkPerfectWeek()
        checkLevelBadge(profile: profile)
        checkPuzzleCountBadges()
        checkDailyVarietyBadge()
    }
    
    private func checkFirstWin() {
        let badge = BadgeType.firstWin
        if !hasBadge(badge) {
            let completions = try? modelContext.fetch(FetchDescriptor<DailyCompletion>())
            let practiceCompletions = try? modelContext.fetch(FetchDescriptor<PracticeSession>())
            
            if (completions?.count ?? 0) > 0 || (practiceCompletions?.filter { $0.isCompleted }.count ?? 0) > 0 {
                unlockBadge(badge)
            }
        }
    }
    
    private func checkStreakBadges() {
        // Check 7-day streak
        if !hasBadge(.weekStreak) {
            let maxStreak = calculateMaxStreak()
            if maxStreak >= 7 {
                unlockBadge(.weekStreak)
            }
        }
        
        // Check 30-day streak
        if !hasBadge(.monthStreak) {
            let maxStreak = calculateMaxStreak()
            if maxStreak >= 30 {
                unlockBadge(.monthStreak)
            }
        }
    }
    
    private func checkSpeedBadge() {
        if !hasBadge(.speedDemon) {
            let fastCompletions = try? modelContext.fetch(
                FetchDescriptor<DailyCompletion>(
                    predicate: #Predicate { $0.completionTime < 60 }
                )
            )
            
            let fastPractice = try? modelContext.fetch(
                FetchDescriptor<PracticeSession>(
                    predicate: #Predicate { $0.completionTime < 60 && $0.isCompleted }
                )
            )
            
            if (fastCompletions?.count ?? 0) > 0 || (fastPractice?.count ?? 0) > 0 {
                unlockBadge(.speedDemon)
            }
        }
    }
    
    private func checkPerfectWeek() {
        if !hasBadge(.perfectWeek) {
            let calendar = Calendar.current
            let today = Date()
            let weekAgo = calendar.date(byAdding: .day, value: -6, to: today)!
            
            var perfectDays = 0
            for dayOffset in 0...6 {
                let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
                if hasCompletedAllGamesForDate(date) {
                    perfectDays += 1
                }
            }
            
            if perfectDays >= 7 {
                unlockBadge(.perfectWeek)
            }
        }
    }
    
    private func checkLevelBadge(profile: PlayerProfile) {
        if !hasBadge(.puzzleMaster) && profile.level >= 10 {
            unlockBadge(.puzzleMaster)
        }
    }
    
    private func checkPuzzleCountBadges() {
        if !hasBadge(.hundredPuzzles) {
            let totalCompletions = (try? modelContext.fetch(FetchDescriptor<DailyCompletion>()).count) ?? 0
            let totalPractice = (try? modelContext.fetch(
                FetchDescriptor<PracticeSession>(
                    predicate: #Predicate { $0.isCompleted }
                )
            ).count) ?? 0
            
            if totalCompletions + totalPractice >= 100 {
                unlockBadge(.hundredPuzzles)
            }
        }
    }
    
    private func checkDailyVarietyBadge() {
        if !hasBadge(.allGamesDaily) {
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            
            let todayCompletions = try? modelContext.fetch(
                FetchDescriptor<DailyCompletion>(
                    predicate: #Predicate { completion in
                        completion.date >= today && completion.date < tomorrow
                    }
                )
            )
            
            let uniqueGames = Set(todayCompletions?.map { $0.gameType } ?? [])
            if uniqueGames.count == GameType.allCases.count {
                unlockBadge(.allGamesDaily)
            }
        }
    }
    
    // Practice mode specific badges
    func checkMarathonBadge(completedCount: Int) {
        if !hasBadge(.marathonRunner) && completedCount >= 10 {
            unlockBadge(.marathonRunner)
        }
    }
    
    func checkSprintBadge(totalTime: TimeInterval, completedCount: Int) {
        if !hasBadge(.sprinter) && completedCount >= 5 && totalTime < 300 { // 5 minutes
            unlockBadge(.sprinter)
        }
    }
    
    // Helper methods
    private func hasBadge(_ type: BadgeType) -> Bool {
        let descriptor = FetchDescriptor<PlayerBadge>(
            predicate: #Predicate { $0.type == type }
        )
        return (try? modelContext.fetch(descriptor).first) != nil
    }
    
    private func unlockBadge(_ type: BadgeType) {
        let badge = PlayerBadge(type: type)
        modelContext.insert(badge)
        
        // Award experience points
        if let profile = getPlayerProfile() {
            profile.addExperience(type.requiredPoints)
        }
        
        try? modelContext.save()
        
        // Post notification for UI update
        NotificationCenter.default.post(name: .badgeUnlocked, object: type)
    }
    
    private func getPlayerProfile() -> PlayerProfile? {
        let descriptor = FetchDescriptor<PlayerProfile>()
        return try? modelContext.fetch(descriptor).first
    }
    
    private func calculateMaxStreak() -> Int {
        // Implementation would calculate max streak from GameProgress
        let progresses = try? modelContext.fetch(FetchDescriptor<GameProgress>())
        return progresses?.map { $0.maxStreak }.max() ?? 0
    }
    
    private func hasCompletedAllGamesForDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let completions = try? modelContext.fetch(
            FetchDescriptor<DailyCompletion>(
                predicate: #Predicate { completion in
                    completion.date >= startOfDay && completion.date < endOfDay
                }
            )
        )
        
        let uniqueGames = Set(completions?.map { $0.gameType } ?? [])
        return uniqueGames.count == GameType.allCases.count
    }
}

extension Notification.Name {
    static let badgeUnlocked = Notification.Name("badgeUnlocked")
}