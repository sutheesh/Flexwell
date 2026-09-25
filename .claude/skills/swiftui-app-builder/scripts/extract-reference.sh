#!/usr/bin/env bash
# Inventory an existing iOS project into a reference document.
#
# Run this BEFORE deleting anything. Its output is what lets a rebuilt app keep
# the identity of the old one — bundle ID, product IDs, signing, permissions,
# Firebase binding — none of which can be recovered once the sources are gone.
#
#   bash extract-reference.sh [project-dir] > PROJECT_REFERENCE.md
#
# Write the output somewhere the rebuild won't delete, or commit it first.

set -uo pipefail
cd "${1:-.}" || exit 1

# Build output, dependency checkouts and tooling folders contain Info.plists,
# Package.resolved files and Swift sources that aren't the app's. Every search
# below skips them.
PRUNE_RE='/(Pods|Carthage|\.build|build|DerivedData|SourcePackages|checkouts|\.git|\.claude|node_modules)/'
ffind() { find . "$@" 2>/dev/null | grep -vE "$PRUNE_RE"; }
SKIP_DIRS=(--exclude-dir=Pods --exclude-dir=Carthage --exclude-dir=.build --exclude-dir=build --exclude-dir=DerivedData
           --exclude-dir=SourcePackages --exclude-dir=checkouts --exclude-dir=.git --exclude-dir=.claude --exclude-dir=node_modules)
# grep's own directory exclusion — a path filter can't work on -h output, which has no paths.
fgrep_src() { grep -r "${SKIP_DIRS[@]}" "$@" . 2>/dev/null; }

PBX=$(ffind -path "*.xcodeproj/project.pbxproj" | grep -v "/Pods.xcodeproj/" | head -1)
SETTINGS=$(mktemp)
trap 'rm -f "$SETTINGS"' EXIT

# Resolve build settings the way Xcode does for the *app target's Release
# configuration*: project xcconfig < project settings < target xcconfig <
# target settings. Reading the first match in project.pbxproj (the old
# approach) returns the project-level value, which is often not what ships.
if [ -n "$PBX" ]; then
python3 - "$PBX" > "$SETTINGS" <<'PY'
import json, os, re, subprocess, sys
pbx = sys.argv[1]
try:
    data = json.loads(subprocess.run(["plutil", "-convert", "json", "-o", "-", pbx],
                                     capture_output=True, check=True).stdout)
except Exception as e:
    print(f"__ERROR\tcould not parse {pbx}: {e}")
    sys.exit()
objs = data["objects"]
root = objs[data["rootObject"]]
project_dir = os.path.dirname(os.path.dirname(os.path.abspath(pbx)))

def configs(list_id):
    return [objs[c] for c in objs.get(list_id, {}).get("buildConfigurations", [])]

def pick(cfgs, name="Release"):
    return next((c for c in cfgs if c.get("name") == name), cfgs[0] if cfgs else {})

def xcconfig(cfg):
    ref = cfg.get("baseConfigurationReference")
    if not ref or ref not in objs:
        return {}
    rel = objs[ref].get("path", "")
    path = os.path.join(project_dir, rel)
    if not os.path.exists(path):  # group-relative path: find by name
        for dp, _, fs in os.walk(project_dir):
            if os.path.basename(rel) in fs:
                path = os.path.join(dp, os.path.basename(rel))
                break
    out = {}
    try:
        for line in open(path, encoding="utf-8", errors="replace"):
            line = line.split("//")[0].strip()
            m = re.match(r"^([A-Za-z0-9_]+)\s*=\s*(.*)$", line)  # skips [sdk=…] conditionals
            if m:
                out[m.group(1)] = m.group(2)
    except OSError:
        pass
    return out

def is_app(t):
    return t.get("isa") == "PBXNativeTarget" and t.get("productType", "").startswith("com.apple.product-type.application")

apps = [objs[t] for t in root.get("targets", []) if is_app(objs[t])]
project_cfg = pick(configs(root.get("buildConfigurationList")))
settings = {}
settings.update(xcconfig(project_cfg))
settings.update(project_cfg.get("buildSettings", {}))
if apps:
    target = apps[0]
    target_cfg = pick(configs(target.get("buildConfigurationList")), project_cfg.get("name", "Release"))
    settings.update(xcconfig(target_cfg))
    settings.update(target_cfg.get("buildSettings", {}))
    settings["__TARGET"] = target.get("name", "")
    settings["__CONFIG"] = target_cfg.get("name", "")
    settings["__APP_TARGETS"] = ", ".join(t.get("name", "") for t in apps)
    settings["__SCRIPT_PHASES"] = ", ".join(
        objs[p].get("name", "Run Script") for p in target.get("buildPhases", [])
        if objs.get(p, {}).get("isa") == "PBXShellScriptBuildPhase")
settings["__OBJECT_VERSION"] = data.get("objectVersion", "")
settings["__SYNCED_GROUPS"] = "yes" if any(o.get("isa") == "PBXFileSystemSynchronizedRootGroup" for o in objs.values()) else ""
settings["__EXCEPTIONS"] = "yes" if any("membershipExceptions" in o for o in objs.values()) else ""
for k, v in settings.items():
    if isinstance(v, list):
        v = " ".join(v)
    print(f"{k}\t{str(v).replace(chr(10), ' ')}")
PY
fi

setting() {
  local v
  v=$(awk -F'\t' -v k="$1" '$1==k { sub(/^[^\t]*\t/, ""); print; exit }' "$SETTINGS")
  # Resolve the common self-references so the output shows real values.
  v=${v//\$(TARGET_NAME)/$(awk -F'\t' '$1=="__TARGET" {print $2; exit}' "$SETTINGS")}
  v=${v//\$(SRCROOT)\//}; v=${v//\$\{SRCROOT\}\//}; v=${v//\$(PROJECT_DIR)\//}
  printf '%s' "$v"
}
section() { printf '\n## %s\n\n' "$1"; }
note()    { printf '_%s_\n\n' "$1"; }

printf '# Project Reference\n\n'
printf '_Generated %s from `%s`._\n' "$(date '+%Y-%m-%d %H:%M')" "$(pwd)"
printf '_Everything below must survive a rebuild. Values marked **PERMANENT** can never change on a shipped app._\n'
if [ -z "$PBX" ]; then
  printf '\n**No .xcodeproj found** (Swift package or workspace-only project?). Build settings below are empty.\n'
elif grep -q '^__ERROR' "$SETTINGS"; then
  printf '\n**Could not read %s:** %s\n' "$PBX" "$(setting __ERROR)"
fi

# ── Identity ────────────────────────────────────────────────────────────────
section "Identity — PERMANENT"
TARGET=$(setting __TARGET)
note "Resolved for app target \`${TARGET:-?}\`, configuration \`$(setting __CONFIG)\` (target settings override project settings)."
[ -n "$(setting __APP_TARGETS)" ] && [ "$(setting __APP_TARGETS)" != "$TARGET" ] && \
  printf '**More than one app target:** %s — reported the first; check the others by hand.\n\n' "$(setting __APP_TARGETS)"
FAMILY=$(setting TARGETED_DEVICE_FAMILY)
case "$FAMILY" in
  1) FAMILY_TXT="1 (iPhone only)" ;;
  2) FAMILY_TXT="2 (iPad only)" ;;
  1,2) FAMILY_TXT="1,2 (iPhone and iPad)" ;;
  *) FAMILY_TXT="$FAMILY" ;;
esac
printf '| Key | Value |\n|---|---|\n'
printf '| Bundle identifier | `%s` |\n' "$(setting PRODUCT_BUNDLE_IDENTIFIER)"
printf '| Development team | `%s` |\n'  "$(setting DEVELOPMENT_TEAM)"
printf '| Product name | `%s` |\n'      "$(setting PRODUCT_NAME)"
printf '| Marketing version | `%s` |\n' "$(setting MARKETING_VERSION)"
printf '| Build number | `%s` |\n'      "$(setting CURRENT_PROJECT_VERSION)"
printf '| Deployment target | `%s` |\n' "$(setting IPHONEOS_DEPLOYMENT_TARGET)"
printf '| Device family | `%s` |\n'     "$FAMILY_TXT"
printf '\nAn update must keep supporting every device family the live version supports.\n'
printf '\n**Ask the user for these — they are not in the project:**\n'
printf -- '- App Store ID (the numeric `id…` in the App Store URL — grep for `apps.apple.com` / `itunes.apple.com` too)\n'
printf -- '- Has this app shipped? (decides whether persisted data can change)\n'
printf -- '- Apple Developer account / team owner\n'
STORE_URL=$(fgrep_src -ohE '(apps|itunes)\.apple\.com/[^"]*id[0-9]+' --include="*.swift" --include="*.m" --include="*.plist" | sort -u | head -3)
[ -n "$STORE_URL" ] && printf '\nFound in code: %s\n' "$(echo "$STORE_URL" | sed 's/^/`/;s/$/`/' | paste -sd ' ' -)"

# ── Info.plist ──────────────────────────────────────────────────────────────
section "Info.plist"
PLIST=$(setting INFOPLIST_FILE)
if [ -n "$PLIST" ] && [ -f "$PLIST" ]; then
  printf 'Source: `%s` (from INFOPLIST_FILE — a real file, carry it forward)\n\n```xml\n' "$PLIST"
  cat "$PLIST"
  printf '```\n'
elif [ "$(setting GENERATE_INFOPLIST_FILE)" = "YES" ] && [ -n "$PBX" ]; then
  note "Generated from build settings (GENERATE_INFOPLIST_FILE). Consider migrating to a real file — see references/project-scaffold.md."
  printf '```\n'; grep "INFOPLIST_KEY_" "$SETTINGS" | tr '\t' '=' | sort -u; printf '```\n'
else
  PLIST=$(ffind -name "Info.plist" -not -path "*/Frameworks/*" -not -path "*.xcframework/*" -not -path "*Tests*" | head -1)
  [ -n "$PLIST" ] && { printf 'Source: `%s` (found by search — confirm it is the app target'"'"'s)\n\n```xml\n' "$PLIST"; cat "$PLIST"; printf '```\n'; } \
                  || note "No Info.plist found."
fi

# ── Permissions ─────────────────────────────────────────────────────────────
section "Permissions requested"
note "Each one must still be justified by a real feature in the rebuild — an unused permission string is an App Store rejection."
PERMS=$({ [ -n "$PLIST" ] && [ -f "$PLIST" ] && grep -o 'NS[A-Za-z]*UsageDescription' "$PLIST"
          grep -o 'NS[A-Za-z]*UsageDescription' "$SETTINGS"; } 2>/dev/null | sort -u)
[ -n "$PERMS" ] && echo "$PERMS" | sed 's/^/- /' || note "None."

# ── Entitlements ────────────────────────────────────────────────────────────
section "Entitlements"
ENT=$(setting CODE_SIGN_ENTITLEMENTS)
[ -n "$ENT" ] && [ -f "$ENT" ] || ENT=$(ffind -name "*.entitlements" | grep -v Tests | head -1)
if [ -n "$ENT" ] && [ -f "$ENT" ]; then printf '`%s`\n\n```xml\n' "$ENT"; cat "$ENT"; printf '```\n'
else note "None found."; fi

# ── Privacy manifest ────────────────────────────────────────────────────────
section "Privacy manifest"
PRIV=$(ffind -name "PrivacyInfo.xcprivacy" -not -path "*.xcframework/*" -not -path "*.bundle/*" | head -1)
if [ -n "$PRIV" ]; then printf '`%s`\n\n```xml\n' "$PRIV"; cat "$PRIV"; printf '```\n'
else note "None — Apple requires one. See references/app-review.md."; fi

# ── Monetisation ────────────────────────────────────────────────────────────
section "Monetisation — product IDs are PERMANENT"
printf '**Likely StoreKit product identifiers** (string literals matching common product words — verify each; they must match App Store Connect exactly):\n\n'
PIDS=$(fgrep_src -hoE '"[a-zA-Z0-9]+(\.[a-zA-Z0-9]+){2,}"' --include="*.swift" --include="*.m" \
  | grep -iE 'premium|subscription|monthly|yearly|annual|weekly|lifetime|pro\b|plus\b|unlock|coins|gems' \
  | grep -vE '\.(fill|circle|square|badge|slash|arrow|up|down|left|right)"?$' | sort -u | head -20)
[ -n "$PIDS" ] && echo "$PIDS" | sed 's/^/- `/;s/$/`/' || printf -- '- none found\n'
printf '\n**StoreKit test configuration:**\n'
SK=$(ffind -name "*.storekit" | head -5)
[ -n "$SK" ] && echo "$SK" | sed 's/^/- `/;s/$/`/' || printf -- '- none\n'
printf '\n**AdMob** (app IDs contain `~`, ad units `/`; `ca-app-pub-3940256099942544` is Google'"'"'s sample publisher):\n'
ADS=$(fgrep_src -hoE 'ca-app-pub-[0-9]+[~/][0-9]+' --include="*.xcconfig" --include="*.plist" --include="*.swift" --include="*.m" | sort -u | head -15)
[ -n "$ADS" ] && echo "$ADS" | sed 's/^/- `/;s/$/`/' || printf -- '- none\n'
if [ -n "$PLIST" ] && [ -f "$PLIST" ] && grep -q SKAdNetworkItems "$PLIST"; then
  printf -- '- SKAdNetworkItems present (%s entries) — carry the list forward\n' "$(grep -c skadnetwork "$PLIST")"
fi

# ── Third-party services ────────────────────────────────────────────────────
section "Third-party services"
GS=$(ffind -name "GoogleService-Info.plist" | head -1)
if [ -n "$GS" ]; then
  printf '**Firebase** — `%s`. Binds the app to a Firebase project; copy the file itself, do not regenerate it blindly.\n\n' "$GS"
  printf '| Key | Value |\n|---|---|\n'
  for k in BUNDLE_ID PROJECT_ID GOOGLE_APP_ID; do
    v=$(/usr/libexec/PlistBuddy -c "Print :$k" "$GS" 2>/dev/null) && printf '| %s | `%s` |\n' "$k" "$v"
  done
  RC=$(ffind -iname "*RemoteConfig*.plist" | head -1)
  [ -n "$RC" ] && printf '\n**Remote Config defaults** `%s` — keys: %s\n' "$RC" \
    "$(/usr/libexec/PlistBuddy -c Print "$RC" 2>/dev/null | grep -E '^\s+[A-Za-z_]+ =' | sed 's/ =.*//;s/^ *//' | paste -sd ',' - | sed 's/,/, /g')"
else note "No GoogleService-Info.plist found."; fi
[ -f Podfile ] && { printf '\n**CocoaPods** (`Podfile`):\n```\n'; grep -E "^\s*pod " Podfile; printf '```\n'; }

# ── Dependencies ────────────────────────────────────────────────────────────
section "Swift Package dependencies"
# The app's own lockfile lives in the project/workspace, not in build output or
# a dependency's checkout.
RESOLVED=$(ffind -path "*.xcworkspace/xcshareddata/swiftpm/Package.resolved" | head -1)
[ -z "$RESOLVED" ] && [ -f Package.resolved ] && RESOLVED=./Package.resolved
if [ -n "$RESOLVED" ]; then
  printf 'From `%s`\n\n| Package | Version |\n|---|---|\n' "$RESOLVED"
  python3 - "$RESOLVED" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    pins = d.get("pins") or d.get("object", {}).get("pins", [])  # v2/v3 or v1 format
    for p in pins:
        name = p.get("identity") or p.get("package", "?")
        state = p.get("state", {})
        print(f"| {name} | {state.get('version') or state.get('branch') or (state.get('revision') or '')[:8]} |")
except Exception as e:
    print(f"| (unreadable: {e}) | |")
PY
else note "None."; fi

# ── Build settings worth keeping ────────────────────────────────────────────
section "Build settings that were deliberate"
note "These are usually the result of debugging something. Don't drop them without knowing why they were added."
if [ -n "$PBX" ]; then
  for k in OTHER_LDFLAGS OTHER_SWIFT_FLAGS SWIFT_VERSION SWIFT_DEFAULT_ACTOR_ISOLATION ENABLE_USER_SCRIPT_SANDBOXING \
           CODE_SIGN_ENTITLEMENTS INFOPLIST_FILE GENERATE_INFOPLIST_FILE SWIFT_ACTIVE_COMPILATION_CONDITIONS; do
    v=$(setting "$k"); [ -n "$v" ] && printf -- '- `%s` = `%s`\n' "$k" "$v"
  done
  PHASES=$(setting __SCRIPT_PHASES)
  [ -n "$PHASES" ] && printf -- '- Run-script build phases: %s — check what each does before discarding (`[CP] …` are CocoaPods'"'"' own)\n' "$PHASES"
  [ "$(setting __EXCEPTIONS)" = "yes" ] && printf -- '- File-system-synchronized group has membership exceptions (see references/project-scaffold.md)\n'
fi

# ── Persisted data ──────────────────────────────────────────────────────────
section "Persisted data — BREAKING if changed on a shipped app"
note "Whatever the old app stored is what existing users have on their phones. Changing it without a migration loses their data."
MODELS=$(fgrep_src -lE '@Model\b' --include="*.swift")
if [ -n "$MODELS" ]; then
  printf '**SwiftData `@Model` types:**\n\n'
  # Only the files that actually contain @Model — never an empty list, which
  # would make grep -r fall back to scanning every file.
  echo "$MODELS" | while read -r f; do
    grep -hE -A1 '@Model\b' "$f" | grep -oE '(final )?class [A-Za-z0-9_]+' | sed "s|^|- \`|;s|$|\` in \`$f\`|"
  done
  printf '\n'
else
  printf -- '- No SwiftData `@Model` types.\n'
fi
CD=$(ffind -name "*.xcdatamodeld" | head -3)
if [ -n "$CD" ]; then
  printf -- '- **Core Data models:** %s\n' "$(echo "$CD" | paste -sd ' ' -)"
  for m in $CD; do
    ENTS=$(grep -ohE '<entity name="[^"]+"' "$m"/*/contents 2>/dev/null | sed 's/<entity name="//;s/"//' | sort -u | paste -sd ',' - | sed 's/,/, /g')
    [ -n "$ENTS" ] && printf '  - entities: %s\n' "$ENTS"
  done
else
  printf -- '- No Core Data models.\n'
fi
# Only lines that touch UserDefaults — `forKey:` alone also matches animation and KVC keys.
KEYS=$(fgrep_src -hE 'UserDefaults|NSUserDefaults|@AppStorage|defaults\.' --include="*.swift" --include="*.m" \
  | grep -oE '(forKey|AppStorage)[:(] *"[^"]+"' | sed -E 's/.*"([^"]+)"/\1/' | sort -u | head -40)
if [ -n "$KEYS" ]; then
  printf -- '- **UserDefaults / @AppStorage keys** (string literals — keys built with interpolation show their fixed part):\n'
  echo "$KEYS" | sed 's/^/  - `/;s/$/`/'
else
  printf -- '- No UserDefaults keys found as string literals.\n'
fi
KC=$(fgrep_src -lE 'SecItemAdd|kSecClass|KeychainAccess|Keychain\(' --include="*.swift" --include="*.m" | head -3)
[ -n "$KC" ] && printf -- '- **Keychain** used in: %s\n' "$(echo "$KC" | paste -sd ' ' -)"

# ── Assets and content ──────────────────────────────────────────────────────
section "Assets and bundled content"
printf '**Asset catalogs:**\n'
ffind -name "*.xcassets" | while read -r a; do
  printf -- '- `%s` — %s image sets, %s colour sets\n' "$a" \
    "$(find "$a" -name "*.imageset" 2>/dev/null | wc -l | tr -d ' ')" \
    "$(find "$a" -name "*.colorset" 2>/dev/null | wc -l | tr -d ' ')"
done
printf '\n**Fonts:**\n'
FONTS=$(ffind \( -name "*.ttf" -o -name "*.otf" \) | head -10)
[ -n "$FONTS" ] && echo "$FONTS" | sed 's/^/- `/;s/$/`/' || printf -- '- none\n'
printf '\n**Other content files** (seed data, legal pages — often hand-written and worth keeping; confirm each is in the app target):\n'
OTHER=$(ffind \( -name "*.html" -o -name "*.json" -o -name "*.csv" -o -name "*.txt" \) \
  -not -path "*.xcassets/*" -not -name "Package.resolved" -not -path "*.xcodeproj/*" -not -path "*.xcworkspace/*" | head -20)
[ -n "$OTHER" ] && echo "$OTHER" | sed 's/^/- `/;s/$/`/' || printf -- '- none\n'

# ── Git ─────────────────────────────────────────────────────────────────────
section "Git state"
if git rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  printf -- '- Branch: `%s`\n' "${BRANCH:-detached HEAD at $(git describe --tags --always 2>/dev/null)}"
  printf -- '- Uncommitted changes: `%s` file(s)\n' "$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  printf -- '- Last commit: `%s`\n' "$(git log -1 --oneline 2>/dev/null)"
  UP=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
  if [ -n "$UP" ]; then
    printf -- '- Upstream: `%s` (%s commit(s) not pushed)\n' "$UP" "$(git rev-list --count "$UP"..HEAD 2>/dev/null)"
  else
    printf -- '- No upstream for this branch — its commits may exist only on this machine (remotes: %s)\n' "$(git remote | paste -sd ',' - | sed 's/^$/none/')"
  fi
  printf '\n**Before wiping:** commit and tag the current state so the old app stays recoverable.\n'
else
  printf '**Not a git repository.** There is no undo. Take a copy of the whole folder before deleting anything.\n'
fi
