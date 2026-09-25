import SwiftUI

/// First launch. Always dark by design (mock: navy ground in both appearances),
/// so everything here uses fixed tokens rather than roles.
struct IntroView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            hero
            content
        }
        .background(Palette.navy.ignoresSafeArea())
    }

    private var hero: some View {
        // The image lives in an overlay so its ideal width can't widen the column.
        Rectangle()
            .fill(Palette.navyRaised)
            .overlay {
                Image("Illustration-hero")
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: Palette.navy.opacity(0.1), location: 0),
                        .init(color: Palette.navy.opacity(0.25), location: 0.55),
                        .init(color: Palette.navy, location: 0.99),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .overlay(alignment: .top) {
                // Same column as the text below, so it lines up on iPad too.
                HStack {
                    logo
                    Spacer()
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.md)
                .readableColumn()
            }
            .accessibilityHidden(true)
    }

    private var logo: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "bolt.fill")
                .font(TextStyle.label.font)
                .foregroundStyle(Palette.navy)
                .frame(width: Size.logoTile, height: Size.logoTile)
                .background(Palette.ice, in: RoundedRectangle(cornerRadius: Radius.xs))
            Text("FlexFit")
                .textStyle(.button)
                .foregroundStyle(Palette.onPanel)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.xs - 1) {
                pill("Training", fg: Palette.ice, bg: Palette.ice.opacity(0.16))
                pill("Targets", fg: Palette.copper, bg: Palette.copper.opacity(0.18))
                pill("One plan", fg: Palette.onPanel.opacity(0.75), bg: Palette.onPanelHairline)
            }
            .padding(.bottom, Space.md)

            Text("Train and eat on the day you actually got.")
                .textStyle(.display)
                .foregroundStyle(Palette.onPanel)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("A few quick questions. Then a week-by-week plan that bends when life does.")
                .textStyle(.body)
                .foregroundStyle(Palette.onPanelMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.sm + 2)
                .padding(.bottom, Space.xl)

            IceButton(title: "Build my plan", action: onStart)
        }
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.md)
        .readableColumn()
    }

    private func pill(_ text: String, fg: Color, bg: Color) -> some View {
        Text(text)
            .textStyle(.kicker)
            .foregroundStyle(fg)
            .padding(.horizontal, Space.sm - 1)
            .padding(.vertical, Space.xs - 1)
            .background(bg, in: Capsule())
    }
}

#Preview { IntroView {} }
