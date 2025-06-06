//
//  PracticeModeComponents.swift
//  almanac
//
//  UI components for practice mode features
//

import SwiftUI
import Foundation

// MARK: - Mode Button

struct ModeButton: View {
    let mode: PracticeMode
    let isSelected: Bool
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : mode.color)
                
                Text(mode.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if isActive {
                    Text("Active")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? mode.color : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Marathon Status Card

struct MarathonStatusCard: View {
    let count: Int
    let isActive: Bool
    let onEnd: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Marathon Mode", systemImage: "infinity")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("Complete as many puzzles as you can!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isActive {
                    Button("End") {
                        onEnd()
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.1))
                    )
                }
            }
            
            HStack(spacing: 24) {
                StatItem(
                    value: "\(count)",
                    label: "Completed",
                    color: .green
                )
                
                StatItem(
                    value: isActive ? "Active" : "Ready",
                    label: "Status",
                    color: isActive ? .green : .orange
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Sprint Status Card

struct SprintStatusCard: View {
    let count: Int
    let startTime: Date?
    let isActive: Bool
    let onEnd: () -> Void
    
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Sprint Mode", systemImage: "timer")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("Complete 5 puzzles as fast as possible!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isActive {
                    Button("End") {
                        onEnd()
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.1))
                    )
                }
            }
            
            HStack(spacing: 24) {
                StatItem(
                    value: "\(count)/5",
                    label: "Progress",
                    color: .cyan
                )
                
                StatItem(
                    value: formatTime(elapsedTime),
                    label: "Time",
                    color: .orange
                )
            }
            
            if count >= 5 {
                Text("🎉 Sprint Complete!")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }
    
    private func startTimer() {
        guard isActive, startTime != nil else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let start = startTime {
                elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Mode Info Sheet

struct ModeInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(PracticeMode.allCases, id: \.self) { mode in
                        ModeInfoCard(mode: mode)
                    }
                }
                .padding()
            }
            .navigationTitle("Practice Modes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Mode Info Card

struct ModeInfoCard: View {
    let mode: PracticeMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(mode.displayName, systemImage: mode.icon)
                .font(.headline)
                .foregroundStyle(mode.color)
            
            Text(mode.description)
                .font(.body)
                .foregroundStyle(.secondary)
            
            switch mode {
            case .normal:
                Text("• Play at your own pace\n• No time pressure\n• Perfect for learning")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
            case .marathon:
                Text("• Keep playing until you quit\n• Track your longest streak\n• Unlock the Marathon Runner badge")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
            case .sprint:
                Text("• Complete 5 puzzles quickly\n• Race against the clock\n• Unlock the Sprint Champion badge")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

// MARK: - Mode Colors

extension PracticeMode {
    var color: Color {
        switch self {
        case .normal: return .blue
        case .marathon: return .green
        case .sprint: return .orange
        }
    }
}