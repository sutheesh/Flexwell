import SwiftUI

// Pieces of the mock's chrome shared across screens: toasts, the bottom-sheet layout, the header cart button.

// MARK: - Toast

/// The mock's navy confirmation toast ("⚡ Cut to 20 minutes. Streak intact.").
struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: Space.sm - 2) {
            Image(systemName: "bolt.fill").foregroundStyle(Palette.ice)
            Text(message)
                .textStyle(.caption)
                .foregroundStyle(Palette.onPanel)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.md - 2)
        .background(Palette.navy, in: RoundedRectangle(cornerRadius: Radius.sm))
        .shadow(color: Palette.navy.opacity(0.25), radius: 10, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

extension View {
    /// Shows the router's toast above the tab bar for 2.6 s.
    func toastOverlay(_ router: AppRouter) -> some View {
        overlay(alignment: .bottom) {
            if let message = router.toastMessage {
                ToastView(message: message)
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, Size.tabBarClearance)
                    .readableColumn()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(message)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: router.toastMessage)
    }
}

// MARK: - Mock sheet

/// The mock's sheet: copper kicker, title, subtitle, ✕ close, content, optional footer line.
struct MockSheet<Content: View>: View {
    let kicker: String
    let title: String
    var subtitle: String?
    var footer: String?
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: Space.sm) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(kicker)
                        .textStyle(.kicker)
                        .foregroundStyle(Palette.copperText)
                    Text(title)
                        .textStyle(.title2)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.xs + 1)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .textStyle(.caption)
                            .foregroundStyle(Palette.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, Space.xs - 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(TextStyle.label.font)
                        .foregroundStyle(Palette.navy)
                        .frame(width: Size.control - 6, height: Size.control - 6)
                        .background(Palette.ice, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, Space.lg + 2)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.md - 2)
            .readableColumn()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    content
                    if let footer {
                        Text(footer)
                            .textStyle(.caption)
                            .foregroundStyle(Palette.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Space.lg + 2)
                .padding(.bottom, Space.xxl)
                .readableColumn()
            }
        }
        .background(Palette.page.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }
}

/// A lettered / glyph row in a mock sheet ("A  Push-Up, feet elevated · Zero equipment").
struct SheetRow: View {
    let badge: String
    let title: String
    var subtitle: String?
    var trailing: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm + 1) {
                Text(badge)
                    .textStyle(.label)
                    .foregroundStyle(Palette.onInkFill)
                    .frame(width: Size.iconTile, height: Size.iconTile)
                    .background(Palette.inkFill, in: RoundedRectangle(cornerRadius: Radius.xs))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(title)
                        .textStyle(.rowTitle)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle)
                            .textStyle(.caption)
                            .foregroundStyle(Palette.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let trailing {
                    Text(trailing).textStyle(.label).foregroundStyle(Palette.copperText)
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm + 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Header cart

/// The square cart button on the right of every tab header (opens Groceries).
struct CartButton: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button { router.isGroceryPresented = true } label: {
            Image(systemName: "cart")
                .font(TextStyle.rowTitle.font)
                .foregroundStyle(Palette.ink)
                .frame(width: Size.avatar, height: Size.avatar)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.sm))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Grocery list")
    }
}

/// Toggle drawn like the mock's pill switch (navy when on).
struct MockSwitch: View {
    let isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? Palette.inkFill : Palette.track)
            .frame(width: Size.switchSize.width, height: Size.switchSize.height)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle().fill(isOn ? Palette.onInkFill : Palette.card)
                    .padding(Space.xxs)
            }
            .animation(.easeOut(duration: 0.15), value: isOn)
            .accessibilityHidden(true)
    }
}
