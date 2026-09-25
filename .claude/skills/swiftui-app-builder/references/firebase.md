# Firebase

Analytics and Crashlytics, with the integration traps that cost real debugging time.

## Adding it

Swift Package Manager: `https://github.com/firebase/firebase-ios-sdk`, up-to-next-major.

**Product names have changed and the old guidance is still everywhere.** In 12.x:

| Product | What it gives you |
|---|---|
| `FirebaseCore` | Required for `FirebaseApp.configure()` |
| `FirebaseAnalytics` | Analytics **without** IDFA — this is now the default build |
| `FirebaseAnalyticsIdentitySupport` | Opt-in, **adds** IDFA collection |
| `FirebaseCrashlytics` | Crash reporting |

The older `FirebaseAnalyticsWithoutAdId` product no longer exists, and the polarity flipped: plain `FirebaseAnalytics` used to include IDFA and now doesn't. Adding it alone means **no IDFA, no ATT prompt required, nothing to declare as tracking** — usually what you want until ads actually ship. Verify rather than trust:

```bash
otool -L YourApp.app/YourApp | grep -i adsupport      # expect no match
nm -u YourApp.app/YourApp | grep -i ASIdentifier      # expect no match
```

## The `-ObjC` linker requirement

`GoogleAppMeasurement 12.19.0` ships the `APMMeasurement+SBT` category without an anchor symbol. The linker strips it as dead code, and at runtime something calls `fetchSBT` on a class that no longer implements it:

```
*** Terminating app due to uncaught exception 'NSInvalidArgumentException',
reason: '-[APMMeasurement fetchSBT]: unrecognized selector sent to instance'
```

It crashes during Firebase's own startup, so the app dies before any of your UI appears — which also means any ATT prompt or first-screen logic never runs, and the symptom looks unrelated to Firebase.

```
OTHER_LDFLAGS = ("$(inherited)", "-ObjC")
```

`-ObjC` forces every object file in a linked static archive to be kept, anchor symbol or not. Set it when adding Firebase rather than waiting for the crash. Clean-build afterwards — the stripped category can persist in cached objects.

## Crashlytics dSYM upload

Without symbol upload, crash reports arrive as raw addresses instead of stack traces. Add a run-script phase after Resources:

```bash
# Debug builds emit plain DWARF and have nothing to upload. Firebase's own
# `run` wrapper fails the build when it can't find a dSYM, so guard it.
DSYM="${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}"
if [ ! -d "$DSYM" ]; then echo "note: no dSYM — skipping"; exit 0; fi
UPLOAD="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"
if [ ! -x "$UPLOAD" ]; then echo "warning: upload-symbols not found — skipping"; exit 0; fi
"$UPLOAD" -gsp "${PROJECT_DIR}/YourApp/GoogleService-Info.plist" -p ios "$DSYM"
```

**Declare the plist as a script input.** Modern projects have `ENABLE_USER_SCRIPT_SANDBOXING = YES`, which blocks the script from reading undeclared files — the failure is `Unable to read Google Service plist` even though the path is perfectly correct:

```
inputPaths = (
    "$(PROJECT_DIR)/YourApp/GoogleService-Info.plist",
    "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}",
);
```

Declaring inputs is better than turning sandboxing off project-wide.

## Initialisation

```swift
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication,
                     didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main struct YourApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // …
}
```

`GoogleService-Info.plist` must be in the bundle — it's a resource, unlike `Info.plist`, so a synchronized group including it automatically is correct here.

## One wrapper for analytics, with a closed vocabulary

Route every event through one file. It keeps what leaves the device auditable as a short list rather than something to hunt for across a hundred views:

```swift
enum Analytics {
    /// Closed set — there is deliberately no way to pass free text through this
    /// API, so no call site can leak user content even by accident.
    enum Feature: String { case search, export, share }

    static func featureUsed(_ f: Feature) {
        FirebaseAnalytics.Analytics.logEvent("feature_used", parameters: ["feature": f.rawValue])
    }
}
```

**Nothing sensitive in an event, ever** — no names, notes, photos, locations, health or financial data, not as event names and not as parameters. Beyond the privacy question, health data reaching an analytics or advertising pipeline is exactly what App Store guideline 5.1.3 prohibits. An enum-only parameter API makes the guarantee structural instead of a rule people have to remember.

A handful of well-chosen events beats exhaustive instrumentation: onboarding completed, a heavy one-time setup finished, key feature used, paywall shown, purchase completed. Those five answer most product questions.

**SwiftUI note:** automatic `screen_view` tracking keys off UIKit view controllers. A SwiftUI app is one hosting controller, so screen names won't populate until you log them explicitly.

## What this means for the privacy label

Adding Analytics changes the app from "collects nothing" to collecting: **Device ID** (the Firebase app-instance ID), **Product Interaction**, **Crash Data** (with Crashlytics), and **Coarse Location** (Firebase infers region from IP). All with purpose *Analytics*, and — with plain `FirebaseAnalytics` — **none of it used for tracking**.

Update App Store Connect and the privacy policy in the same change that adds the SDK. A policy still saying "no analytics" while the binary contains Firebase is its own rejection.
