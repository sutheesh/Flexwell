# FlexFit — work progress and handoff

Last updated: 2026-09-26. Read this first, then `DESIGN.md`, then the code.

## 1. What FlexFit is

An iPhone + iPad fitness app (SwiftUI, iOS 18+, Liquid Glass on iOS 26) that plans training **and** food around the user's goal, and adapts the day when life gets in the way (low energy, no gym, missing ingredient, eating out).

- **Inputs:** `docs/FlexFit PRDv2.docx` (product spec) and `docs/design/FlexFit-mock.html` (visual source of truth; readable markup in `docs/design/mock-template.html`).
- **Scope, decided by the owner:** build **everything** in the PRD and the mock. Ignore "MVP / phase 1 / phase 2" labels.
- **Identity:**
  - Bundle ID `com.ilabbs.flexfit`; app group `group.com.ilabbs.flexfit`; iCloud container `iCloud.com.ilabbs.flexfit`.
  - GitHub repo: `git@github.com:sutheesh/Flexwell.git` (branch `main`).
  - The app may be renamed later ("FlexFit" is taken); no rename done yet.
- **Business model:** freemium with a Pro subscription (StoreKit 2).

## 2. Working agreements with the owner (important)

- **Commit and push only when asked.** The owner often says "commit but don't push", or "push now, then don't push until I say".
- **Commit state right now:**
  - Last push was `24b795a` ("Gym library, progress tile, new tab layout, food scanner").
  - Everything after it is **uncommitted**: the swap bottom sheet (section 6.3) and this file.
- **Never commit `.freebuff/`** (keep it untracked). `.claude/settings.json` is gitignored.
- **Match the mock 1:1** where the mock has a screen. Where it doesn't (Profile, Progress, the Gym library), reuse the app's tiles and tokens.
- **Deploy to the owner's phones after each change** (commands in section 4):
  - iPhone 17 Pro: `1A7DD07B-3433-509A-95C6-72A1DE406968`
  - iPhone 12 Pro Max "iPhone S": `4BA01009-C3D2-5F4B-8DB9-EA7540FCFCAD`
- **The owner writes short, informal messages.** Confirm scope before big features when they ask for that ("confirm the scope, I'll confirm before edits").
- **Commit messages** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## 3. Stack and layout

| Area | What |
|---|---|
| Project | XcodeGen (`project.yml` → `FlexFit.xcodeproj`). Run `xcodegen generate` after adding or removing files. |
| App | `FlexFit/` (SwiftUI) plus `Shared/` (widget and watch payloads) |
| Engine | `Packages/FlexFitEngine` (pure Swift, no UI). JSON resources: `exercises.json` (150), `meals.json` (120), `restaurants.json`, `nutrition.json` (171 foods), `exercise_guides.json` (steps and cues for all 150; **draft, needs review by a qualified coach**) |
| Tests | Engine tests with Swift Testing: `cd Packages/FlexFitEngine && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` (60 passing) |
| Persistence | SwiftData, `SchemaV1` (`FlexFit/Data/Schema.swift`), mirrored to the CloudKit private DB. Every property has a default and nothing is unique (CloudKit rule). |
| Extensions | `FlexFitWidgets` (WidgetKit; app group snapshot) and `FlexFitWatch` (watchOS 10+; WatchConnectivity) |
| Third party | [MuscleMap](https://github.com/melihcolpan/MuscleMap) 1.6.4, MIT, pinned: the anatomical body figure. The licence text is in-app (Profile → Acknowledgements, `LegalPage.swift`). |
| Apple frameworks | StoreKit 2, HealthKit, Foundation Models (on-device coach text, template fallback), Vision + AVFoundation (food scanner), Charts |

### App source map

- `App/`
  - `FlexFitApp`
  - `RootView`: tabs, a single `.sheet(item:)`, full-screen covers, toast
  - `AppRouter`: sheet enum, `tab`, `gymPath`, toasts, `-FFTab` launch argument
  - `MockTabBar`: the floating bar
- `Today/`
  - `TodayView`: progress tile, check-in, energy, session card, What changed, next meal, Log progress, Your path
  - `ProgressViews`: tile, Progress page, Log progress sheet, weekly check-in card
- `Train/`
  - `TrainView`: Gym tab — week strip, session card, "My plan | Exercises", session plan, This week
  - `PlanResolver`: plan + swaps + travel + pivots for a day
- `Gym/`
  - `ExerciseLibrary`: body map, muscle lists, swap list, exercise detail, favourites, rest timer, navy "Gym chrome"
  - `BodyFigure`: MuscleMap wrapper, our muscle-group mapping, custom feet with toes, body-map anchors
- `Eat/`: `EatView` (calorie card, search, scanner, picked-for-you, day chips, meals, logged food), `MealViews` (meal card, meal detail with ingredient "flower"), `MealPlanContext` / `DayIntake` (single source of eaten totals), `GroceryView`, `FoodEntryRow`
- `Scan/`: camera scanner (photo classify, barcode via Open Food Facts, nutrition-label OCR), `FoodDetailsView`
- `Path/`: `PathView` (pushed from Today; goal chart, road, day by day, adapt log, weigh-in and targets, volume, PRs), `RoadAndDays`, `WeighInSheet`
- `Settings/`: `SettingsView` is the **Profile tab** (tiles; editable body details), `LegalPage` (privacy, terms, acknowledgements)
- `Workout/`: `WorkoutView` (full-screen logging)
- `Adapt/`: `AdaptSheet` (the "What changed?" sheet)
- `Onboarding/`: intro, 16-step wizard, building, plan ready
- `Paywall/`, `Services/`: store, entitlements, Health, reminders, targets upkeep, watch sync, coach text
- `Theme/DesignTokens.swift` and `Components/` (controls, labels, mock chrome)

## 4. Build, run, verify, deploy

Always prefix with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Keep derived data in a scratch folder.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
# Simulator (iPhone 17 Pro sim used throughout: 0CCCE408-C45D-47E6-85EE-2E06E6442028)
xcodebuild -project FlexFit.xcodeproj -scheme FlexFit -configuration Debug \
  -destination "id=0CCCE408-C45D-47E6-85EE-2E06E6442028" -derivedDataPath /tmp/dd build
xcrun simctl install <sim> /tmp/dd/Build/Products/Debug-iphonesimulator/FlexFit.app
xcrun simctl launch --terminate-running-process <sim> com.ilabbs.flexfit -FFLocalOnly -FFTab train
# Devices
xcodebuild ... -destination "generic/platform=iOS" -derivedDataPath /tmp/dd-device -allowProvisioningUpdates build
xcrun devicectl device install app --device <id> /tmp/dd-device/Build/Products/Debug-iphoneos/FlexFit.app
xcrun devicectl device process launch --device <id> com.ilabbs.flexfit   # fails if the phone is locked
```

**Gotchas:**
- **Stale package resources:** when engine resources change (a JSON is added or renamed), delete derived data. A stale bundle once crashed the app because `meals.json` was missing.
- **Design check:** `.claude/skills/swiftui-app-builder/scripts/design-check.sh FlexFit` fails on literal colours, font sizes or radii in views. Everything goes through `Palette`, `TextStyle` (`.textStyle(.x)`), `Radius`, `Space`, `Size`.

**Debug launch arguments** (`Data/DebugLaunch.swift`, `AppRouter.launchTab`):
- `-FFResetData`: wipe every model
- `-FFSeedProfile`: demo "Alex", 4 days/week, 82 → 75 kg
- `-FFSeedHistory`: weigh-ins and 12 sessions
- `-FFLowYesterday`, `-FFPro`, `-FFWatchDemo`
- `-FFLocalOnly`: skip CloudKit
- `-FFTab train|eat|profile`: open on a tab

**Screen verification recipe** (how every change was checked):
1. Write a throwaway XCUITest in a `.shots/` folder.
2. Generate a separate project, `FlexFitShots.xcodeproj`, from a copy of `project.yml` with `name: FlexFitShots` and an extra target:
   ```yaml
   ShotsUITests:
     type: bundle.ui-testing
     platform: iOS
     sources: [.shots]
     dependencies: [{target: FlexFit}]
     settings: {base: {GENERATE_INFOPLIST_FILE: YES, TEST_TARGET_NAME: FlexFit}}
   ```
3. Run it with `SIMCTL_CHILD_SHOT_DIR=... TEST_RUNNER_SHOT_DIR=...`. The tests write screenshots there.
4. Delete `FlexFitShots.xcodeproj` and `.shots/` afterwards.

   Generating the project into a folder outside the repo hangs XcodeGen; generate it in the repo root under the other name. To render the mock for comparison, use headless Chrome via the cached Playwright (`~/.npm/_npx/*/node_modules/playwright`).

## 5. Architecture conventions (keep these)

- **Sheets:**
  - **One `.sheet(item: $router.sheet)`** at the root. Stacked `.sheet` modifiers presented unreliably.
  - Full-screen covers hang off `.background { Color.clear.fullScreenCover }`.
  - Sheets with text fields use a **plain header** (Cancel / title / Save), not a nav bar: a nav-bar button's first tap only dismissed the keyboard.
- **Eaten totals:** `DayIntake` is the only way to compute them (planned meals ticked plus `FoodEntry` records).
- **Gym is always navy:** it forces `.colorScheme(.dark)` and uses fixed tokens (`Palette.navy`, `navyRaised`, `ice`, `onPanel…`).
- **Tab bar:**
  - `mockTabBarSpace()` hides the system tab bar and adds **content margins**, not safe-area padding. Pushed pages inherit margins; safe-area padding didn't reach them, so content hid behind the bar.
  - Tabs with their own stacks: Today (`TodayRoute.path`, `.progress`) and Gym (`AppRouter.gymPath`, `GymRoute.group`, `.exercise`). The swap sheet has its own stack (`GymRoute.swapDetail`).
- **MuscleMap:**
  - Its view catches taps even without a handler, so `BodyFigure` sets `allowsHitTesting(onTap != nil)`.
  - Its feet are crude, so they're hidden (`.highlight(.feet, color: .clear)`) and ankles re-coloured. `FeetShape` draws feet with toes in the model's 727 × 1280 view box, mirrored about x = 365.35.
  - Body-map dots come from path centroids, as fractions of that box.
- **Schema changes:**
  - Adding models or properties to `SchemaV1` has worked with lightweight migration so far.
  - Removing properties also worked (protein check removed).
  - **Before the first App Store release, freeze `SchemaV1`** and use `SchemaV2` plus a migration stage for further changes.
  - New models must also be added to the reset lists: `SettingsView.reset`, `TodayView.startOver`, `DebugLaunch`.

## 6. Feature status

### 6.1 Tabs (current layout, owner-directed)
`[ Gym | ⚡ Today (raised centre, no label) | Eat ]` in a floating navy capsule, plus **Profile** as a separate circle ("split tab").
- Adapt ("What changed?") is a tile on Today, not a tab.
- Path is pushed from Today's "Your path" tile.

### 6.2 Today
- **Progress tile (first, white card):** weight change and trend, muscle (lean mass / body fat), average kcal per day with days on target and weekly mini bars, sessions · hours · weight lifted, walking (Health). It opens the **Progress page**: 4 weeks / 3 months / All, with Free limited to 30 days.
- **Weekly check-in card:**
  - Shown when there's no weigh-in for 7 days, or no body measurement for 14.
  - "Later" snoozes it until tomorrow (`@AppStorage checkInSnoozedUntil`).
  - A Sunday notification fires at the reminder hour (`Reminders.scheduleWeekly`).
- **Energy check-in** on training days only.
- **Slim session card (white):** Start, a summary line, and a tap to open Gym.
- **What changed?** tile → Adapt sheet.
- **Next meal:** the next meal plus "N of M eaten · kcal left · See all"; logged food shows with Undo.
- **Log progress** (permanent tile): weight, body fat %, lean mass, waist.
- **Your path** tile.
- **Cart:** none on Today or Gym; it lives on Eat and Profile.

### 6.3 Gym
- **Top:** week strip, then today's session card. Session names say what leads, e.g. "Full body · Squat day", with a summary line.
- **My plan | Exercises** switch below the card.
- **My plan:**
  - Session rows show sets × reps · equipment. The name opens the exercise detail; the number circle marks done.
  - **Swap** opens the **swap bottom sheet** (`SwapSheet` in `Gym/ExerciseLibrary.swift`, presented through the root sheet as `AppRouter.Sheet.exerciseSwap`) *(new, uncommitted)*:
    - A 2-column card list of every safe alternative for the same movement pattern with the gear you have, ranked by `SwapRanker` (limit 40), the first card badged "Best match".
    - A "Just today / From now on" switch.
    - A **⇄ Swap** pill on each card, bottom right. Tapping the card pushes its detail page inside the sheet, which leads with "Swap in for X".
    - Swapping saves an `ExerciseSwap`, closes the sheet and shows a toast.
  - The old pop-up swap sheet (engine top 3) was replaced by this.
- **Exercises:**
  - Body map uses **AI-generated photos supplied by the owner** (`BodyMapFront` / `BodyMapBack`, cut out onto transparency with Vision). Dots and label rows are placed by eye (`BodyGeometry.anchors`); tapping the body opens the nearest muscle. Cards and detail pages still use the MuscleMap figure for highlighting.
  - Bottom row: flip, favourites ★ and rest timer. No search bar (the owner removed it).
  - Muscle list: 2-column cards, "My equipment | All".
  - Exercise detail:
    - **Guidance:** at a glance, muscles worked with front/back figures, how to do it, take care if, my notes.
    - **Performance:** sessions, best set, estimated-max chart, session history.

### 6.4 Eat
- Calorie card (arc) moved here from Today.
- Search plus a scan button. Picked for you, day chips, meal cards, logged food and saved meals.
- The scanner logs a `FoodEntry`; restaurant picks can replace dinner.
- Meal detail uses the reference "flower" design; ingredient swaps are available.

### 6.5 Profile (the Settings screen, restyled)
- Header and navy "you" card.
- Tiles:
  - About you: name, age, sex, height, target weight, goal, units
  - Training
  - Food
  - Coaching
  - Apple Health
  - Pro
  - Health & privacy, including Acknowledgements
  - Start over
- Values edit in place; the Profile page is pinned to screen width, so it can't slide sideways.

### 6.6 Other screens
- **Path:** built from the mock. The weigh-in, Pro targets upsell, target notices, volume and PRs sit below the mock's content.
- **Onboarding:** full 16-step wizard, including food preferences.
- **Paywall and Pro gating:** in place.
- **Other surfaces:** Workout logging, Watch app, widgets, iCloud backup, HealthKit (reads weight, body fat, lean mass, waist, steps and distance; writes strength workouts).

### 6.7 Removed on purpose
- The daily protein check (PRD F7) and all its logic.
- The system tab bar.
- The Cardio pill and search bar on the body map.
- Cart icons on Gym, Today and Path.

## 7. Known gaps and next steps

- **Swap bottom sheet is uncommitted** (section 2). It was tested on the simulator and deployed to both phones.
- **RepDB exercise illustrations** (free tier): all 150 exercises have start and peak images. The 22 that had no RepDB match were replaced with RepDB exercises of the same movement pattern: band variants, towel door row, prone Y raise, chair squat, pull-throughs, rack carry, bear plank, leg-press calf raise, and six mobility drills. Their guides now come from RepDB's steps and tips. Band-only users no longer have a band pulldown; the builder falls back to a row. The images are in `Assets.xcassets/Exercises/ex_<id>_<start|peak>.jpg`, converted from RepDB WebP. They're used on cards (`ExerciseArt`), the detail thumbnail and the "The movement" card. `ExerciseArt` still falls back to the MuscleMap figure if an image is missing. **Licence:**
  - The credit "Exercise data by RepDB (repdb.co)" must stay in Acknowledgements.
  - No republishing the images as a dataset, so **keep the GitHub repo private**.
  - No using them as input to generative AI.
- Body-map dots are red (`Palette.mapDot`) with a white ring.
- **Exercise guidance** (`exercise_guides.json`) is draft copy. It needs review by a qualified coach or physio before release; the app says so on each detail page.
- **Privacy policy URL** is a placeholder (`LegalPage.swift` TODO).
- **Real exercise photos and videos:** `exercises.json` media points to non-existent `r2://clips/...`. Detail pages show a drawn illustration.
- **Progress page:**
  - Calorie charts were only seen in their empty state with seed data.
  - Walking needs a real device with Health data.
- **Feet:** a faint overlap line where ankle and heel meet (cosmetic).
- **Nothing tested yet on:**
  - the full-body session names with real data (the seed profile is 4 days → Upper/Lower)
  - the Today card's move-list text on a training day
- **Schema freeze** before the first public build (section 5).
- **Possible next steps the owner hinted at:** keep matching screens to the mock, and a possible rename.

## 8. History (commits on `main`)

- `c6477ee` recipe library (120 meals)
- `0c9c779` on-device coach intros and widgets
- `96628c9` iCloud backup
- `61b2233` Apple Watch session view
- `62d2a56` match the mock screen by screen
- `24b795a`:
  - new tabs and floating bar
  - Gym library (MuscleMap)
  - Today progress tile, Progress page and check-in
  - Eat calorie card and food scanner
  - Profile restyle
  - protein check removed
  - session names
- *(uncommitted)* swap bottom sheet; this handoff file
