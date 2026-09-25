import SwiftUI
import StoreKit

/// FlexFit Pro. Always dark by design (same navy ground as the intro), so fixed tokens throughout.
struct PaywallView: View {
    let reason: AppRouter.PaywallReason

    @Environment(\.dismiss) private var dismiss
    @Environment(StoreService.self) private var store
    @Environment(EntitlementService.self) private var entitlements
    @State private var selectedID = StoreService.ProductID.yearly
    @State private var purchasing = false
    @State private var legal: LegalPage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(TextStyle.label.font)
                            .foregroundStyle(Palette.onPanel)
                            .frame(width: Size.control, height: Size.control)
                            .background(Palette.onPanelHairline, in: Circle())
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("paywall.close")
                }

                Text("FlexFit Pro")
                    .textStyle(.kicker)
                    .foregroundStyle(Palette.copper)
                Text(headline)
                    .textStyle(.title1)
                    .foregroundStyle(Palette.onPanel)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.sm - 2)
                    .accessibilityAddTraits(.isHeader)
                Text("The swap habit stays free. Pro is the layer that keeps adapting.")
                    .textStyle(.body)
                    .foregroundStyle(Palette.onPanelMuted)
                    .padding(.top, Space.xs)

                VStack(spacing: 0) {
                    featureRow("Energy check-in pivots", free: "3 a month", pro: "Unlimited")
                    featureRow("Travel Mode", free: "—", pro: "Yes")
                    featureRow("Calorie & protein targets", free: "Static", pro: "Weekly adaptive")
                    featureRow("Progress history", free: "30 days", pro: "Everything")
                    featureRow("Swaps, logging, Health", free: "Yes", pro: "Yes", last: true)
                }
                .background(Palette.onPanelHairline, in: RoundedRectangle(cornerRadius: Radius.md))
                .padding(.top, Space.xl)

                plans
                    .padding(.top, Space.xl)

                if let error = store.lastError {
                    Text(error)
                        .textStyle(.caption)
                        .foregroundStyle(Palette.copper)
                        .padding(.top, Space.sm)
                }

                IceButton(title: ctaTitle) { Task { await buy() } }
                    .disabled(product == nil || purchasing)
                    .opacity(product == nil ? 0.5 : 1)
                    .padding(.top, Space.lg)

                HStack(spacing: Space.md) {
                    Button("Restore") { Task { await store.restore(); if entitlements.isPro { dismiss() } } }
                    Button("Terms") { legal = .terms }
                    Button("Privacy") { legal = .privacy }
                }
                .textStyle(.chip)
                .foregroundStyle(Palette.onPanelMuted)
                .frame(maxWidth: .infinity)
                .padding(.top, Space.md)

                Text("Subscriptions renew automatically until cancelled in Settings › Apple ID at least 24 hours before the period ends.")
                    .textStyle(.micro)
                    .foregroundStyle(Palette.onPanelMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Space.sm)
            }
            .padding(Space.lg)
            .readableColumn()
        }
        .background(Palette.navy.ignoresSafeArea())
        .task { await store.loadProducts() }
        .legalPage($legal)
    }

    private var product: Product? { store.products.first { $0.id == selectedID } }

    private var headline: String {
        switch reason {
        case .pivots: "You've used this month's 3 low-energy pivots."
        case .travel: "Travel Mode keeps you training on the road."
        case .adaptiveTargets: "Targets that follow your real weight trend."
        case .history: "See your whole path, not just 30 days."
        case .firstSession: "First session done. Keep the plan bending with you."
        case .settings: "Everything that adapts, unlocked."
        }
    }

    private var ctaTitle: String {
        guard let product else { return store.isLoading ? "Loading…" : "Unavailable" }
        if product.subscription?.introductoryOffer != nil { return "Start 7-day free trial" }
        return "Continue with \(product.displayPrice)"
    }

    @ViewBuilder
    private var plans: some View {
        if store.products.isEmpty {
            Text(store.isLoading ? "Loading plans…" : "Plans couldn't load. Check your connection and try again.")
                .textStyle(.caption)
                .foregroundStyle(Palette.onPanelMuted)
        } else {
            VStack(spacing: Space.sm) {
                ForEach(store.products, id: \.id) { p in
                    let selected = p.id == selectedID
                    Button { selectedID = p.id } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: Space.xxs) {
                                Text(p.id == StoreService.ProductID.yearly ? "Yearly" : "Monthly")
                                    .textStyle(.rowTitle)
                                Text(planDetail(p))
                                    .textStyle(.caption)
                                    .opacity(0.75)
                            }
                            Spacer()
                            Text(p.displayPrice)
                                .textStyle(.statValue)
                        }
                        .foregroundStyle(selected ? Palette.navy : Palette.onPanel)
                        .padding(Space.md)
                        .background(selected ? Palette.ice : Color.clear, in: RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(selected ? Color.clear : Palette.onPanelOutline))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private func planDetail(_ p: Product) -> String {
        if p.id == StoreService.ProductID.yearly {
            return p.subscription?.introductoryOffer != nil ? "7 days free, then \(p.displayPrice) a year" : "\(p.displayPrice) a year"
        }
        return "\(p.displayPrice) a month"
    }

    private func featureRow(_ title: String, free: String, pro: String, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).textStyle(.caption).foregroundStyle(Palette.onPanel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(free).textStyle(.micro).foregroundStyle(Palette.onPanelMuted)
                    .frame(width: Size.avatar * 1.6, alignment: .trailing)
                Text(pro).textStyle(.micro).foregroundStyle(Palette.ice)
                    .frame(width: Size.avatar * 2.2, alignment: .trailing)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            if !last { Rectangle().fill(Palette.onPanelHairline).frame(height: 1) }
        }
        .accessibilityElement(children: .combine)
    }

    private func buy() async {
        guard let product else { return }
        purchasing = true
        defer { purchasing = false }
        if await store.purchase(product) { dismiss() }
    }
}
