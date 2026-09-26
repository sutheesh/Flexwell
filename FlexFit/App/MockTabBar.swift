import SwiftUI

/// The floating tab bar, in the mock's style: a navy capsule with Gym, the raised copper ⚡ (Today) in the
/// middle and Eat, plus Profile split off as its own circle on the right. Navy in both appearances.
/// The active tab is copper, or ice on Gym (whose page is navy).
struct MockTabBar: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(spacing: Space.sm - 2) {
            HStack(spacing: 0) {
                item(.train, "Gym") { TabGlyph.Train() }
                todayButton
                item(.eat, "Eat") { TabGlyph.Eat() }
            }
            .frame(height: Size.tabBar)
            .background(Palette.navy, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.onPanel.opacity(0.07)))
            .shadow(color: Palette.navy.opacity(0.3), radius: 17, y: 14)

            // Split tab: Profile sits apart from the main bar.
            item(.profile, "Profile") { TabGlyph.Person() }
                .frame(width: Size.tabBar, height: Size.tabBar)
                .background(Palette.navy, in: Circle())
                .overlay(Circle().strokeBorder(Palette.onPanel.opacity(0.07)))
                .shadow(color: Palette.navy.opacity(0.3), radius: 17, y: 14)
        }
        .frame(maxWidth: Size.readableWidth)
        .padding(.horizontal, Space.md)
    }

    private func item<G: Shape>(_ tab: AppTab, _ title: String, glyph: () -> G) -> some View {
        let selected = router.tab == tab
        return Button { router.tab = tab } label: {
            VStack(spacing: Space.xxs + 1) {
                glyph()
                    .stroke(style: StrokeStyle(lineWidth: Size.tabIcon * 1.9 / 24, lineCap: .round, lineJoin: .round))
                    .frame(width: Size.tabIcon, height: Size.tabIcon)
                Text(title).textStyle(.tabLabel)
            }
            .foregroundStyle(selected ? (tab == .train ? Palette.ice : Palette.copper) : Palette.onPanel.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    /// Today: the raised ⚡, no label. Dimmed ring when another tab is showing.
    private var todayButton: some View {
        let selected = router.tab == .today
        return Button { router.tab = .today } label: {
            TabGlyph.Bolt()
                .fill(Palette.navy)
                .frame(width: Size.tabIcon + 3, height: Size.tabIcon + 3)
                .frame(width: Size.adaptButton, height: Size.adaptButton)
                .background(Palette.copper.opacity(selected ? 1 : 0.8), in: Circle())
                .overlay(Circle().strokeBorder(Palette.navy, lineWidth: 4))
                .shadow(color: Palette.copper.opacity(selected ? 0.38 : 0.15), radius: 10, y: 8)
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .offset(y: -Size.adaptLift)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Today")
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

/// The mock's tab icons, drawn from its 24 × 24 SVG paths.
enum TabGlyph {
    private static func scaled(_ rect: CGRect, _ build: (inout Path) -> Void) -> Path {
        var p = Path()
        build(&p)
        return p.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }

    /// M3 10.5 12 3l9 7.5 · M5.5 9.5V20h13V9.5
    struct Today: Shape {
        func path(in rect: CGRect) -> Path {
            TabGlyph.scaled(rect) { p in
                p.move(to: .init(x: 3, y: 10.5)); p.addLine(to: .init(x: 12, y: 3)); p.addLine(to: .init(x: 21, y: 10.5))
                p.move(to: .init(x: 5.5, y: 9.5)); p.addLine(to: .init(x: 5.5, y: 20))
                p.addLine(to: .init(x: 18.5, y: 20)); p.addLine(to: .init(x: 18.5, y: 9.5))
            }
        }
    }

    /// M4 8v8 M8 6v12 M16 6v12 M20 8v8 M8 12h8
    struct Train: Shape {
        func path(in rect: CGRect) -> Path {
            TabGlyph.scaled(rect) { p in
                for (x, y0, y1) in [(4.0, 8.0, 16.0), (8, 6, 18), (16, 6, 18), (20, 8, 16)] {
                    p.move(to: .init(x: x, y: y0)); p.addLine(to: .init(x: x, y: y1))
                }
                p.move(to: .init(x: 8, y: 12)); p.addLine(to: .init(x: 16, y: 12))
            }
        }
    }

    /// Fork (M6 3v8a2.5 2.5 0 0 0 5 0V3 · M8.5 13v8) and knife (M17 3c-1.4 2-2 4-2 6h4c0-2-.6-4-2-6z · M17 9v12).
    struct Eat: Shape {
        func path(in rect: CGRect) -> Path {
            TabGlyph.scaled(rect) { p in
                p.move(to: .init(x: 6, y: 3)); p.addLine(to: .init(x: 6, y: 11))
                p.addArc(center: .init(x: 8.5, y: 11), radius: 2.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
                p.addLine(to: .init(x: 11, y: 3))
                p.move(to: .init(x: 8.5, y: 13)); p.addLine(to: .init(x: 8.5, y: 21))
                p.move(to: .init(x: 17, y: 3))
                p.addCurve(to: .init(x: 15, y: 9), control1: .init(x: 15.6, y: 5), control2: .init(x: 15, y: 7))
                p.addLine(to: .init(x: 19, y: 9))
                p.addCurve(to: .init(x: 17, y: 3), control1: .init(x: 19, y: 7), control2: .init(x: 18.4, y: 5))
                p.closeSubpath()
                p.move(to: .init(x: 17, y: 9)); p.addLine(to: .init(x: 17, y: 21))
            }
        }
    }

    /// Head and shoulders, in the same line style: circle (12, 8) r 4 · M4 21c0-4 4-6 8-6s8 2 8 6
    struct Person: Shape {
        func path(in rect: CGRect) -> Path {
            TabGlyph.scaled(rect) { p in
                p.addEllipse(in: CGRect(x: 8, y: 4, width: 8, height: 8))
                p.move(to: .init(x: 4, y: 21))
                p.addCurve(to: .init(x: 12, y: 15), control1: .init(x: 4, y: 17), control2: .init(x: 8, y: 15))
                p.addCurve(to: .init(x: 20, y: 21), control1: .init(x: 16, y: 15), control2: .init(x: 20, y: 17))
            }
        }
    }

    /// M13 2 4 14h6l-1 8 9-12h-6l1-8z (filled).
    struct Bolt: Shape {
        func path(in rect: CGRect) -> Path {
            TabGlyph.scaled(rect) { p in
                p.addLines([.init(x: 13, y: 2), .init(x: 4, y: 14), .init(x: 10, y: 14), .init(x: 9, y: 22),
                            .init(x: 18, y: 10), .init(x: 12, y: 10), .init(x: 13, y: 2)])
                p.closeSubpath()
            }
        }
    }
}

#Preview {
    VStack { Spacer(); MockTabBar() }
        .environment(AppRouter())
        .background(Palette.page)
}
