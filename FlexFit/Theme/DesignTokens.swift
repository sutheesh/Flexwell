import SwiftUI
import UIKit

// The only place in the app where colour values, type sizes, radii and
// spacing are written down. Views name a token; they never spell a value.
// See DESIGN.md for what each token is for and why it flips (or doesn't).

// MARK: - Colour

enum Palette {

    // MARK: Roles — these flip with light/dark.

    /// Page background (top of the page gradient).
    static let page = Color(light: 0xF2F7FC, dark: 0x0A1322)
    /// Bottom of the page gradient. In dark mode the page is flat.
    static let pageTint = Color(light: 0xD6E4F3, dark: 0x0A1322)
    /// Cards, list groups, input fields on the page.
    static let card = Color(light: 0xFFFFFF, dark: 0x14233F)
    /// Primary text and icons on page and card.
    static let ink = Color(light: 0x14233F, dark: 0xEEF3F9)
    /// Secondary text. 65% / 55% keeps it ≥ 4.5:1 on card in both modes.
    static let inkMuted = Color(light: 0x14233F, lightOpacity: 0.65, dark: 0xEEF3F9, darkOpacity: 0.55)
    /// Dividers between rows. Non-text only.
    static let hairline = Color(light: 0x14233F, lightOpacity: 0.07, dark: 0xEEF3F9, darkOpacity: 0.10)
    /// Empty track of progress bars, inactive step dots, disabled fills. Non-text only.
    static let track = Color(light: 0x14233F, lightOpacity: 0.14, dark: 0xEEF3F9, darkOpacity: 0.16)
    /// Selected/filled control on the page (chosen option, active step dot, primary button fill).
    /// Inverts against the page in both modes; its label is `onInkFill`.
    static let inkFill = Color(light: 0x14233F, dark: 0xD6E4F3)
    static let onInkFill = Color(light: 0xFFFFFF, dark: 0x14233F)
    /// Copper used as *text* (links, "See all", kickers). Darkened in light mode for AA.
    static let copperText = Color(light: 0x9A5129, dark: 0xE0A27C)
    /// Blue used as *text or icon* on page/card.
    static let blueText = Color(light: 0x2F5C9E, dark: 0x86A8DA)
    /// Tinted icon tiles behind copperText / blueText glyphs.
    static let copperTint = Color(light: 0xE0A27C, lightOpacity: 0.20, dark: 0xE0A27C, darkOpacity: 0.18)
    static let blueTint = Color(light: 0x2F5C9E, lightOpacity: 0.16, dark: 0x86A8DA, darkOpacity: 0.18)

    // MARK: Hero panel — the navy cards.
    // The panel lifts slightly in dark mode so it doesn't vanish into a navy page,
    // but it is dark in BOTH appearances, so everything drawn on it is fixed-light.

    static let panel = Color(light: 0x14233F, dark: 0x1C3057)
    /// Image area / inset inside a panel.
    static let panelRaised = Color(light: 0x1C3057, dark: 0x243B69)
    /// Outline that separates the panel from a dark page. Invisible in light mode.
    static let panelEdge = Color(light: 0xFFFFFF, lightOpacity: 0, dark: 0xFFFFFF, darkOpacity: 0.08)

    // MARK: Fixed — deliberately identical in both appearances.

    /// Brand navy. Used as the label colour on ice and copper fills, and as the
    /// always-dark ground of the intro and plan-building screens.
    static let navy = Color(hex: 0x14233F)
    static let navyRaised = Color(hex: 0x1C3057)
    /// Ice: primary CTA fill on dark grounds, protein bar, active items on panels. Label = navy (12.1:1).
    static let ice = Color(hex: 0xD6E4F3)
    /// Copper: the ⚡ accent, calorie arc, "current" markers. Label = navy (7.2:1).
    static let copper = Color(hex: 0xE0A27C)
    /// Fat macro bar; warm end of the meal "petals".
    static let sand = Color(hex: 0xEBC9B2)
    /// Cool end of the meal petals and ingredient tiles.
    static let iceLight = Color(hex: 0xE6EEF8)
    /// "Picked for you" card: a fixed peach surface with fixed dark content.
    static let peach = Color(hex: 0xF4E3D6)
    static let peachDeep = Color(hex: 0xEFD2BF)
    /// Dark copper for text on peach (6.1:1).
    static let copperInk = Color(hex: 0x8F4A26)
    static let white = Color(hex: 0xFFFFFF)

    // Content on panel / navy grounds. Fixed because those grounds are always dark.
    static let onPanel = Color(hex: 0xFFFFFF)
    static let onPanelMuted = Color(hex: 0xFFFFFF, opacity: 0.60)   // ≥ 5.7:1 on both panel shades
    static let onPanelHairline = Color(hex: 0xFFFFFF, opacity: 0.10)
    static let onPanelTrack = Color(hex: 0xFFFFFF, opacity: 0.12)
    static let onPanelOutline = Color(hex: 0xFFFFFF, opacity: 0.16)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: opacity))
    }

    init(light: UInt32, lightOpacity: Double = 1, dark: UInt32, darkOpacity: Double = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkOpacity)
                : UIColor(hex: light, alpha: lightOpacity)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: Double) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - Page background

extension View {
    /// The page gradient from the mock (ice-white → ice). Flat navy in dark mode.
    func pageBackground() -> some View {
        background(
            LinearGradient(colors: [Palette.page, Palette.pageTint], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

extension View {
    /// Behind a bottom bar pinned over scrolling content: fades the page in so rows
    /// don't show through the button.
    func bottomBarBackground() -> some View {
        background(alignment: .top) {
            LinearGradient(colors: [Palette.pageTint.opacity(0), Palette.pageTint], startPoint: .top, endPoint: .init(x: 0.5, y: 0.35))
                .ignoresSafeArea(edges: .bottom)
        }
    }

    /// Covers the status-bar area with the page colour on screens without a navigation
    /// bar, so content scrolling under it doesn't collide with the clock.
    func statusBarBackdrop() -> some View {
        overlay(alignment: .top) {
            Color.clear
                .frame(height: 0)
                .background(Palette.page.ignoresSafeArea(edges: .top))
        }
    }
}

// MARK: - Type

/// Plus Jakarta Sans at the mock's sizes, scaled with Dynamic Type relative to a system style.
struct TextStyle {
    let weight: FontWeight
    let size: CGFloat
    let relativeTo: Font.TextStyle
    /// Letter spacing as a fraction of the size (the mock's `em` values).
    let trackingEm: CGFloat
    let uppercase: Bool

    enum FontWeight: String {
        case regular = "PlusJakartaSans-Regular"
        case medium = "PlusJakartaSans-Medium"
        case semibold = "PlusJakartaSans-SemiBold"
        case bold = "PlusJakartaSans-Bold"
        case extraBold = "PlusJakartaSans-ExtraBold"
    }

    var font: Font { .custom(weight.rawValue, size: size, relativeTo: relativeTo) }
    var tracking: CGFloat { size * trackingEm }

    private init(_ weight: FontWeight, _ size: CGFloat, _ relativeTo: Font.TextStyle,
                 tracking: CGFloat = 0, uppercase: Bool = false) {
        self.weight = weight
        self.size = size
        self.relativeTo = relativeTo
        self.trackingEm = tracking
        self.uppercase = uppercase
    }

    /// Intro hero line.
    static let display = TextStyle(.extraBold, 36, .largeTitle, tracking: -0.035)
    /// Big numbers: calorie target, today's intake.
    static let metric = TextStyle(.extraBold, 34, .largeTitle, tracking: -0.03)
    /// Screen titles: wizard step, path header.
    static let title1 = TextStyle(.extraBold, 28, .title, tracking: -0.03)
    /// Header name, session name, sheet title.
    static let title2 = TextStyle(.extraBold, 21, .title2, tracking: -0.02)
    /// Section headers ("The road", "Session plan").
    static let headline = TextStyle(.extraBold, 17, .headline, tracking: -0.01)
    /// Small stat values (macro grams, row numbers).
    static let statValue = TextStyle(.extraBold, 16, .callout)
    /// Primary button labels.
    static let button = TextStyle(.extraBold, 15, .body)
    /// Typed values in number/text fields.
    static let input = TextStyle(.bold, 18, .body)
    /// Row titles, option labels.
    static let rowTitle = TextStyle(.bold, 14.5, .subheadline)
    /// Paragraph copy.
    static let body = TextStyle(.regular, 14, .subheadline)
    /// Question labels, secondary emphasis.
    static let label = TextStyle(.bold, 13, .footnote)
    /// Secondary button / chip labels.
    static let chip = TextStyle(.semibold, 13, .footnote)
    /// Row meta, hints, footnotes.
    static let caption = TextStyle(.medium, 12, .caption)
    /// Tiny labels under stats.
    static let micro = TextStyle(.semibold, 11, .caption2)
    /// Uppercase pills and kickers ("YOUR PATH IS READY").
    static let kicker = TextStyle(.bold, 10.5, .caption2, tracking: 0.12, uppercase: true)
}

extension View {
    func textStyle(_ style: TextStyle) -> some View {
        modifier(TextStyleModifier(style: style))
    }
}

private struct TextStyleModifier: ViewModifier {
    let style: TextStyle
    func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.tracking)
            .textCase(style.uppercase ? .uppercase : nil)
    }
}

// MARK: - Shape & space

enum Radius {
    /// Icon tiles, small swatches.
    static let xs: CGFloat = 8
    /// Inputs, day cells, back button.
    static let sm: CGFloat = 10
    /// Grouped lists.
    static let md: CGFloat = 12
    /// Cards and hero panels.
    static let lg: CGFloat = 14
    // Pills and circles use `Capsule()` / `Circle()`.
}

enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Size {
    /// Space the toast keeps above the tab bar.
    static let tabBarClearance: CGFloat = 96
    /// The mock's pill switch.
    static let switchSize = CGSize(width: 46, height: 28)
    /// Calorie arc on Today (mock: 18×34 segments at radius 108).
    static let arcRadius: CGFloat = 92
    static let segment = CGSize(width: 16, height: 30)
    /// Meal photo in a meal card.
    static let mealThumb = CGSize(width: 88, height: 96)
    /// Round meal image on "Picked for you" and the detail flower.
    static let mealHero: CGFloat = 100
    /// Primary CTA height.
    static let buttonTall: CGFloat = 58
    /// Secondary CTA height.
    static let button: CGFloat = 48
    /// Minimum list-row height.
    static let row: CGFloat = 56
    /// Icon tiles in rows.
    static let iconTile: CGFloat = 38
    /// Avatar and square header buttons.
    static let avatar: CGFloat = 42
    /// Back button and other small square controls.
    static let control: CGFloat = 40
    /// Selection ring in choice rows.
    static let checkRing: CGFloat = 22
    /// Step-progress bars and thin progress tracks.
    static let progressBar: CGFloat = 4
    /// Widest a single column of reading content gets (iPad).
    static let readableWidth: CGFloat = 560
    /// The logo tile on the intro screen.
    static let logoTile: CGFloat = 26
    /// Plan-building spinner.
    static let spinner: CGFloat = 120
    /// Status dots in badges.
    static let dot: CGFloat = 6
    /// Max width of text laid over a panel illustration.
    static let panelTextWidth: CGFloat = 260
    /// Width of the plan-building progress track.
    static let progressTrack: CGFloat = 210
}

// MARK: - Elevation

extension View {
    /// The mock's soft card shadow. Dropped in dark mode, where shadows on navy read as dirt.
    func cardShadow() -> some View {
        modifier(CardShadow())
    }
}

private struct CardShadow: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.shadow(color: scheme == .dark ? .clear : Palette.navy.opacity(0.05), radius: 7, y: 2)
    }
}
