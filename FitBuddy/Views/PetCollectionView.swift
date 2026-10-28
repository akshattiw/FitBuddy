import SwiftUI

/// Pet Collection view displaying owned companions, active selection, feeding/leveling, and locked requirements.
/// Sourced directly from authoritative shared AppState and RewardStore XP balance.
public struct PetCollectionView: View {
    @Bindable public var petStore: PetCompanionStore
    @Bindable public var rewardStore: RewardStore
    public var onFeedPet: ((String) -> FeedPetResult)?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Locked pet explanation alert state
    @State private var selectedLockedPet: Pet? = nil
    @State private var showingLockedAlert: Bool = false
    
    // Transient feeding feedback tracking per pet
    @State private var feedFeedback: [String: String] = [:]
    @State private var isFeedingInFlight: Bool = false
    
    public init(
        petStore: PetCompanionStore = PetCompanionStore(),
        rewardStore: RewardStore = RewardStore(),
        onFeedPet: ((String) -> FeedPetResult)? = nil
    ) {
        self.petStore = petStore
        self.rewardStore = rewardStore
        self.onFeedPet = onFeedPet
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    // MARK: - Header & Available XP Balance
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                                Text("Pet Collection")
                                    .font(AppTheme.Typography.screenTitle)
                                    .foregroundColor(AppColors.primaryText)
                                
                                Text("Choose your workout companion and feed them with earned XP to level up.")
                                    .font(AppTheme.Typography.body)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            
                            Spacer()
                            
                            // Authoritative XP Balance Pill from Rewards
                            availableXPPill
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.large)
                    .padding(.top, AppTheme.Spacing.small)
                    
                    // MARK: - Section 1: Owned Companions
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        HStack {
                            Text("Owned Companions")
                                .font(AppTheme.Typography.sectionHeading)
                                .foregroundColor(AppColors.primaryText)
                            
                            Spacer()
                            
                            Text("\(petStore.ownedPets.count) Owned")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .padding(.horizontal, AppTheme.Spacing.large)
                        
                        VStack(spacing: AppTheme.Spacing.medium) {
                            ForEach(petStore.ownedPets) { pet in
                                ownedPetCard(pet: pet)
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.large)
                    }
                    
                    // MARK: - Section 2: Locked Companions
                    if !petStore.lockedPets.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                            HStack {
                                Text("Locked Companions")
                                    .font(AppTheme.Typography.sectionHeading)
                                    .foregroundColor(AppColors.primaryText)
                                
                                Spacer()
                                
                                Text("\(petStore.lockedPets.count) Locked")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            .padding(.horizontal, AppTheme.Spacing.large)
                            .padding(.top, AppTheme.Spacing.small)
                            
                            VStack(spacing: AppTheme.Spacing.medium) {
                                ForEach(petStore.lockedPets) { pet in
                                    lockedPetCard(pet: pet)
                                }
                            }
                            .padding(.horizontal, AppTheme.Spacing.large)
                        }
                    }
                    
                    Spacer().frame(height: 32)
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Pet Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(AppTheme.Typography.cardTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.mint)
                }
            }
            .alert(
                selectedLockedPet?.displayName ?? "Locked Companion",
                isPresented: $showingLockedAlert,
                presenting: selectedLockedPet
            ) { _ in
                Button("Got It", role: .cancel) {}
            } message: { pet in
                Text("\(pet.unlockRequirement.explanation)\n\nKeep progressing in FitBuddy to unlock this companion!")
            }
            .onAppear {
                petStore.evaluateHungerAndSurvival()
            }
        }
    }
    
    // MARK: - Available XP Pill
    private var availableXPPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.mint)
            Text("\(rewardStore.state.totalXP) XP")
                .font(AppTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColors.mint.opacity(0.18))
        .clipShape(Capsule())
        .accessibilityLabel("Available rewards balance: \(rewardStore.state.totalXP) XP")
    }
    
    // MARK: - Owned Pet Card
    private func ownedPetCard(pet: Pet) -> some View {
        let isAlive = pet.status.isAlive
        let hasSufficientXP = rewardStore.state.totalXP >= PetCompanionConstants.feedingXPCost
        let canFeed = pet.isUnlocked && isAlive && hasSufficientXP
        let remainingSeconds = pet.remainingTimeUntilStarvation()
        
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            // Top status bar: Active button/badge + Level badge + Vitality
            HStack {
                if pet.isActive {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(isAlive ? AppColors.mint : AppColors.secondaryText)
                            .frame(width: 8, height: 8)
                        
                        Text(isAlive ? "ACTIVE COMPANION" : "ACTIVE (PASSED AWAY)")
                            .font(AppTheme.Typography.micro)
                            .fontWeight(.bold)
                            .foregroundColor(isAlive ? AppColors.mint : AppColors.secondaryText)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background((isAlive ? AppColors.mint : AppColors.secondaryText).opacity(0.18))
                    .clipShape(Capsule())
                } else {
                    Button {
                        petStore.selectActivePet(id: pet.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 10))
                            Text("Set Active")
                                .font(AppTheme.Typography.micro)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.secondaryCardBackground)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Current Level Badge
                Text("Lvl \(pet.level)")
                    .font(AppTheme.Typography.micro)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.lavender.opacity(0.6))
                    .clipShape(Capsule())
                
                // Vitality Status Badge
                vitalityBadge(status: pet.status)
            }
            
            // Content Row: Artwork + Details (Tappable to make active)
            Button {
                if !pet.isActive {
                    petStore.selectActivePet(id: pet.id)
                }
            } label: {
                HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                    ZStack {
                        Circle()
                            .fill(pet.isActive ? (isAlive ? AppColors.softPink.opacity(0.6) : AppColors.secondaryCardBackground) : AppColors.secondaryCardBackground)
                            .frame(width: 76, height: 76)
                        
                        PetArtworkView(
                            artwork: pet.artwork,
                            isLocked: false,
                            isDeceased: !isAlive,
                            size: 60
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(pet.displayName)
                                .font(AppTheme.Typography.cardTitle)
                                .foregroundColor(AppColors.primaryText)
                            
                            Text("• \(pet.name)")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        Text(pet.description)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Hunger Countdown / Status row for living pet
                        if isAlive {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.system(size: 10))
                                    .foregroundColor(remainingSeconds < 24 * 3600 ? AppColors.peachAccent : AppColors.secondaryText)
                                Text(starvationCountdownText(seconds: remainingSeconds))
                                    .font(AppTheme.Typography.micro)
                                    .foregroundColor(remainingSeconds < 24 * 3600 ? AppColors.peachAccent : AppColors.secondaryText)
                            }
                            .padding(.top, 2)
                        }
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            // Success Feedback Banner (if just fed)
            if let message = feedFeedback[pet.id] {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(AppColors.mint)
                        .font(.system(size: 13, weight: .bold))
                    Text(message)
                        .font(AppTheme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.mint)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.mint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            Divider()
                .padding(.vertical, 2)
            
            // MARK: - Feeding Interaction Row
            if isAlive {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Feed Cost:")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppColors.secondaryText)
                            Text("\(PetCompanionConstants.feedingXPCost) XP")
                                .font(AppTheme.Typography.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primaryText)
                        }
                        
                        if !hasSufficientXP {
                            Text("Need 10 XP to feed (Available: \(rewardStore.state.totalXP) XP)")
                                .font(AppTheme.Typography.micro)
                                .foregroundColor(AppColors.secondaryText)
                        } else {
                            Text("+1 Level per feed")
                                .font(AppTheme.Typography.micro)
                                .foregroundColor(AppColors.mint)
                        }
                    }
                    
                    Spacer()
                    
                    // Atomic Feed Button
                    Button {
                        handleFeed(petId: pet.id)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 11, weight: .bold))
                            Text("Feed (10 XP)")
                                .font(AppTheme.Typography.micro)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(canFeed ? .white : AppColors.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(canFeed ? AppColors.mint : AppColors.secondaryCardBackground)
                        .clipShape(Capsule())
                        .appShadow(canFeed ? AppTheme.Shadows.softCard(colorScheme: colorScheme) : ShadowStyle(color: .clear, radius: 0, x: 0, y: 0))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canFeed || isFeedingInFlight)
                    .accessibilityLabel("Feed \(pet.displayName) for 10 XP. \(hasSufficientXP ? "Available." : "Disabled, insufficient XP.")")
                }
            } else {
                // Deceased Status Banner - Tasteful memorial record
                HStack(spacing: 8) {
                    Image(systemName: "heart.slash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.secondaryText)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This companion has passed away")
                            .font(AppTheme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("3 days elapsed without feeding. Historical record preserved.")
                            .font(AppTheme.Typography.micro)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.secondaryCardBackground.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous))
            }
        }
        .padding(AppTheme.Spacing.large)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                .stroke(pet.isActive ? (isAlive ? AppColors.mint : AppColors.secondaryText) : Color.clear, lineWidth: 2)
        )
        .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
    }
    
    // MARK: - Vitality Badge Helper
    private func vitalityBadge(status: PetLifeStatus) -> some View {
        let (tint, bg): (Color, Color) = {
            switch status {
            case .healthy, .energized, .resting:
                return (AppColors.mint, AppColors.mint.opacity(0.12))
            case .hungry:
                return (AppColors.peachAccent, AppColors.peach.opacity(0.4))
            case .starving:
                return (AppColors.peachAccent, AppColors.softPink.opacity(0.5))
            case .exhausted, .deceased:
                return (AppColors.secondaryText, AppColors.secondaryCardBackground)
            }
        }()
        
        return Text(status.displayLabel)
            .font(AppTheme.Typography.micro)
            .fontWeight(.medium)
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bg)
            .clipShape(Capsule())
    }
    
    // MARK: - Starvation Countdown Formatter
    private func starvationCountdownText(seconds: TimeInterval) -> String {
        let totalHours = Int(seconds) / 3600
        if totalHours >= 24 {
            let days = totalHours / 24
            let remainingHours = totalHours % 24
            return "Must feed in \(days)d \(remainingHours)h"
        } else if totalHours > 0 {
            return "Must feed in \(totalHours)h"
        } else {
            let minutes = max(1, Int(seconds) / 60)
            return "Must feed in \(minutes)m"
        }
    }
    
    // MARK: - Locked Pet Card
    private func lockedPetCard(pet: Pet) -> some View {
        Button {
            selectedLockedPet = pet
            showingLockedAlert = true
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                // Top status bar: Locked Badge
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                        Text("LOCKED")
                            .font(AppTheme.Typography.micro)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(AppColors.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.secondaryCardBackground)
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    // Unlock Requirement Summary Tag
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                        Text(pet.unlockRequirement.displayTitle)
                            .font(AppTheme.Typography.micro)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(AppColors.primaryText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(AppColors.peach.opacity(0.4))
                    .clipShape(Capsule())
                }
                
                // Content Row: Dimmed Artwork + Details
                HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                    ZStack {
                        Circle()
                            .fill(AppColors.secondaryCardBackground)
                            .frame(width: 76, height: 76)
                        
                        PetArtworkView(artwork: pet.artwork, isLocked: true, size: 60)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(pet.displayName)
                                .font(AppTheme.Typography.cardTitle)
                                .foregroundColor(AppColors.primaryText.opacity(0.8))
                            
                            Text("• \(pet.name)")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppColors.secondaryText.opacity(0.8))
                        }
                        
                        Text(pet.description)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppColors.secondaryText.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                }
            }
            .padding(AppTheme.Spacing.large)
            .background(AppColors.cardBackground.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
            .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pet.displayName), Locked. Requirement: \(pet.unlockRequirement.displayTitle). Tap for details.")
    }
    
    // MARK: - Feeding Handler
    private func handleFeed(petId: String) {
        guard !isFeedingInFlight else { return }
        isFeedingInFlight = true
        
        let result: FeedPetResult
        if let onFeedPet = onFeedPet {
            result = onFeedPet(petId)
        } else {
            result = petStore.feedPet(id: petId, rewardStore: rewardStore)
        }
        
        switch result {
        case .success(let newLevel, let petName):
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                feedFeedback[petId] = "Fed \(petName)! Now Level \(newLevel) 🎉"
            }
            // Auto-clear confirmation banner after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    _ = feedFeedback.removeValue(forKey: petId)
                }
            }
        case .insufficientXP:
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        default:
            break
        }
        
        // Brief debounce release
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isFeedingInFlight = false
        }
    }
}

#Preview {
    PetCollectionView(
        petStore: PetCompanionStore(),
        rewardStore: RewardStore(state: RewardInventoryState(totalXP: 50))
    )
}
