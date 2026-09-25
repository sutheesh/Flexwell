import SwiftUI
import SwiftData
import FlexFitEngine

/// Intro → wizard → building → plan ready. Saves the profile on "Start today".
struct OnboardingFlow: View {
    enum Phase: Equatable {
        case intro, wizard, building, ready
    }

    @Environment(\.modelContext) private var modelContext
    @State private var draft = OnboardingDraft()
    @State private var phase: Phase = .intro
    @State private var stepIndex = 0
    @State private var profile: UserProfile?

    var body: some View {
        ZStack {
            switch phase {
            case .intro:
                IntroView {
                    stepIndex = 0
                    phase = .wizard
                }
                .transition(.opacity)
            case .wizard:
                WizardView(draft: draft, stepIndex: $stepIndex, onExit: { phase = .intro }, onFinish: finishWizard)
                    .transition(.opacity)
            case .building:
                BuildingView { phase = .ready }
                    .transition(.opacity)
            case .ready:
                if let profile {
                    PlanReadyView(profile: profile, onStart: { save(profile) })
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phase)
    }

    private func finishWizard() {
        guard let made = draft.makeProfile() else { return }
        profile = made
        phase = .building
    }

    private func save(_ profile: UserProfile) {
        modelContext.insert(ProfileRecord(profile: profile))
        try? modelContext.save()
        Task { await Reminders.schedule(time: profile.reminder, tone: profile.tone) }
    }
}

#Preview("Onboarding") {
    OnboardingFlow()
        .modelContainer(for: ProfileRecord.self, inMemory: true)
}
