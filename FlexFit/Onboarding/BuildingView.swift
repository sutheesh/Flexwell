import SwiftUI

/// "Building your plan". The engine is instant; this is a short, honest beat that
/// finishes well inside the PRD's 2-second budget. Always dark by design.
struct BuildingView: View {
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 0.0
    @State private var lineIndex = 0
    @State private var spinning = false

    private let lines = ["Reading your constraints", "Sizing your energy needs", "Programming your week",
                         "Picking food you’ll actually eat", "Your path is ready"]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().stroke(Palette.onPanelHairline, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(Palette.ice, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                Circle()
                    .trim(from: 0.25, to: 0.5)
                    .stroke(Palette.copper, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            .frame(width: Size.spinner, height: Size.spinner)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .accessibilityHidden(true)

            Text(lines[lineIndex])
                .textStyle(.title2)
                .foregroundStyle(Palette.onPanel)
                .multilineTextAlignment(.center)
                .padding(.top, Space.xxl + 2)
                .contentTransition(.opacity)

            Capsule()
                .fill(Palette.onPanelHairline)
                .frame(maxWidth: Size.progressTrack, maxHeight: Size.progressBar)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(Palette.ice)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .padding(.top, Space.lg + 2)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.navy.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .task { await run() }
    }

    private func run() async {
        if !reduceMotion {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { spinning = true }
        }
        for i in lines.indices {
            withAnimation(.easeOut(duration: 0.3)) {
                lineIndex = i
                progress = Double(i + 1) / Double(lines.count)
            }
            // Five beats inside the PRD's 2-second budget.
            try? await Task.sleep(for: .milliseconds(i == lines.count - 1 ? 300 : 320))
        }
        onDone()
    }
}

#Preview { BuildingView {} }
