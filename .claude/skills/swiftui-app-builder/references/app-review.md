# App Store review

A pre-submit pass. Every item here comes from a rejection that actually happened, not from a general reading of the guidelines — which is why it's short and specific rather than a summary of the whole rulebook.

## The one that catches almost everyone

**The privacy label in App Store Connect must match what the binary actually does.** It's edited in a web form, invisible from inside Xcode, and drifts the moment the code changes.

Both directions are rejections:

| Label says | Code does | Result |
|---|---|---|
| Collects tracking data | No ATT prompt | **5.1.2** — "apps need permission before tracking" |
| No tracking | Asks for ATT / uses IDFA | Inconsistent; reviewers flag it |
| Health/Fitness used for advertising | anything | **5.1.3** — automatic, no version of this is permissible |

Walk the label category by category against the code before every submission. The common failure is a stale label left over from a template or an earlier architecture — an app with no ad SDK at all declaring Advertising Data, Device ID, Precise Location and User ID for tracking, purely because the questionnaire was filled in optimistically at the start.

**Checking the code rather than assuming:**

```bash
grep -rn "AppTrackingTransparency\|ATTrackingManager" --include="*.swift" .   # is ATT used?
grep -c NSUserTrackingUsageDescription **/Info.plist                          # is the string there?
otool -L YourApp.app/YourApp | grep -i adsupport                              # is IDFA linked?
grep -rniE "firebase|adjust|appsflyer|amplitude|mixpanel|sentry" --include="*.swift" .
```

If all of these come back empty, the honest answer to "do you collect any data?" is **No**, and that single answer clears the whole section.

**`PrivacyInfo.xcprivacy` has its own, stricter validation, independent of the ASC label — and it's easy to fix it wrong.** Apple's build-time check (ITMS-91064) enforces `NSPrivacyTracking` and `NSPrivacyTrackingDomains` as a matched pair, in **both directions**, per TN3181:

- `NSPrivacyTrackingDomains` non-empty → `NSPrivacyTracking` must be `true`
- `NSPrivacyTracking: true` → `NSPrivacyTrackingDomains` must have **at least one real domain**

`true` with an empty domains array is just as invalid as `false` with a populated one — same error code, opposite direction. The instinctive fix on seeing this rejection is to flip the app's own `NSPrivacyTracking` to `true` because the app requests ATT for an ad SDK's benefit — **don't**, unless you're also adding the real domain(s) that SDK actually tracks through. If your own app code never contacts a tracking domain directly (the SDK's compiled framework does that, using the permission you requested on its behalf), leave the app's own manifest at `NSPrivacyTracking: false` with an empty domains array, and let the SDK's own bundled `PrivacyInfo.xcprivacy` carry its own tracking declaration — this is Apple's documented merge model, and it's the config a real submission was confirmed to pass review with (a developer reported exactly this on the Apple Developer Forums: set the app's own key `false`, relying on the ad SDK's manifest, submitted, passed).

When Build 1 gets rejected for this and the app's own manifest is already `false`/empty (a combination that's valid either way), the actual cause is very likely a third-party SDK's *own* bundled manifest — often an ad SDK version with a known bug in its shipped manifest, fixed in a later release. Check what's resolved (`grep -rn "NSPrivacyTrackingDomains" <DerivedData>/SourcePackages/**/PrivacyInfo.xcprivacy` and parse each one's pair for the same both-directions rule) before touching the app's own file at all.

## Apple-framework attribution

Several frameworks require visible attribution wherever their data appears:

- **WeatherKit** — the Apple Weather mark *and* a link to the legal attribution page, on every screen showing weather data. Fetch both from `WeatherService.shared.attribution` (`combinedMarkLightURL` / `combinedMarkDarkURL` / `legalPageURL`) rather than approximating the mark. Missing it is **5.2.5**
- **MapKit** — Apple's own attribution is built into the map view; don't cover it

If a framework's data isn't worth its attribution, removing the framework is a legitimate resolution — and a cleaner one than a half-hearted logo in a corner.

## Sensitive-content apps

Health, medical, finance, legal:

- **Say what the app is not**, at the point of the result, not only in a banner beforehand. Someone who has just been told "probably minor" has already relaxed — that's precisely when the disclaimer has to appear. A reassuring result is not clearance
- **Separate urgency levels.** "See a professional" and "go now" are different instructions; one paragraph flattens them into neither
- Mirror the same language in the Terms — the in-app copy and the legal document should not describe different products

Guideline **1.4.1** covers physical harm through inaccuracy. Explicit, unmissable, result-adjacent disclaimers are what reviewers look for on generated health output.

## In-app purchase

- A lifetime tier priced well above the subscription triggers an automated **price-confirmation hold**. Not a rejection — reply confirming it's intentional and what it buys
- Every product must reach "Ready to Submit" and be attached to the version, or the production paywall shows an empty state
- Product **display names** are visible in the purchase sheet. After an app rename, rename them too — a payment dialog branded differently from the app is confusing and gets flagged
- **Restore purchases** must be reachable for non-consumables

## App Store Connect metadata limits

Easy to blow past without checking, and ASC won't tell you until you paste it in:

| Field | Limit |
|---|---|
| App Name | 30 characters |
| Subtitle | 30 characters |
| Keywords | 100 characters total, comma-separated |
| Promotional Text | 170 characters — the only one editable without a new review |
| Description | 4000 characters |

Keywords are wasted on words already covered by the Name, Subtitle or category — those are indexed automatically, so repeating them there is space that could hold a term nothing else covers.

## Build-level items

| Item | Setting |
|---|---|
| iPad orientations | All four, or `TARGETED_DEVICE_FAMILY = 1` |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` for HTTPS-only apps |
| Release signing | `DEVELOPMENT_TEAM` set on **Release**, not just Debug |
| Privacy manifest | `PrivacyInfo.xcprivacy` present with required-reason APIs |
| Permission strings | Every one justified by a shipping feature — an unused string is a rejection |

## Bundle hygiene

Check what's actually inside the built app, because synchronized groups include files silently:

```bash
ls YourApp.app/            # design mocks? .storekit? stray HTML? none of these belong
du -sh YourApp.app
```

## Naming

- **Uniqueness is enforced at reservation**, and web search can't see names other developers have reserved but never shipped. App Store Connect is the only reliable test — type the name into New App and it tells you immediately
- A **live trademark** beats an App Store reservation regardless of who listed first. Check [USPTO TESS](https://tmsearch.uspto.gov) before committing
- Names that read as near-misses of an established competitor invite **4.1** ("confusingly similar") trouble, even when technically distinct

## Before renaming a shipped app

| Never changes | Safe to change |
|---|---|
| Bundle ID | Display name (`CFBundleDisplayName`) |
| StoreKit product IDs | App Store listing name, subtitle |
| App Store ID | UI copy, launch art, legal pages |

Changing a bundle ID doesn't rename the app — it creates a different app, orphaning the listing, every review, and every existing install. Product IDs are equally permanent: they're baked into purchases people already own.

Renaming also has reach beyond the obvious: permission strings in Info.plist, PDF export headers, share text, the legal pages, the launch-screen wordmark. Sweep for the old name across **all** file types, not just Swift:

```bash
grep -rl "OldName" --include="*.swift" --include="*.html" --include="*.md" --include="*.plist" .
```

## Replying to a rejection

Reviewers move much faster on an explained resubmission than a silent one. State what changed, and where to find it — "tracking permission is requested the first time the user reaches the main app, after onboarding" saves a round trip. If the resolution was removing a framework rather than complying with it, say that plainly.
