import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: .now, snapshot: .placeholder) }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .placeholder)
        // The app reloads timelines on every change; refresh at midnight so yesterday never lingers.
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

/// Always-dark like the mock's panels: fixed tokens.
struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        let s = entry.snapshot
        let stale = !Calendar.current.isDateInToday(s.date)
        Group {
            if family == .systemSmall {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Label(s.isTrainingDay ? "Today" : "Recovery", systemImage: "bolt.fill")
                        .textStyle(.micro)
                        .foregroundStyle(Palette.copper)
                    Text(stale ? "Open FlexFit" : s.sessionTitle)
                        .textStyle(.headline)
                        .foregroundStyle(Palette.onPanel)
                        .lineLimit(2)
                    Text(s.sessionDetail)
                        .textStyle(.micro)
                        .foregroundStyle(Palette.onPanelMuted)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(s.kcalEaten.formatted()) / \(s.kcalTarget.formatted()) kcal")
                        .textStyle(.micro)
                        .foregroundStyle(Palette.ice)
                }
            } else {
                HStack(alignment: .top, spacing: Space.md) {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Label("Today", systemImage: "bolt.fill")
                            .textStyle(.micro)
                            .foregroundStyle(Palette.copper)
                        Text(stale ? "Open FlexFit" : s.sessionTitle)
                            .textStyle(.headline)
                            .foregroundStyle(Palette.onPanel)
                            .lineLimit(2)
                        Text(s.sessionDetail)
                            .textStyle(.micro)
                            .foregroundStyle(Palette.onPanelMuted)
                        Spacer(minLength: 0)
                        if s.streakWeeks > 0 {
                            Text("🔥 \(s.streakWeeks)-week streak")
                                .textStyle(.micro)
                                .foregroundStyle(Palette.ice)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text("Food").textStyle(.micro).foregroundStyle(Palette.onPanelMuted)
                        Text("\(s.kcalEaten.formatted())").textStyle(.title2).foregroundStyle(Palette.onPanel)
                        Text("of \(s.kcalTarget.formatted()) kcal").textStyle(.micro).foregroundStyle(Palette.copper)
                        ProgressView(value: min(1, Double(s.kcalEaten) / Double(max(1, s.kcalTarget))))
                            .tint(Palette.copper)
                        Spacer(minLength: 0)
                        if let next = s.nextMeal {
                            Text("Next: \(next)")
                                .textStyle(.micro)
                                .foregroundStyle(Palette.onPanelMuted)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .containerBackground(for: .widget) { Palette.navy }
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FlexFitToday", provider: SnapshotProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Today's session and how much you've eaten.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct FlexFitWidgets: WidgetBundle {
    init() { FontRegistration.register() }
    var body: some Widget { TodayWidget() }
}
