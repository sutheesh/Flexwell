#!/usr/bin/env bash
# Catch design drift before it reaches a screenshot.
#
#   bash design-check.sh [source-dir]
#
# Tiered deliberately. A check that reports three hundred findings on a working
# app gets ignored, and then it catches nothing at all. Tier 1 is the pattern
# that has actually shipped as a visible bug; the rest is context.

set -uo pipefail
SRC="${1:-.}"

# Colour definitions belong in the theme layer — that's the whole point of it.
# Excluded so the system's own literals don't drown out misuse elsewhere.
THEME_RE='(Theme/|DesignTokens|Color\+Hex|InkTheme|Palette\.swift)'

# Build output and dependency checkouts hold other people's Swift (Firebase,
# ads SDKs…); scanning them buries the app's own findings.
SKIP_DIRS=(--exclude-dir=Pods --exclude-dir=Carthage --exclude-dir=.build --exclude-dir=build --exclude-dir=DerivedData
           --exclude-dir=SourcePackages --exclude-dir=checkouts --exclude-dir=.git --exclude-dir=.claude)

scan() { grep -rnE "$1" "${SKIP_DIRS[@]}" --include="*.swift" "$SRC" 2>/dev/null \
         | grep -vE "$THEME_RE" \
         | grep -vE '^\S+:[0-9]+:[[:space:]]*(//|///|\*)' \
         | sed 's|^\./||'; }
count() { printf '%s' "$1" | grep -c . || true; }

T1=""; T2=""

# ── Tier 1 ──────────────────────────────────────────────────────────────────
# A literal *fill* is the one that ships as a visible bug: the surface stays
# white while the text on it correctly flips to light, and the content
# disappears. Opacity-modified whites are excluded — those are nearly always
# deliberate overlays on an always-dark card, and they read fine either way.
FILLS=$(scan '\.(background|fill)\((Color\.)?(white|black)\)|\.(background|fill)\(Color\.(white|black)\)')
RAW_BG=$(scan '\.(background|fill)\(Color\(hex:')

# A fixed near-black or near-white *behind* content, on a screen whose own
# background also flips, is the "invisible button" pattern.
T1=$(printf '%s\n%s\n' "$FILLS" "$RAW_BG" | grep -v '^[[:space:]]*$' || true)

# ── Tier 2 ──────────────────────────────────────────────────────────────────
HEX=$(scan 'Color\(hex:|Color\(red:|UIColor\(red:')
FONTS=$(scan '\.font\(\.system\(size:')
RADII=$(scan 'cornerRadius: [0-9]+')
FIXED_H=$(scan '\.frame\(height: [0-9]{3,}')
FG=$(scan '\.foregroundStyle\(\.?(Color\.)?white\)|\.foregroundColor\(\.white\)')

echo "════════ design drift check ════════"
echo

n1=$(count "$T1")
if [ "$n1" -gt 0 ]; then
  printf '🔴 LIKELY BUGS — %s\n' "$n1"
  printf 'A literal colour used as a background or fill. If the surface behind it\n'
  printf 'flips with the theme and this does not, it breaks in one appearance.\n\n'
  printf '%s\n' "$T1" | head -30
  [ "$n1" -gt 30 ] && printf '  … and %s more\n' "$((n1 - 30))"
  echo
else
  printf '🟢 No literal colours used as backgrounds or fills.\n\n'
fi

printf '🟡 WORTH A LOOK\n'
printf '  %-38s %s\n' "raw hex outside the theme layer"  "$(count "$HEX")"
printf '  %-38s %s\n' "hardcoded font sizes"             "$(count "$FONTS")"
printf '  %-38s %s\n' "magic-number corner radii"        "$(count "$RADII")"
printf '  %-38s %s\n' "fixed heights ≥100pt"             "$(count "$FIXED_H")"
printf '  %-38s %s\n' "white foregrounds"                "$(count "$FG")"
printf '\n  Re-run with a pattern to list any of these, e.g.\n'
printf "    grep -rn --exclude-dir=build '.font(.system(size:' --include='*.swift' %s\n\n" "$SRC"

cat <<'EOF'
────────────────────────────────────────
The question for each Tier 1 finding:

  Does this sit on a surface that changes with the theme,
  while the value itself does not?

  Yes → it breaks in one appearance. Use a role token.
  No  → the surface is deliberately fixed (an always-dark hero card, a
        branded tile). The literal is correct — leave a short comment
        saying so, or someone will "fix" it into a real bug later.

White *foregrounds* are usually fine: they sit on fixed dark cards. They're
counted above rather than listed for that reason.
EOF
