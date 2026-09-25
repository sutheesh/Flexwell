#!/usr/bin/env python3
"""Propose a dark-mode palette from a light-mode one, and check it actually reads.

Most designs arrive in one appearance. Inverting them produces the classic bad
dark mode: pure black grounds that smear on OLED, pure white text that halates,
and mid-tone accents that go muddy. This derives something defensible instead,
then measures it — so what gets proposed is checked rather than eyeballed.

    python3 derive-dark-palette.py \
        --bg '#F4F1EA' --surface '#FFFFFF' --text '#0E0E10' \
        --accent gold=#E4A93C --accent lime=#D6FB4E

Output is a proposal, not an answer. Show it to whoever owns the design before
building on it — this gets you a sane starting point, not a designed palette.
"""

import argparse, colorsys, sys

# ── colour maths ────────────────────────────────────────────────────────────

def hex_to_rgb(h):
    h = h.strip().lstrip('#')
    if len(h) == 3:
        h = ''.join(c * 2 for c in h)
    if len(h) != 6:
        raise ValueError(f"not a hex colour: #{h}")
    return tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4))

def rgb_to_hex(rgb):
    return '#' + ''.join(f'{max(0, min(255, round(c * 255))):02X}' for c in rgb)

def luminance(rgb):
    """WCAG relative luminance."""
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (f(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def contrast(a, b):
    la, lb = luminance(hex_to_rgb(a)), luminance(hex_to_rgb(b))
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

def with_lightness(hex_colour, target_l, sat_scale=1.0):
    """Keep the hue, scale saturation, move to a target lightness.

    Hue is preserved because a warm cream and a warm near-black belong to the
    same family — that's what makes a dark mode feel like the same product
    rather than a different app.
    """
    r, g, b = hex_to_rgb(hex_colour)
    h, _, s = colorsys.rgb_to_hls(r, g, b)
    return rgb_to_hex(colorsys.hls_to_rgb(h, target_l, min(1.0, s * sat_scale)))

# ── derivation ──────────────────────────────────────────────────────────────

def derive(bg, surface, text, accents):
    """Targets chosen to avoid the two failure modes of naive inversion:
    pure-black grounds and pure-white text."""
    out = {}

    # Ground sits above pure black. Saturation is pulled down hard — a dark
    # neutral that keeps full chroma reads as tinted rather than neutral.
    out['background'] = with_lightness(bg, 0.072, sat_scale=0.30)

    # In dark mode elevation still means lighter, so a card must sit above the
    # page — the same relationship as light mode, from the other end.
    out['surface'] = with_lightness(bg, 0.115, sat_scale=0.35)

    # Off-white rather than #FFFFFF: full white on a dark ground halates and is
    # tiring to read. Hue comes from the light-mode ink so warmth carries over.
    out['text'] = with_lightness(text, 0.94, sat_scale=0.55)

    # Secondary text is the same ink at reduced opacity rather than a separate
    # grey, so it stays consistent over any surface it lands on.
    out['muted'] = f"{out['text']} @ 58% opacity"
    out['hairline'] = f"{out['text']} @ 13% opacity"

    for name, val in accents.items():
        lum = luminance(hex_to_rgb(val))
        if lum >= 0.45:
            out[name] = (val, 'unchanged — already bright enough to hold on a dark ground')
        elif lum >= 0.20:
            r, g, b = hex_to_rgb(val)
            h, l, s = colorsys.rgb_to_hls(r, g, b)
            out[name] = (rgb_to_hex(colorsys.hls_to_rgb(h, min(0.97, l + 0.10), s * 0.92)),
                         'lightened ~10% — mid-tones lose punch against dark')
        else:
            r, g, b = hex_to_rgb(val)
            h, l, s = colorsys.rgb_to_hls(r, g, b)
            out[name] = (rgb_to_hex(colorsys.hls_to_rgb(h, min(0.97, l + 0.22), s * 0.85)),
                         'lightened ~22% — would be near-invisible otherwise')
    return out

# ── reporting ───────────────────────────────────────────────────────────────

def grade(ratio, large=False):
    need = 3.0 if large else 4.5
    if ratio >= 7.0:            return '✅ AAA'
    if ratio >= need:           return '✅ AA'
    if ratio >= need - 0.7:     return '⚠️  borderline'
    return '❌ fails'

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--bg', required=True, help='light-mode page background')
    ap.add_argument('--surface', help='light-mode card surface (defaults to white)')
    ap.add_argument('--text', required=True, help='light-mode primary text')
    ap.add_argument('--accent', action='append', default=[], metavar='NAME=#HEX')
    a = ap.parse_args()

    accents = {}
    for spec in a.accent:
        if '=' not in spec:
            sys.exit(f"--accent needs NAME=#HEX, got: {spec}")
        k, v = spec.split('=', 1)
        accents[k.strip()] = v.strip()

    surface = a.surface or '#FFFFFF'
    d = derive(a.bg, surface, a.text, accents)

    print('\n╭─ proposed dark palette ' + '─' * 40)
    print(f"│ {'role':<12} {'light':<10} →  {'dark':<24} note")
    print('│')
    for role, light in (('background', a.bg), ('surface', surface), ('text', a.text)):
        print(f"│ {role:<12} {light:<10} →  {d[role]:<24}")
    print(f"│ {'muted':<12} {'—':<10} →  {d['muted']:<24} derived from text")
    print(f"│ {'hairline':<12} {'—':<10} →  {d['hairline']:<24} derived from text")
    for name in accents:
        val, why = d[name]
        print(f"│ {name:<12} {accents[name]:<10} →  {val:<24} {why}")
    print('╰' + '─' * 63)

    print('\n╭─ contrast check ' + '─' * 46)
    pairs = [
        ('text on background',  d['text'], d['background'], False),
        ('text on surface',     d['text'], d['surface'],    False),
        ('muted on background', with_lightness(d['text'], 0.62), d['background'], False),
    ]
    for name in accents:
        val = d[name][0]
        # An accent used as a fill needs a label that reads on it; check both
        # candidate labels so the right one is obvious rather than guessed.
        pairs.append((f'dark text on {name} fill',  d['background'], val, True))
        pairs.append((f'light text on {name} fill', d['text'],       val, True))

    for label, fg, bg, large in pairs:
        r = contrast(fg, bg)
        print(f"│ {label:<28} {r:5.2f}:1  {grade(r, large)}")
    print('╰' + '─' * 63)

    # The lightened accents above suit accent-coloured *text* on the dark page.
    # For accent *fills* (buttons, tiles) there is a second option the checks
    # above don't cover: keep the light-mode value in both appearances with a
    # fixed label. It keeps the design's look (e.g. white on a brand colour) —
    # the lightened fill usually forces a dark label instead.
    if accents:
        print('\n╭─ accent fills: keep fixed, or flip? ' + '─' * 26)
        for name, light in accents.items():
            dark_val = d[name][0]
            white = contrast('#FFFFFF', light)
            ink = contrast(a.text, light)
            label, label_r = ('white', white) if white >= ink else ('dark ink', ink)
            vs_page = contrast(light, d['background'])
            as_text = contrast(dark_val, d['background'])
            fixed_ok = label_r >= 4.5 and vs_page >= 3.0
            print(f"│ {name}")
            print(f"│   keep {light} fixed · {label} label {label_r:5.2f}:1 {grade(label_r)}"
                  f" · fill vs dark page {vs_page:4.2f}:1 {grade(vs_page, large=True)}")
            print(f"│   accent text on dark page → use {dark_val} ({as_text:4.2f}:1 {grade(as_text)})")
            print(f"│   → {'fixed fill + ' + label + ' label works in both modes' if fixed_ok else 'flip the fill and use the passing label from the check above'}")
        print('╰' + '─' * 63)

    print("""
Next steps
  1. Show this to whoever owns the design before building on it. It is a
     defensible starting point, not a designed palette.
  2. Accents need two tokens: a fill and an ink. Where "fixed fill" works
     (last box), keep the fill and its label identical in both modes, and use
     the lightened value only for accent-coloured text. Otherwise flip the
     fill and take the label that passes — don't guess.
  3. Anything marked ❌ or ⚠️ needs a human decision: shift the accent, or
     restrict it to large text and non-text UI only.
  4. Record in DESIGN.md which tokens flip and which are fixed. That single
     distinction prevents most dark-mode bugs later.
""")

if __name__ == '__main__':
    main()
