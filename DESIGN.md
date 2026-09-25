# FlexFit design system

Source of truth: `docs/design/FlexFit-mock.html` (v9 "v3 on white"). Readable markup extracted from it: `docs/design/mock-template.html`.
Every value below lives in `FlexFit/Theme/DesignTokens.swift`. **Views never contain literal colours, font sizes, or corner radii** — `design-check.sh` enforces it.

The mock only draws light mode. The dark palette was derived (hue-preserving, WCAG-checked) and signed off on 2026-09-24.

## Colour

### Roles — flip with light/dark

| Token | Light | Dark | Use |
|---|---|---|---|
| `page` → `pageTint` | `#F2F7FC` → `#D6E4F3` | `#0A1322` (flat) | Page gradient (`.pageBackground()`) |
| `card` | `#FFFFFF` | `#14233F` | Cards, grouped lists, inputs |
| `ink` | `#14233F` | `#EEF3F9` | Primary text/icons |
| `inkMuted` | ink @ 65% | ink @ 55% | Secondary text (≥ 4.5:1 on card) |
| `hairline` | ink @ 7% | ink @ 10% | Row dividers — non-text only |
| `track` | ink @ 14% | ink @ 16% | Empty bars, inactive dots — non-text only |
| `inkFill` / `onInkFill` | navy / white | ice / navy | Selected option, primary button on the page. Always inverts against the page |
| `copperText` | `#9A5129` | `#E0A27C` | Links, "See all", kickers |
| `blueText` | `#2F5C9E` | `#86A8DA` | Blue glyphs and text |
| `copperTint`, `blueTint` | accent @ ~20% | accent @ ~18% | Icon tiles behind the matching `*Text` glyph |
| `panel` | `#14233F` | `#1C3057` | Navy hero cards. Lifts in dark so it doesn't vanish into the page |
| `panelRaised` | `#1C3057` | `#243B69` | Image area inside a panel |
| `panelEdge` | clear | white @ 8% | 1pt outline on panels in dark mode |

### Fixed — identical in both appearances, on purpose

| Token | Value | Why fixed |
|---|---|---|
| `navy`, `navyRaised` | `#14233F`, `#1C3057` | Label colour on ice/copper fills; ground of the intro and "building your plan" screens, which are always dark by design |
| `ice` | `#D6E4F3` | CTA fill on dark grounds, protein bar. Label: `navy` (12.1:1) |
| `copper` | `#E0A27C` | The ⚡ accent, calorie arc, "you are here" markers. Label: `navy` (7.2:1) |
| `sand` | `#EBC9B2` | Fat macro bar |
| `onPanel`, `onPanelMuted` (60%), `onPanelHairline`, `onPanelTrack`, `onPanelOutline` | white | Content on `panel`/`navy`. Panels are dark in both modes, so their content is fixed-light |

**Rule:** content on a fixed surface is fixed too. Never put `ink` text on `ice`/`copper`/`panel`; never put `onPanel` text on `card`/`page`.

### Deviations from the mock (accessibility)

- Muted text raised from 45–55% to 65% (mock value was 3.2:1 on white).
- Copper link text darkened `#B8643A` → `#9A5129` (was 4.3:1).
- Navy cards lift to `#1C3057` + hairline edge in dark mode.

## Type — Plus Jakarta Sans (OFL, bundled)

All styles scale with Dynamic Type relative to the listed system style. Use `.textStyle(.x)`.

| Style | Weight / size | Tracking | Use |
|---|---|---|---|
| `display` | 800 / 36 | −3.5% | Intro hero |
| `metric` | 800 / 34 | −3% | Calorie target, big numbers |
| `title1` | 800 / 28 | −3% | Screen titles |
| `title2` | 800 / 21 | −2% | Header name, session name, sheet title |
| `headline` | 800 / 17 | −1% | Section headers |
| `statValue` | 800 / 16 | | Macro grams, small stats |
| `button` | 800 / 15 | | CTA labels |
| `rowTitle` | 700 / 14.5 | | Row & option titles |
| `body` | 400 / 14 | | Paragraphs |
| `label` | 700 / 13 | | Question labels |
| `chip` | 600 / 13 | | Chips, secondary buttons |
| `caption` | 500 / 12 | | Row meta, hints |
| `micro` | 600 / 11 | | Labels under stats |
| `kicker` | 700 / 10.5, UPPERCASE | +12% | Pills, "YOUR PATH IS READY" |

## Shape, space, size

- Radius: `xs 8` icon tiles · `sm 10` inputs/day cells · `md 12` grouped lists · `lg 14` cards/panels · pills & circles use `Capsule()`/`Circle()`.
- Space: 4 · 8 · 12 · 16 · 20 · 24 · 32. Page gutter is `Space.lg` (20).
- Size: CTA 58 / 48, list row min 56, icon tile 38, avatar 42.
- Shadow: `.cardShadow()` — navy @ 5%, light mode only.

## Components & platform choices

- **Tab bar:** native `TabView` (Liquid Glass on iOS 26), not the mock's custom pill. ⚡ Adapt is a tab that opens the adapt sheet instead of navigating.
- Sheets: system presentation; don't force `presentationCornerRadius` on partial-height sheets.
- Images: the mock's image slots are placeholders. The mock's own drawn illustrations (hero, lift, walk) are in `Assets.xcassets/Illustrations` until real art exists.
- Shared controls live in `FlexFit/Components/Controls.swift`: `PrimaryButton` (inkFill), `IceButton` (on always-dark grounds), `DisabledCTA`, `KickerPill`, `CardList`, `ChoiceRow`, `Chip`, `FlowLayout`, `UnitField`, `InlineNote`.
- Layout helpers: `.readableColumn()` caps content at 560pt (iPad); `.bottomBarBackground()` behind any bar pinned over scrolling content; `.statusBarBackdrop()` on scrolling screens with no navigation bar.
- **Always-dark screens (deliberate):** Intro, "building your plan", the Paywall (fixed `navy` ground) and the Train tab (`.environment(\.colorScheme, .dark)`, because the mock draws Train on navy). No other screen forces a scheme.
- Charts (Eat, Path) use Swift Charts with token colours: trend `copperText`/`copper`, plan line `onPanelOutline` dashed, target rule `blueText`.
- Sheets that need the paywall close themselves first; the paywall is presented only from the root.
- Bottom CTAs over forms hide while a text field is focused — otherwise they ride up on the keyboard and cover the field.

## MVP scope vs the mock

The mock includes Phase 2/3 features (meal plans, grocery list, eating-out guide, food wizard steps). Per the PRD these are **out of v1**: the Eat tab shows adaptive calorie/protein targets and the daily protein check; the wizard drops the food/kitchen/shopping steps.

Onboarding (11 steps, 10 when maintaining) also drops the mock's questions the MVP never uses: dieting history, daily steps, training styles, sleep, reminder time and coaching tone. It adds a health-notice step (PRD safety). "Recomp" is dropped as a goal — the PRD's goals are lose / maintain / gain. "Skip to the app" is dropped: there's nothing to show without a profile.
