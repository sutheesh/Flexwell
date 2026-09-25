# Design system

Turning a design into something that can't be drifted from.

## Why tokens, specifically

A design mock is a picture. Code is a thousand small decisions, each of which can be a little bit wrong. The gap between them opens one screen at a time, and nobody notices until someone scrolls through the app in dark mode and finds four different greys.

Tokens close the gap by removing the opportunity. If a view *cannot* express a colour except by naming one from the system, it cannot drift.

## Extracting from what you're given

**HTML/CSS mock.** The highest-fidelity input — read values directly:

```bash
grep -oE '#[0-9A-Fa-f]{3,8}' mock.html | sort | uniq -c | sort -rn   # palette by frequency
grep -oE 'border-radius:[^;]+' mock.html | sort -u                    # radii
grep -oE 'font-size:[^;]+' mock.html | sort -u                        # type scale
```
Frequency ordering is informative: the most-used colours are the role colours (background, surface, text), the rare ones are accents.

**Screenshots.** Sample the colours, then ask about what the image can't show — dark mode, empty states, error states, disabled states. Guessing these is how a design system acquires colours nobody chose.

**A written direction.** Propose a concrete palette and type scale, show it, get agreement. Don't build three screens on an unconfirmed interpretation.

## The structure

Two categories, and keeping them straight prevents most dark-mode bugs:

```swift
enum Ink {  // or whatever the app is called

    // MARK: Roles — these flip with the theme.
    // Each is defined for both appearances because the *role* is constant
    // ("the page background") while the value depends on the appearance.
    static let paper   = Color(light: "#F4F1EA", dark: "#121214")  // page background
    static let surface = Color(light: "#FFFFFF", dark: "#1C1C20")  // cards on the page
    static let text    = Color(light: "#0E0E10", dark: "#F2EFE7")  // primary text
    static let mu      = Color(light: "#0E0E10", lightOpacity: 0.52,
                               dark: "#F2EFE7", darkOpacity: 0.58) // secondary text
    static let hairline = Color(light: "#0E0E10", lightOpacity: 0.10,
                                dark: "#F2EFE7", darkOpacity: 0.13)

    // MARK: Fixed — deliberately the same in both appearances.
    // Brand accents, and surfaces that are meant to read as "always dark"
    // regardless of theme (hero panels, badges, feature tiles).
    static let gold = Color(hex: "#E4A93C")
    static let lime = Color(hex: "#D6FB4E")
    static let bg   = Color(hex: "#0E0E10")   // the always-dark panel colour
}
```

`Color(light:dark:)` isn't built in — implement it once with `UIColor { traits in ... }`, or define the colours in the asset catalog with appearance variants. Either works; the asset-catalog route also makes them available to storyboards, which matters for a launch screen.

## The trap that produces the most bugs

A fixed colour used where a flipping one is needed. The two look identical in light mode, which is where most development happens.

**The concrete failure:** a primary button filled with the always-dark panel colour. In light mode it's near-black on cream — a strong CTA. In dark mode the page background is *also* near-black, and the button vanishes into it. Same code, same token, correct in one appearance and invisible in the other.

**The test**, worth applying to every fixed colour:

> Does this sit on a surface that changes with the theme, while this value does not?

If yes, it breaks in one appearance. If the surface is *also* fixed — a permanently dark hero card, text inside a branded tile — the literal is right, and deserves a one-line comment saying so, because otherwise a future reader "fixes" it into a real bug.

**For a primary button on a themed page**, two options that both survive:
- A fixed accent (`gold`, `lime`) with a role-token label — contrast comes from hue, so it holds in both appearances
- `text` as the fill and `paper` as the label — they're exact opposites in both appearances, so the button always inverts against the page

## Beyond colour

The same discipline applies to everything else that varies:

- **Type scale** — a fixed set of sizes and weights, named by role (`display`, `title`, `body`, `caption`). Custom fonts get registered once; for a launch screen they have to be in `UIAppFonts` or converted to outlines, because a storyboard loads before any app code runs
- **Spacing and radii** — a small scale (4/8/12/16/20/24) rather than arbitrary numbers

## When the design only has light mode

This is the normal case — mocks and Figma files usually ship one appearance. Don't invent the dark palette silently as you go, and don't skip it either: colours chosen screen by screen is precisely how an app ends up with four different greys.

Derive a proposal, check it, then get it signed off:

```bash
python3 "$SKILL_DIR/scripts/derive-dark-palette.py" \
    --bg '#F4F1EA' --surface '#FFFFFF' --text '#0E0E10' \
    --accent gold=#E4A93C --accent lime=#D6FB4E
```

It preserves hue (a warm cream and a warm near-black read as the same product), avoids the two classic failures — pure-black grounds that smear on OLED, pure-white text that halates — lightens accents that would go muddy, and then **measures every pairing against WCAG** so what you propose is checked rather than eyeballed.

Two things the output is for:

**Sign-off.** It's a defensible starting point, not a designed palette. Show it before building on it.

**Choosing label colours for accent fills.** The report tells you which label passes on each accent, and — in its last box — whether the fill can simply stay fixed with its light-mode label. When it can, that's usually the better choice: the button looks the same in both modes, and only accent-coloured *text* uses the lightened value. Take what the report says passes — this is not a guess, and getting it wrong is the failure below.

## The accent-fill trap

An accent used as a button fill deserves its own attention, because it produces a bug that survives review by looking fine in light mode.

A fixed accent doesn't flip. If its **label** uses a role token, the label flips underneath it:

| | fill | label | contrast |
|---|---|---|---|
| Light | gold `#E4A93C` | ink `#0E0E10` | 8.9:1 ✅ |
| Dark | gold `#E4A93C` | cream `#F2EFE7` | **1.8:1 ❌** |

Same line of code. Perfect in one appearance, unreadable in the other — and the developer building in light mode has no reason to look.

**The rule that falls out of it:** content on a fixed surface must also be fixed. If the fill doesn't respond to the theme, neither can the text on it. Pair a fixed accent with a fixed label colour chosen from the contrast report, not with `text`.

This is the same principle as the trap above, one level in: *don't mix things that flip with things that don't.*

## Forcing colorScheme on a whole screen

`.environment(\.colorScheme, .dark)` is a bigger move than a fixed token on one element — it overrides every descendant, including system controls, and overrides the user's actual appearance setting for that whole screen. It's a legitimate choice for a screen that's genuinely always-dark by design (a paywall drawn like a hero card, say), but it's also exactly the kind of thing that gets copied: one screen does it on purpose, the next screen reuses the pattern because it was already there, and now a screen that was never meant to be fixed has no light mode and nobody decided that.

Before reaching for it, check the mock — is *this specific screen* always-dark, or did the pattern just travel? If it's genuinely fixed, it still wants the same one-line comment the trap above asks for. If not, build it from role tokens like everything else and let it flip.

## Layout bugs that look like design bugs

Four SwiftUI-specific ones that read as "the design is broken" when the design is fine:

**Horizontal drift.** A row that doesn't pin its width sizes to its *ideal* width — for a `Text`, that's the full unwrapped single line. One long string and the whole page scrolls sideways. Pin rows with `.frame(maxWidth: .infinity, alignment: .leading)` and give wrapping text `.fixedSize(horizontal: false, vertical: true)`. When several rows share a container, they must all do this — the one that doesn't sets the container's width for everyone.

**Stale container width.** `containerRelativeFrame` caches its container's width and doesn't re-measure on rotation, leaving a page stuck at landscape width after rotating back. Measure with `onGeometryChange` instead when the value must survive a rotation.

**The self-sizing-sheet trap.** A sheet built to fit short content — a toggle, a couple of rows — instead of sitting in a fixed `.medium` detent with blank space underneath it is worth building correctly, because the naive version fails in a way that's easy to misdiagnose as "the sheet just doesn't open": a `PreferenceKey` with a non-`nil` `defaultValue` (commonly `0`) defeats an `Optional`-based fallback silently — `Optional(0.0) ?? .medium` never trips, because `Optional(0.0)` isn't `nil` — and `.presentationDetents([.height(0)])` collapses the sheet invisibly mid-transition. No error, no crash, just nothing on screen.

The fix: skip `Optional` entirely. Plain non-optional `@State` height(s), measured with `.onGeometryChange(for:of:action:)` (not `GeometryReader` + `PreferenceKey`), floored with `max(measured, minHeight)` so the very first frame already has a safe non-zero value to present:

```swift
@State private var headerHeight: CGFloat = 0
@State private var contentHeight: CGFloat = 0     // measure header and content
                                                    // separately — a title
                                                    // pinned outside the
                                                    // ScrollView shouldn't
                                                    // scroll away if the body
                                                    // ever needs to
private var detentHeight: CGFloat {
    min(max(contentHeight + headerHeight, 220), screenHeight * 0.85)
}
// .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
// .presentationDetents([.height(detentHeight)])
// .animation(.spring(response: 0.34, dampingFraction: 0.86), value: detentHeight)
```

**Forcing `.presentationCornerRadius` on a partial-height sheet.** On iOS 26 the system picks a corner radius concentric with the display's own corners for a sheet that floats inset from the edges. A fixed radius set here makes the sheet's bottom corners cut across the screen's corner instead of nesting into it — looks fine on a full-height sheet (where the bottom corners are off-screen anyway), breaks the moment the same modifier is reused on a `.height(_:)` or `.medium` sheet. Leave it to the system unless the sheet is always full-height.
