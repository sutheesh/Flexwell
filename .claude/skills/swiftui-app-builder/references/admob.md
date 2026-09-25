# AdMob

Ads wired up so development never touches live inventory, and ATT handled before it becomes a rejection.

## IDs come from xcconfig, never from source

Google publishes sample ad units that always fill and never affect your account. Put those in Debug and the real ones in Release, so no source file knows which environment it's in:

```
# Config/Debug.xcconfig — Google's published sample units
ADMOB_APP_ID       = ca-app-pub-3940256099942544~1458002511
ADMOB_BANNER       = ca-app-pub-3940256099942544/2934735716
ADMOB_INTERSTITIAL = ca-app-pub-3940256099942544/4411468910
ADMOB_REWARDED     = ca-app-pub-3940256099942544/1712485313
ADMOB_NATIVE       = ca-app-pub-3940256099942544/3986624511
ADMOB_APP_OPEN     = ca-app-pub-3940256099942544/5575463023

# Config/Release.xcconfig — your real units
ADMOB_APP_ID       = ca-app-pub-<publisher>~<app>
ADMOB_BANNER       = ca-app-pub-<publisher>/<unit>
```

Info.plist consumes them as build variables:

```xml
<key>GADApplicationIdentifier</key><string>$(ADMOB_APP_ID)</string>
<key>ADMOB_BANNER</key><string>$(ADMOB_BANNER)</string>
```

This matters beyond tidiness: testing against live ad units risks your AdMob account for invalid traffic, and a hardcoded test ID that survives into Release means an app that serves sample ads and earns nothing.

Don't add `GADApplicationIdentifier` before you have a real app ID — the Mobile Ads SDK reads it at launch and crashes on a missing or malformed value.

## SKAdNetwork

Attribution needs the ad networks' identifiers in Info.plist:

```xml
<key>SKAdNetworkItems</key>
<array>
    <dict><key>SKAdNetworkIdentifier</key><string>cstr6suwn9.skadnetwork</string></dict>
    <!-- Google's full published list — ~50 entries -->
</array>
```

Take the current list from Google's AdMob quick-start docs rather than copying an old one; it grows. The array is inert without an ads SDK, so it's safe to add ahead of time.

## App Tracking Transparency

Required before any IDFA access. Two parts:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>Allow tracking to see ads that are more relevant to you.
You can still use everything in the app if you decline.</string>
```

Missing this key is a **hard crash**, not a silent skip, the moment you call the API.

```swift
enum TrackingService {
    @MainActor static func requestIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        // A request fired the instant a view appears can race the window becoming
        // key and be silently dropped — a beat lets that settle.
        try? await Task.sleep(nanoseconds: 500_000_000)
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }
}
```

**Where to ask.** Not at cold launch, and not on a screen where it interrupts something. The first time the user reaches the main app after onboarding works well — they've seen enough to judge, and nothing is mid-flight. Calling it repeatedly is harmless; once answered, the status is no longer `.notDetermined` and it returns without prompting.

**Asking ahead of shipping ads is fine** and saves a rework later — the permission is in place before the SDK needs it. But the privacy label has to move at the same time (below), or the app asks for tracking permission while declaring it doesn't track, which is the mismatch reviewers catch.

## What the privacy label must say once ads ship

| Category | Declare | Purposes | Tracking? |
|---|---|---|---|
| Identifiers — Device ID (IDFA + app-instance ID) | Yes | Analytics, Third-Party Advertising | **Yes** |
| Usage Data — Product Interaction, Advertising Data | Yes | Analytics, Third-Party Advertising | **Yes** |
| Diagnostics — Crash/Performance | Yes | Analytics, App Functionality | No |
| Location — **Coarse** only | Yes | Analytics, Third-Party Advertising | Yes |
| Contact Info | **No** | — | — |

Two corrections worth making explicitly, because both are commonly over-declared:

**Contact Info stays "Not Collected"** unless you add authentication. Analytics and ad SDKs don't collect names or emails on their own.

**Keep Location at Coarse.** Precise Location is a separate, heavier declaration, needed only if you deliberately hand GPS coordinates to the ad SDK. Location used solely for MapKit/WeatherKit-style real-time requests isn't "collected" at all under Apple's definition — you never receive or retain it.

## Health, finance, and sensitive categories

Guideline 5.1.3 prohibits using health or fitness data for advertising, marketing, or data mining. In practice, for an app that handles anything sensitive:

**Never let that data reach an ad or analytics pipeline** — not as event parameters, not as user properties, not as audience segments. An enum-only analytics API (see `firebase.md`) makes this structural rather than a rule someone has to remember at every call site.

Declaring Health or Fitness as "used for tracking" in App Store Connect is an automatic rejection, and it describes an app almost nobody intends to ship.
