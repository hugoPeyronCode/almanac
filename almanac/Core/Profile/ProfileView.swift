//
//  ProfileView.swift
//  almanac
//
//  Player profile with badges and customization
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profile: [PlayerProfile]
    @Query private var badges: [PlayerBadge]
    
    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var selectedBackground = "dotsBackgroundWhite"
    @State private var showingBackgroundPicker = false
    
    private var currentProfile: PlayerProfile? {
        profile.first
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundView
                
                ScrollView {
                    VStack(spacing: 24) {
                        profileHeader
                            .padding(.top, 20)
                        
                        levelProgressView
                        
                        badgesSection
                        
                        customizationSection
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            setupProfile()
        }
        .sheet(isPresented: $showingBackgroundPicker) {
            BackgroundPickerView(selectedBackground: $selectedBackground) { newBackground in
                updateBackground(newBackground)
            }
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar placeholder
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                
                Text(currentProfile?.username.prefix(2).uppercased() ?? "PL")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            // Username
            HStack {
                if isEditingName {
                    TextField("Username", text: $editedName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                        .onSubmit {
                            updateUsername()
                        }
                } else {
                    Text(currentProfile?.username ?? "Player")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Button {
                        editedName = currentProfile?.username ?? ""
                        isEditingName = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Member since
            if let createdDate = currentProfile?.createdAt {
                Text("Playing since \(createdDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Level Progress
    
    private var levelProgressView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level \(currentProfile?.level ?? 1)")
                        .font(.headline)
                    
                    Text("\(currentProfile?.experience ?? 0) XP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Next level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("\(experienceToNextLevel) XP")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * levelProgress, height: 12)
                }
            }
            .frame(height: 12)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Badges Section
    
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Badges")
                    .font(.headline)
                
                Spacer()
                
                Text("\(badges.count)/\(BadgeType.allCases.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                ForEach(BadgeType.allCases, id: \.self) { badgeType in
                    BadgeView(
                        type: badgeType,
                        isUnlocked: badges.contains { $0.type == badgeType },
                        isNew: badges.first { $0.type == badgeType }?.isNew ?? false
                    )
                }
            }
        }
    }
    
    // MARK: - Customization Section
    
    private var customizationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Customization")
                .font(.headline)
            
            Button {
                showingBackgroundPicker = true
            } label: {
                HStack {
                    Image(systemName: "photo")
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Background Image")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        
                        Text("Tap to change")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Background View
    
    @ViewBuilder
    private var backgroundView: some View {
        if let imageName = currentProfile?.backgroundImageName,
           let uiImage = UIImage(named: imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .blur(radius: 20)
                .overlay(Color.black.opacity(0.4))
        } else {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
        }
    }
    
    // MARK: - Helper Methods
    
    private var levelProgress: CGFloat {
        guard let profile = currentProfile else { return 0 }
        let currentLevelXP = profile.experience % 1000
        return CGFloat(currentLevelXP) / 1000.0
    }
    
    private var experienceToNextLevel: Int {
        guard let profile = currentProfile else { return 1000 }
        return 1000 - (profile.experience % 1000)
    }
    
    private func setupProfile() {
        if currentProfile == nil {
            let newProfile = PlayerProfile()
            modelContext.insert(newProfile)
            try? modelContext.save()
        }
    }
    
    private func updateUsername() {
        guard !editedName.isEmpty else { return }
        currentProfile?.username = editedName
        currentProfile?.lastUpdated = Date()
        try? modelContext.save()
        isEditingName = false
    }
    
    private func updateBackground(_ imageName: String) {
        currentProfile?.backgroundImageName = imageName
        currentProfile?.lastUpdated = Date()
        try? modelContext.save()
    }
}

// MARK: - Badge View

struct BadgeView: View {
    let type: BadgeType
    let isUnlocked: Bool
    let isNew: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? type.backgroundColor : Color.secondary.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundStyle(isUnlocked ? .white : .secondary)
                
                if isNew {
                    Circle()
                        .fill(.red)
                        .frame(width: 12, height: 12)
                        .offset(x: 20, y: -20)
                }
            }
            
            Text(type.name)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(isUnlocked ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Background Picker

struct BackgroundPickerView: View {
    @Binding var selectedBackground: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    // Available backgrounds
    let backgrounds = [
        "dotsBackgroundWhite",
        "dotsBackgroundDark"
        // Add more as they're added to assets
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    ForEach(backgrounds, id: \.self) { imageName in
                        Button {
                            selectedBackground = imageName
                            onSelect(imageName)
                            dismiss()
                        } label: {
                            ZStack {
                                if let uiImage = UIImage(named: imageName) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 150)
                                        .clipped()
                                        .cornerRadius(12)
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 150)
                                }
                                
                                if selectedBackground == imageName {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue, lineWidth: 3)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Background")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Badge color extension
extension BadgeType {
    var backgroundColor: Color {
        switch self {
        case .firstWin: return .yellow
        case .weekStreak, .monthStreak: return .orange
        case .speedDemon: return .red
        case .perfectWeek: return .purple
        case .puzzleMaster: return .indigo
        case .marathonRunner: return .green
        case .sprinter: return .cyan
        case .allGamesDaily: return .pink
        case .hundredPuzzles: return .blue
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [PlayerProfile.self, PlayerBadge.self], inMemory: true)
}
