# StoreKit, paywall, and free-tier gating

Building and testing purchases before any product exists in App Store Connect.

## Two services, not one

Keep "what the store says" separate from "what the user is allowed to do":

- **`StoreKitService`** — loads products, runs purchases, restores, watches `Transaction.updates`. Knows about StoreKit and nothing else
- **`EntitlementService`** — the single place every limit is decided. Knows nothing about StoreKit

The split matters because gating logic gets consulted from everywhere, and `if store.purchasedPremium` scattered across thirty views produces an inconsistent paywall — a feature blocked on one screen and open on another. That's both a lost sale and a confusing app. One service answering `canUseX` keeps it coherent.

```swift
@Observable final class EntitlementService {
    static let shared = EntitlementService()

    enum Limit {
        static let aiCredits = 3      // one shared pool reads better than
        static let savedItems = 1     // per-feature allowances nobody tracks
    }

    /// Mirrored rather than read through to the store. Views observe *this*
    /// object; if `isPremium` reaches through to another object's property,
    /// nothing here changes when a purchase lands and no view redraws.
    private(set) var isPurchased = false
    var isPremium: Bool { isPurchased }

    func premiumStatusChanged(to purchased: Bool) { isPurchased = purchased }
}
```

That mirrored property is not redundancy — reading through to another object's state means observation never fires, and the symptom is a successful purchase that unlocks nothing until the app relaunches.

## Local testing without App Store Connect

A `.storekit` configuration file defines products locally. Create it, add it to the scheme (Run → Options → StoreKit Configuration), and purchases work entirely offline.

**The constraint that wastes the most time: the configuration only applies when Xcode launches the app.** An app installed with `xcrun devicectl device install` ignores it completely — no products load, the paywall shows an empty state, and nothing about the code is wrong. If prices are missing, check how the app was launched before debugging anything else.

Keep the `.storekit` file out of the shipped bundle — if it lives in a file-system-synchronized folder it will be copied as a resource unless excluded (see `project-scaffold.md`).

## Purchase flow

```swift
@discardableResult
func purchase(_ product: Product) async -> Bool {
    do {
        switch try await product.purchase() {
        case .success(let verification):
            let tx = try checkVerified(verification)
            await tx.finish()
            await refreshPurchaseStatus()
            return purchasedPremium
        case .pending:
            // Ask-to-Buy. Real, but not complete — saying nothing reads as failure.
            lastError = "Waiting for approval. You'll get access once it's confirmed."
            return false
        case .userCancelled: return false
        @unknown default:    return false
        }
    } catch {
        lastError = "That didn't go through. Nothing has been charged."
        return false
    }
}
```

Two things worth getting right because both produce "the purchase worked but nothing happened":

**Act on the return value.** Relying only on `.onChange(of: store.purchasedPremium)` to dismiss the paywall fails if the flip doesn't propagate, or already happened. Use the result directly *and* keep the observer.

**Own the store instance deliberately.** `@State private var store = StoreKitService()` in an `App` can have its initialiser evaluated more than once, and if a discarded instance is the one wired into your entitlement service, it reports `false` forever. Attach from the instance the app actually keeps, in `App.init()`.

## Verification in the test environment

StoreKit Testing signs transactions with a local certificate. On a device that hasn't accepted it, every purchase returns `.unverified`, and a strict `checkVerified` rejects a purchase that genuinely succeeded.

Honour it in DEBUG, refuse it in Release — the verification check is the entire point in production:

```swift
case .unverified(let value, let error):
    #if DEBUG
    print("⚠️ unverified — honouring in DEBUG:", error)
    tx = value
    #else
    throw error
    #endif
```

## Products in App Store Connect

| Type | For | Notes |
|---|---|---|
| Auto-renewable subscription | Monthly, yearly | Must share one subscription group |
| Non-consumable | Lifetime | Created separately, not in the group |

- **Subscription levels matter.** Yearly must rank above monthly, or switching between them behaves as a downgrade and defers to the end of the period
- **Product IDs are permanent.** They ship inside the app; changing one breaks every existing purchase
- **Display names are user-visible** in the purchase sheet — if the app gets renamed, rename these too, or buyers see a different brand at the moment of payment
- Every product needs a localised name, description and review screenshot before it leaves "Missing Metadata", and all must be attached to the version being submitted. Otherwise the production paywall shows the same empty state as an unconfigured local build
- A lifetime tier priced well above the subscription will trigger an automated price-confirmation hold. Not a rejection — reply confirming the price is intentional

### Filling in the Create Subscription form

Three fields, and what actually goes in each:

- **Reference Name** — internal only, never shown to a user, editable later. Anything that identifies the plan to you (`"Pro Yearly"`) is fine
- **Product ID** — must exactly match the string the code passes to `Product.products(for:)`, and is permanent the moment the product is created. Get this from the app's own product-ID constants, not from memory
- **Subscription Duration** — must match what the local `.storekit` testing file declares for the same plan. A mismatch here means local testing and the live App Store checkout charge on different schedules, and nobody notices until a support email arrives

## Terms & Privacy on the paywall

Guideline 3.1.2 requires a subscription screen to link both the Privacy Policy and the Terms of Use (EULA) — reachable from the purchase screen itself, not buried in Settings only.

**Don't `openURL` out to Safari to show them.** That hands the person off mid-purchase-flow, which is the worst moment to lose them — they were one tap from paying. Show the page in-app instead: a bare, chrome-less `WKWebView` in a sheet with nothing but a title and a close button.

```swift
private struct WebContent: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false                 // let the page's own dark-mode CSS show through
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil { webView.load(URLRequest(url: url)) }   // don't reload on every state change
    }
}

enum LegalPage: String, Identifiable {
    case privacy, terms, subscription
    var id: String { rawValue }
    var title: String { /* "Privacy Policy" etc. */ }
    var url: URL { /* base host + this case's filename */ }
}

extension View {
    func legalPage(_ page: Binding<LegalPage?>) -> some View {
        background { Color.clear.sheet(item: page) { LegalWebView(title: $0.title, url: $0.url) } }
    }
}
```

**The sheet-inside-a-sheet trap:** the paywall is usually itself presented as a `.sheet`. Adding a second `.sheet(item:)` directly on that same paywall view for the legal page is unreliable — two `.sheet` modifiers stacked on one view don't both reliably present. Presenting the legal page from a `.background { Color.clear.sheet(...) }` puts it on a separate view identity, so it composes safely regardless of what's presenting the paywall itself.

### The HTML pages themselves

The three documents (Privacy Policy, Terms of Use, Subscription Terms) are static HTML, hosted wherever the app's other web assets live — they don't need a backend. A pattern that holds up across apps:

- **One self-contained file per document**, CSS inlined rather than linked to a shared stylesheet — so any single page can be uploaded or re-hosted on its own without a second request pulling in the rest
- **Light/dark via CSS custom properties**, overridden under `@media (prefers-color-scheme: dark)` — the same role-token idea as the app's own design tokens, just in CSS. Without it the page reads as a jarring white flash inside an otherwise dark-mode-aware `WKWebView`
- **Serif headings** (`Georgia, "Times New Roman", serif` — no font file to ship) read as a document rather than as more app UI, which is the right signal for something with legal weight
- **A `.card` component** for the one paragraph someone will actually read — a plain-language summary at the top of the privacy policy, a safety disclaimer in the terms, a refund note in the subscription terms. Rendered with its own background and border so it doesn't blend into the surrounding prose
- **A shared footer** on all three pages, cross-linking to the other two, so a visitor who lands on any one of them (from the App Store listing, from a search result) can reach the rest
- **Content is app-specific, not copy-pasted.** Two apps with different data practices (one with ads and tracking, one without) need different policies even if they share a publisher and a CSS template — see `app-review.md` for why a mismatched policy is a rejection risk, not just an accuracy nicety

## Designing the wall

What consistently works better than blocking:

- **Leave the flow open.** Let people pick the photo, fill the form, choose the options. Put the limit on the *action*, marked with a badge before the tap, so nothing is computed and then withheld
- **Charge on a result, never on a tap that failed.** An error that costs a credit is the fastest way to make a free tier feel like a con
- **Show the remaining count** next to the feature. A counter that ticks down while the feature is working teaches the value and the limit in the same moment — it sells better than the paywall does
- **Never take away what someone already entered.** Limit creation and derived analysis; leave existing records readable and exportable forever. Apple rejects apps that hold user data hostage, and it earns the reviews it deserves
- **Restore purchases must be reachable** — the paywall is the conventional place. If it's the only place, don't remove it

## A debug override, and its expiry date

While building, a DEBUG-only switch that grants premium without the store is the only practical way to exercise every gate:

```swift
var isPremium: Bool {
    #if DEBUG
    if debugPremiumOverride { return true }
    #endif
    return isPurchased
}
```

Strip it before shipping — along with any on-screen debug rows that drive it. It's genuinely useful right up until it's an embarrassment in a release build.
