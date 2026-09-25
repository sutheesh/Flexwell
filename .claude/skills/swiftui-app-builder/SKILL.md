---
name: swiftui-app-builder
description: Build production-ready SwiftUI iOS apps from a design mock and optional PRD, with the App Store submission traps already solved. Use this whenever the user wants to build, rebuild, scaffold, or redesign an iOS/SwiftUI app — including "build me an app that does X", "rebuild this app from this design", "start a new iOS project", "rewrite the UI to match this mock", or "make this app App Store ready". Also use when adding Firebase, AdMob, StoreKit paywalls, App Tracking Transparency, or a privacy manifest to a SwiftUI app, and when a dark-mode colour bug, a design inconsistency, or an App Store rejection needs fixing. Applies even when the user doesn't mention SwiftUI by name but is clearly building for iPhone or iPad.
---

# SwiftUI App Builder

Build iOS apps that survive App Store review and don't drift from their design as they grow.

The failure modes this exists to prevent are specific and they repeat: a design that erodes screen by screen until nothing matches the mock; dark mode that looks broken because colours were hardcoded; a rejection two days before launch for a privacy label nobody kept in sync with the code; a rebuild that silently changes the bundle ID and orphans the App Store listing.

## The order matters

Do not start writing views until you've been through the gates below. Each one exists because skipping it is expensive later, and the cost lands on the user, not on you.

```
0. Existing project?  → inventory it and protect it BEFORE touching anything
1. Intake gate        → get the design; get the PRD if there is one
2. Design system      → extract tokens from the design; this becomes the only source of colour
3. Scaffold           → project config with the known traps pre-solved
4. Build              → screens, one at a time, checked against the design
5. Integrations       → only what the PRD actually asks for
6. Pre-submit audit   → the checklist, run rather than read
```

---

## Phase 0 — Existing project

If the working directory already contains an `.xcodeproj`, `.xcworkspace`, or `Package.swift`, you are rebuilding, not starting fresh. **Rebuilding destroys things that cannot be recreated**, so the inventory comes first and the deletion comes much later.

Run the bundled script from the project root. Script paths in this skill are relative to the skill's own base directory (shown when the skill loads) — call it `$SKILL_DIR`:

```bash
bash "$SKILL_DIR/scripts/extract-reference.sh" > PROJECT_REFERENCE.md
```

It inventories identity, configuration, dependencies, persisted data and assets into a single file. Build settings are resolved for the app target's Release configuration (the values that actually ship), not the project-level defaults. It can't infer everything: check the device family and deployment target against what the live App Store version supports, and treat the product-ID list as candidates to verify. Read it, then fill the gaps it flags — some things (the App Store ID, the Firebase project owner, whether the app has shipped) only the user knows.

Three categories come out of it, and they have very different weights:

| Category | Examples | Rule |
|---|---|---|
| **Permanent identity** | Bundle ID, StoreKit product IDs, App Store ID, team ID | Never changes. Changing the bundle ID orphans the App Store record and every existing install |
| **Expensive to recreate** | Usage descriptions, entitlements, `GoogleService-Info.plist`, AdMob IDs, SKAdNetwork list, signing config, SPM pins | Carry forward verbatim unless the user asks otherwise |
| **Breaking if changed** | Persisted data: SwiftData `@Model` types, Core Data entities, UserDefaults / `@AppStorage` keys, Keychain items | If the app has shipped, this is what's on users' phones. Changing it without a migration loses their data. Confirm before altering |

Then, before deleting anything:

1. **Check git is clean.** `git status`. If there are uncommitted changes, stop and ask — they may be work in progress.
2. **Make it recoverable.** Commit the current state and tag it (`pre-rebuild-<date>`), so the old app is one command away.
3. **Put `PROJECT_REFERENCE.md` somewhere the wipe won't reach** — the scratchpad directory, or commit it first.
4. **Confirm with the user**, naming what will be deleted and what is being preserved. Wiping someone's app is not a step to take on inferred consent.

Only then remove the old sources and rebuild against the reference.

---

## Phase 1 — Intake gate

Ask for two things, and say plainly that the first one is what keeps the result coherent:

**The design (needed).** Any of these work, with different fidelity:

- **HTML/CSS mock** — best case. Exact hex values, spacing and radii can be read straight out of it
- **Figma export or screenshots** — sample colours from the image; ask about states you can't see (dark mode, empty, error)
- **A written direction** ("warm, editorial, serif headings, one lime accent") — propose a concrete system and get sign-off before building on it
- **Nothing** — offer to design one first. Don't quietly invent a look and start coding; the user will discover your taste three screens in, and by then it's expensive to change

**The PRD (optional).** Features, screens, data model, monetisation. A sentence is fine. If there isn't one, derive a screen list from the design and confirm it before building.

Also settle, inline and quickly: app name, bundle ID, monetisation (free / paywall / ads / both), and whether anything needs on-device AI or other heavy dependencies.

**Ask iPad support as its own explicit question — "iPhone only, or iPhone and iPad?"** — don't assume either way. The answer has to be set identically across the project generator's source file, the checked-in Xcode project, `Info.plist`'s orientation keys, and App Store screenshot requirements; see `references/project-scaffold.md`'s Orientation section for exactly where each one lives and how they drift independently.

---

## Phase 2 — Design system

Read `references/design-system.md` before doing this.

Turn the design into a token file (`Theme/DesignTokens.swift`) plus a short `DESIGN.md` recording what each token is for. Every later screen draws from it, which is what stops drift — a mock can't be "sort of" followed if there are no literal colours to drift with.

The distinction that causes the most bugs, so get it explicit in `DESIGN.md`:

- **Role tokens flip** with light/dark — page background, card surface, primary text, muted text, hairline
- **Accent tokens are fixed** on purpose — a brand gold, a lime highlight. These are deliberate, and they read as intentional only when documented as such

**If the design only shows light mode** — which is usual — derive the dark palette rather than improvising it screen by screen:

```bash
python3 "$SKILL_DIR/scripts/derive-dark-palette.py" --bg '#F4F1EA' --text '#0E0E10' --accent gold=#E4A93C
```

It proposes a hue-preserving dark palette and checks every pairing against WCAG. Show the proposal before building on it, and use its contrast report to pick the label colour for each accent fill — a fixed accent with a *flipping* label is a button that reads perfectly in light mode and is unreadable in dark.

The rule for everything after this phase: **views contain no literal colours, font sizes, or corner radii.** Not because literals are ugly, but because every one of them is a dark-mode bug waiting for a screenshot.

---

## Phase 3 — Scaffold

Read `references/project-scaffold.md`. Set up the project so the known traps are already handled — a real `Info.plist` rather than the generated one, xcconfig files for environment-specific IDs, the privacy manifest, orientation keys that pass iPad validation, export compliance. Several of these are one-line settings that cost a rejected build if missed.

---

## Phase 4 — Build the screens

Work screen by screen, not in one pass. After each screen:

```bash
bash "$SKILL_DIR/scripts/design-check.sh" <app-source-dir>
```

It greps for literal colours, hardcoded font sizes and magic-number radii outside the token file. This catches in seconds the class of bug that otherwise surfaces one screenshot at a time, days later.

Build against the design, not against your memory of the design — re-read the mock for each screen. When something in the mock is ambiguous, ask rather than inventing; an invented answer becomes a precedent the rest of the app copies.

Prefer native components over hand-rolled ones: a system `TabView` (including `Tab(role: .search)` for a detached item), system navigation, standard sheet presentation. Hand-built equivalents drift from the platform at every OS release and quietly lose accessibility behaviour you'd then have to rebuild.

---

## Phase 5 — Integrations

Only wire up what the PRD asks for. Each of these has its own reference file with the specific traps:

| Need | Read |
|---|---|
| Analytics, crash reporting | `references/firebase.md` |
| Ads | `references/admob.md` |
| Subscriptions, paywall, free-tier limits | `references/storekit-paywall.md` |

The common thread: **development must not depend on production credentials.** Test ad units in Debug, a local StoreKit configuration for purchases, so the app is fully exercisable before a single real ID exists.

---

## Phase 6 — Pre-submit audit

Read `references/app-review.md` and run it as a pass over the finished app. It's built from rejections that actually happened, not from a general reading of the guidelines.

The one that catches almost everyone: **the privacy label in App Store Connect must match what the code actually does.** If the app asks for tracking permission, the label says it tracks. If it doesn't, it doesn't. A mismatch in either direction is a rejection, and it's invisible from inside Xcode.

---

## Working style for this kind of work

**Verify against the build, not against memory.** When you replace something Xcode generates — an Info.plist, a build setting — build the old configuration into a separate `-derivedDataPath`, build the new one, and diff the outputs key by key. Assumptions about "what Xcode normally produces" are wrong often enough to matter, and the diff takes two minutes.

**A screenshot is the test for UI.** Build, install, look at it — in both light and dark mode. Type-checking proves the code compiles, not that the screen is right.

**When the UI to check is behind an interaction** — a sheet that opens on tap, a toggle that reveals more content — launch isn't enough to screenshot it. A throwaway XCUITest is the fastest way to get real proof: launch with debug launch args that skip onboarding, tap through to the state you need, save `app.windows.firstMatch.screenshot().pngRepresentation` to a file, then look at it. It's scaffolding, not part of the app — delete the test file (and its project-file entry, if the project doesn't use file-system-synchronized groups) once you've seen the result.

**Say which things you didn't verify.** "Built and installed, but I haven't seen the paywall in dark mode" is useful. Silence reads as a claim.

**Porting a pattern from a reference app: the structure transfers, the tuned constants might not.** A well-built component in another codebase is worth copying — but check what each number in it assumes before reusing it verbatim. A padding value trimmed to compensate for one iOS version's sheet-presentation behavior is correct there because that app targets only that version; an app with a lower deployment target still has to support the OS behavior the original number was trimmed *away* from. Copy the technique, re-derive the constant.
