import SwiftUI

struct SessionListView: View {
    @Environment(WatchStore.self) private var store

    var body: some View {
        NavigationStack {
            if let session = store.session {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title).font(.headline)
                            Text(session.subtitle).font(.footnote).foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }
                    ForEach(session.exercises) { ex in
                        NavigationLink {
                            ExerciseSetsView(exercise: ex)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.name).font(.body).lineLimit(2)
                                    Text(ex.detail).font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                let done = store.confirmed[ex.id]?.count ?? 0
                                Text("\(done)/\(ex.sets.count)")
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(done == ex.sets.count ? WatchTheme.copper : .secondary)
                            }
                        }
                    }
                    Section {
                        Button(store.finished ? "Sent to iPhone ✓" : "Finish") { store.finish() }
                            .disabled(store.finished || store.confirmedCount == 0)
                            .tint(WatchTheme.copper)
                    }
                }
                .navigationTitle("Today")
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "bolt.fill").foregroundStyle(WatchTheme.copper).font(.title2)
                    Text("Open FlexFit on your iPhone to send today's session.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }
}

struct ExerciseSetsView: View {
    let exercise: WatchSession.Exercise
    @Environment(WatchStore.self) private var store

    var body: some View {
        List {
            ForEach(exercise.sets.indices, id: \.self) { i in
                let done = store.confirmed[exercise.id]?.contains(i) == true
                Button { store.toggle(exercise.id, set: i) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Set \(i + 1)").font(.footnote).foregroundStyle(.secondary)
                            Text(describe(exercise.sets[i])).font(.body)
                        }
                        Spacer()
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(done ? WatchTheme.copper : .secondary)
                            .font(.title3)
                    }
                }
                .accessibilityLabel("Set \(i + 1), \(describe(exercise.sets[i])), \(done ? "done" : "not done")")
            }
        }
        .navigationTitle(exercise.name)
    }

    private func describe(_ s: WatchSet) -> String {
        let value = exercise.isTimed ? "\(s.value) s" : "\(s.value) reps"
        guard let kg = s.loadKg else { return value }
        return "\(value) · \(kg.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }
}
