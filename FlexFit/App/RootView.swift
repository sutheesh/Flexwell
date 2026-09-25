import SwiftUI

enum AppTab: Hashable {
    case today, train, adapt, eat, path
}

/// The app's tab structure. ⚡ Adapt is a tab in the bar but an action in behaviour:
/// selecting it opens the adapt sheet and leaves the current tab selected.
struct RootView: View {
    @State private var selection: AppTab = .today
    @State private var isAdaptPresented = false

    var body: some View {
        TabView(selection: tabSelection) {
            Tab("Today", systemImage: "house", value: AppTab.today) {
                PlaceholderScreen(kicker: "Today", title: "Hi Alex")
            }
            Tab("Train", systemImage: "dumbbell", value: AppTab.train) {
                PlaceholderScreen(kicker: "Workout plan", title: "Schedule")
            }
            Tab("Adapt", systemImage: "bolt.fill", value: AppTab.adapt) {
                Color.clear
            }
            Tab("Eat", systemImage: "fork.knife", value: AppTab.eat) {
                PlaceholderScreen(kicker: "Daily targets", title: "Fuel")
            }
            Tab("Path", systemImage: "point.topleft.down.to.point.bottomright.curvepath", value: AppTab.path) {
                PlaceholderScreen(kicker: "Your path", title: "Progress")
            }
        }
        .sheet(isPresented: $isAdaptPresented) {
            PlaceholderScreen(kicker: "Adapt today", title: "What changed?")
                .presentationDetents([.medium, .large])
        }
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selection },
            set: { newValue in
                if newValue == .adapt {
                    isAdaptPresented = true
                } else {
                    selection = newValue
                }
            }
        )
    }
}

/// Temporary screen used until each tab is built. Draws only from tokens so the
/// scaffold itself exercises light and dark mode.
private struct PlaceholderScreen: View {
    let kicker: String
    let title: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(kicker)
                        .textStyle(.kicker)
                        .foregroundStyle(Palette.copperText)
                    Text(title)
                        .textStyle(.title1)
                        .foregroundStyle(Palette.ink)
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Daily food target")
                        .textStyle(.micro)
                        .foregroundStyle(Palette.onPanelMuted)
                    Text("2,050 kcal")
                        .textStyle(.metric)
                        .foregroundStyle(Palette.onPanel)
                    Text("Built from tokens")
                        .textStyle(.chip)
                        .foregroundStyle(Palette.navy)
                        .padding(.horizontal, Space.md)
                        .frame(height: Size.button)
                        .background(Palette.ice, in: Capsule())
                }
                .padding(Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.panel, in: RoundedRectangle(cornerRadius: Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Palette.panelEdge))

                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text("This screen is next")
                        .textStyle(.rowTitle)
                        .foregroundStyle(Palette.ink)
                    Text("Placeholder until it's built against the mock.")
                        .textStyle(.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
                .padding(Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.lg))
                .cardShadow()
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.md)
        }
        .pageBackground()
    }
}

#Preview("Light") { RootView() }
#Preview("Dark") { RootView().preferredColorScheme(.dark) }
