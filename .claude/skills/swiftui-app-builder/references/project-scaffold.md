# Project scaffold

Configuration that costs a rejected build, a broken launch, or an afternoon of confusion if it's wrong. Most are one-line settings; all are cheaper to set now than to debug later.

## A real Info.plist, not a generated one

Xcode's default (`GENERATE_INFOPLIST_FILE = YES`) synthesises the plist from `INFOPLIST_KEY_*` build settings. That's fine until you need something the build settings can't express — an `SKAdNetworkItems` array, a scene manifest, nested dictionaries — at which point you need a real file.

```
GENERATE_INFOPLIST_FILE = NO
INFOPLIST_FILE = YourApp/Info.plist
```

**Migrating from generated to real:** don't hand-write it from memory of what Xcode produces. Build the generated version first, copy the output plist out of the built `.app`, and use that as the starting point. Then diff the two builds key by key:

```bash
xcodebuild -derivedDataPath /tmp/old build     # before the change
plutil -p /tmp/old/Build/Products/*/YourApp.app/Info.plist > /tmp/old.txt
# ... make the change ...
xcodebuild -derivedDataPath /tmp/new build
plutil -p /tmp/new/Build/Products/*/YourApp.app/Info.plist > /tmp/new.txt
diff /tmp/old.txt /tmp/new.txt
```

Keys that are easy to lose or get subtly wrong in a hand-written file:
- `CFBundleInfoDictionaryVersion` (`6.0`)
- `UISupportedInterfaceOrientations~iphone` — note the `~iphone` suffix; the unsuffixed key behaves differently
- `UIApplicationSceneManifest` — the generated default is `UIApplicationSupportsMultipleScenes = true` with an empty `UISceneConfigurations`. Setting it to `false` is a real behaviour change on iPad (it disables multi-window under Stage Manager), so don't guess at it

## File-system-synchronized groups (Xcode 16+)

Modern projects use `PBXFileSystemSynchronizedRootGroup` — the target automatically includes whatever is in its folder. Convenient, and it has one sharp edge: **any loose file you drop in gets added to Copy Bundle Resources**, including files that must not be bundled.

Symptoms: `Multiple commands produce .../Info.plist`, or a `.storekit` test configuration shipping inside the released app.

The fix is a membership exception in `project.pbxproj`:

```
/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */
    ABC123... /* Exceptions for "YourApp" folder in "YourApp" target */ = {
        isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
        membershipExceptions = (
            Info.plist,
            YourApp.storekit,
        );
        target = DEF456... /* YourApp */;
    };
```

Paths are relative to the synchronized folder root. Add the exception *before* the first build that would otherwise fail.

## Per-configuration xcconfig

Environment-specific values — ad unit IDs, API endpoints, feature flags — belong in xcconfig files rather than in code or in a single plist. Debug gets test credentials, Release gets real ones, and no source file knows the difference:

```
Config/Debug.xcconfig      ADMOB_BANNER = ca-app-pub-3940256099942544/2934735716   # Google's sample unit
Config/Release.xcconfig    ADMOB_BANNER = ca-app-pub-<your-real-id>/<unit>
```

Referenced from Info.plist as `$(ADMOB_BANNER)`, and assigned to each configuration in the project's `baseConfigurationReference`. This is how you get a fully exercisable app before a single production credential exists — which matters, because the alternative is developers testing against live ad inventory.

## Privacy manifest

`PrivacyInfo.xcprivacy` at the app target root. Apple requires it, and it must agree with both the code and the App Store Connect privacy answers.

```xml
<key>NSPrivacyTracking</key><false/>
<key>NSPrivacyTrackingDomains</key><array/>
<key>NSPrivacyCollectedDataTypes</key><array>…</array>
<key>NSPrivacyAccessedAPITypes</key><array>…</array>
```

Required-reason APIs you're likely using without thinking about it:

| Category | Triggered by | Reason code |
|---|---|---|
| `…CategoryUserDefaults` | Any `UserDefaults` / `@AppStorage` | `CA92.1` (app's own data) |
| `…CategoryFileTimestamp` | `attributesOfItem`, `contentModificationDate` | `C617.1` (files in app container) |
| `…CategoryDiskSpace` | `volumeAvailableCapacity` | `E174.1` |
| `…CategorySystemBootTime` | `systemUptime`, `mach_absolute_time` | `35F9.1` |

Embedded SDKs ship their own manifests; yours covers your own code. The final privacy report is the merge of all of them.

## Orientation

iPhone can be portrait-only. **iPad cannot** — it must declare all four orientations or App Store validation rejects the build for iPad multitasking, and `UIRequiresFullScreen` no longer waives it:

```xml
<key>UISupportedInterfaceOrientations~iphone</key>
<array><string>UIInterfaceOrientationPortrait</string></array>
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```

This forces a real decision: either design iPad landscape properly, or drop to `TARGETED_DEVICE_FAMILY = 1` (iPhone only) and let iPad run it in compatibility mode. Shipping an iPad build whose landscape layout was never designed is the worse option, and it also means you don't need iPad screenshots.

**Ask this explicitly during intake — "is this app for iPhone only, or iPhone and iPad?" — don't infer it from a template or a previous project.** Whichever answer, it has to land identically in every one of these, and they drift independently because each is edited by a different tool:

| Where | What |
|---|---|
| The project generator's source file (`project.yml` for XcodeGen, `Project.swift` for Tuist) | `TARGETED_DEVICE_FAMILY` |
| The checked-in Xcode project | Same key — Xcode lets you flip this in target settings without anyone touching the generator source |
| `Info.plist` | The `~ipad` orientation array (all four, if iPad is in) |
| App Store submission docs / notes | Screenshot sizes required (iPad adds 13"/11" on top of the iPhone sizes) |

The generator source is the one most likely to be quietly wrong, because it's edited least often: someone adds iPad support by changing a setting in Xcode directly, the build works, nobody touches `project.yml` — until someone runs `xcodegen generate` months later and it silently regenerates the project back to iPhone-only. Treat a mismatch between the generator source and the checked-in project as a live bug, not a formatting difference — it means the *next* regeneration will ship something nobody decided.

## Export compliance

```
INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO
```
(or the plist key directly). Apps using only HTTPS are exempt. Without it, App Store Connect asks on every single upload.

## Launch screen

A storyboard (`UILaunchStoryboardName`) gives full layout control; the `UILaunchScreen` dictionary is simpler but limited to a background colour and one centred image.

The constraint that surprises people: **a launch screen renders before any app code runs.** So it cannot use fonts registered at runtime via `CTFontManagerRegisterFontsForURL`, and cannot reach any Swift colour definitions.

- Colours: define them in the asset catalog with appearance variants, and reference by name
- Custom-font wordmarks: either add the font to `UIAppFonts`, or render the wordmark to a vector PDF (outlined glyphs) and use it as an image — the PDF route can't fall back to Helvetica, which is its main advantage
- Light/dark: give the image asset both appearance variants rather than relying on template tinting, which is one fewer runtime behaviour in the launch path

## Signing

`DEVELOPMENT_TEAM` must be set on **Release**, not just Debug. Archiving fails otherwise, and it fails at the end of a long build, usually the first time anyone tries to ship.
