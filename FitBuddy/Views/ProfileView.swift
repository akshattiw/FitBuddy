import SwiftUI

/// Decoupled Profile and Settings view allowing editing of user details and gender.
/// AGENTS.md Rule 3: Decouple Profile & Settings from HomeView.
public struct ProfileView: View {
    @Bindable public var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Personal Info") {
                    TextField("Name", text: $appState.profileManager.profile.name)
                }
                
                Section("Gender Profile") {
                    Picker("Gender", selection: Binding(
                        get: { appState.profileManager.profile.gender ?? .preferNotToSay },
                        set: { newGender in
                            appState.updateGender(newGender)
                        }
                    )) {
                        ForEach(UserGender.allCases) { gender in
                            Text(gender.rawValue).tag(gender)
                        }
                    }
                    
                    Text("Selecting Female displays the Cycle tab in the bottom navigation. Changing this updates tab visibility immediately without deleting cycle history.")
                        .font(AppTheme.Typography.micro)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Section("Tracking & Privacy") {
                    Toggle("Menstrual Cycle Tracking", isOn: Binding(
                        get: { appState.cycleManager.data.isTrackingEnabled },
                        set: {
                            appState.cycleManager.toggleTracking(enabled: $0)
                            appState.save()
                        }
                    ))
                    
                    Toggle("Cycle Informs Workout Intensity", isOn: Binding(
                        get: { appState.cycleManager.data.allowWorkoutAdaptation },
                        set: {
                            appState.cycleManager.toggleWorkoutAdaptation(allowed: $0)
                            appState.save()
                        }
                    ))
                }
                
                Section("Data Storage") {
                    HStack {
                        Text("Persistence Engine")
                        Spacer()
                        Text("Local Encrypted JSON")
                            .foregroundColor(AppColors.secondaryText)
                    }
                    HStack {
                        Text("Completed Workouts")
                        Spacer()
                        Text("\(appState.workoutHistoryStore.totalWorkoutsCompleted)")
                            .foregroundColor(AppColors.secondaryText)
                    }
                    HStack {
                        Text("Total XP Earned")
                        Spacer()
                        Text("\(appState.rewardStore.state.totalXP) XP")
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
            }
            .navigationTitle("Profile & Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        appState.save()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.mint)
                }
            }
        }
    }
}
