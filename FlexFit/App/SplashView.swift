import SwiftUI

/// The splash that follows the system launch screen. It opens on exactly what the launch screen showed —
/// the icon tile, centred on navy — so the hand-off is seamless, then lifts the icon and brings in the name,
/// the promise and the three things the app joins up, before fading into the app.
struct SplashView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false
    @State private var showText = false
    @State private var showPills = false
    @State private var progress: CGFloat = 0

    /// Matches LaunchLogo: a 132 pt tile.
    private let tile: CGFloat = 132

    /// How far the icon rises once the words come in.
    private let lift: CGFloat = 70

    var body: some View {
        // Laid out on the full screen, like the launch screen, so the first frame is identical to it: the icon
        // sits at the exact centre and nothing else takes space until it animates in.
        GeometryReader { geo in
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                background(centre: centre)

                icon
                    .scaleEffect(settled ? 0.92 : 1)
                    .position(x: centre.x, y: centre.y - (settled ? lift : 0))

                VStack(spacing: Space.sm) {
                    Text("FlexFit")
                        .textStyle(.display)
                        .foregroundStyle(Palette.onPanel)
                    Text("Train and eat on the day you actually got.")
                        .textStyle(.body)
                        .foregroundStyle(Palette.onPanelMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Space.xs) {
                        pill("Training", systemImage: "dumbbell.fill", tint: Palette.ice)
                        pill("Food", systemImage: "fork.knife", tint: Palette.copper)
                        pill("One plan", systemImage: "point.topleft.down.to.point.bottomright.curvepath", tint: Palette.onPanel)
                    }
                    .opacity(showPills ? 1 : 0)
                    .offset(y: showPills ? 0 : Space.sm)
                    .padding(.top, Space.xs)
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, Space.xl)
                .opacity(showText ? 1 : 0)
                .offset(y: showText ? 0 : Space.md)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                // Just under where the icon settles (the icon asset is tile + 48 tall, its glow margin included).
                .padding(.top, centre.y - lift + tile / 2 + Space.lg)

                progressBar
                    .opacity(showText ? 1 : 0)
                    .position(x: centre.x, y: geo.size.height - geo.safeAreaInsets.bottom - Space.xl * 2)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("FlexFit. Train and eat on the day you actually got.")
        .task { await run() }
    }

    // MARK: Parts

    /// Flat navy at first — what the launch screen shows — then a teal bloom behind the icon and a copper warmth
    /// low down fade in as it settles.
    private func background(centre: CGPoint) -> some View {
        ZStack {
            Palette.navy
            RadialGradient(colors: [Color(red: 0.16, green: 0.62, blue: 0.72).opacity(0.35), .clear],
                           center: .center, startRadius: 0, endRadius: 320)
                .offset(y: -lift)
                .opacity(settled ? 1 : 0)
            RadialGradient(colors: [Palette.copper.opacity(0.18), .clear],
                           center: .bottom, startRadius: 0, endRadius: 420)
                .opacity(settled ? 1 : 0)
        }
    }

    private var icon: some View {
        Image("LaunchLogo")
            .resizable()
            .scaledToFit()
            .frame(width: tile + 48, height: tile + 48)   // the asset includes a 24 pt glow margin each side
            .accessibilityHidden(true)
    }

    private func pill(_ title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .textStyle(.micro)
            .foregroundStyle(tint)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xs - 2)
            .background(tint.opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.22), lineWidth: 1))
    }

    private var progressBar: some View {
        Capsule()
            .fill(Palette.onPanelHairline)
            .frame(width: 120, height: 3)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: [Palette.copper, Palette.sand], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 120 * progress, height: 3)
            }
    }

    // MARK: Timing

    private func run() async {
        if reduceMotion {
            settled = true; showText = true; showPills = true; progress = 1
            try? await Task.sleep(for: .milliseconds(700))
            onFinish()
            return
        }
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) { settled = true }
        withAnimation(.easeOut(duration: 1.3)) { progress = 1 }
        try? await Task.sleep(for: .milliseconds(220))
        withAnimation(.easeOut(duration: 0.45)) { showText = true }
        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { showPills = true }
        try? await Task.sleep(for: .milliseconds(950))
        onFinish()
    }
}

#Preview {
    SplashView {}
}
