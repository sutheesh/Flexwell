#!/usr/bin/env python3
"""Generates the recipe photos in docs/recipe-image-prompts.md with the DeepAI text2img API.

Each prompt is sent as-is, with its "Avoid: …" part split off into the negative prompt, and the image is saved
under the prompt's own file name (e.g. meal_23_tofu_thai_green_curry.jpg). Images that already exist are
skipped, so the script can be stopped and run again.

It uses DeepAI's API, not their website: their terms don't allow bots on the site, and the API is the supported
way to script it. Images generated with DeepAI are yours to use commercially (DeepAI terms of service).

Your key is read from the DEEPAI_API_KEY environment variable, or from the file ~/.deepai_key (one line, just
the key). Never commit it or paste it anywhere public.

    export DEEPAI_API_KEY=your-key      # this terminal only
    # or, once:  echo 'your-key' > ~/.deepai_key && chmod 600 ~/.deepai_key

Then, from the repo root:

    python3 tools/generate_recipe_images.py --only 23          # one test image
    python3 tools/generate_recipe_images.py --from 1 --to 10   # a small batch
    python3 tools/generate_recipe_images.py                    # all of them
    python3 tools/generate_recipe_images.py --dry-run          # show what would be sent, call nothing

Options: --model hd|standard|genius|super_genius (default hd), --preference photography|cinematic|… (genius
models only), --size 1024 (square, 128–1536 in steps of 32), --out folder (default generated/recipe-photos).
"""
import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://api.deepai.org/api/text2img"
ROOT = Path(__file__).resolve().parent.parent
PROMPTS = ROOT / "docs" / "recipe-image-prompts.md"


def read_prompts(path):
    """[(id, name, prompt, negative, file name)] from the prompt document."""
    text = path.read_text(encoding="utf-8")
    entries = []
    for block in re.split(r"^### ", text, flags=re.M)[1:]:
        head = re.match(r"(\d+)\. (.+)", block)
        body = re.search(r"```\n(.+?)\n```", block, flags=re.S)
        name = re.search(r"Save as: `([^`]+)`", block)
        if not (head and body and name):
            continue
        prompt, _, avoid = body.group(1).strip().partition(" Avoid: ")
        entries.append((int(head.group(1)), head.group(2).strip(), prompt.strip(), avoid.strip(), name.group(1)))
    return entries


def generate(key, prompt, negative, model, preference, size):
    fields = {"text": prompt, "negative_prompt": negative, "image_generator_version": model,
              "width": str(size), "height": str(size)}
    if preference and model in ("genius", "super_genius"):
        fields["genius_preference"] = preference
    request = urllib.request.Request(API, data=urllib.parse.urlencode(fields).encode(), headers={"api-key": key})
    with urllib.request.urlopen(request, timeout=180) as response:
        result = json.load(response)
    if "output_url" not in result:
        raise RuntimeError(f"no image in the response: {result}")
    return result["output_url"]


def download(url, path):
    with urllib.request.urlopen(url, timeout=180) as response:
        data = response.read()
    tmp = path.with_suffix(path.suffix + ".part")
    tmp.write_bytes(data)
    tmp.replace(path)  # only a complete file ever gets the real name


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", type=int, help="generate just this recipe number")
    ap.add_argument("--from", dest="first", type=int, default=1, help="first recipe number")
    ap.add_argument("--to", dest="last", type=int, default=10**6, help="last recipe number")
    ap.add_argument("--model", default="hd", choices=["standard", "hd", "genius", "super_genius"])
    ap.add_argument("--preference", default=None, help="genius models only: photography, cinematic, graphic, anime")
    ap.add_argument("--size", type=int, default=1024, help="square side in pixels, 128–1536, multiple of 32")
    ap.add_argument("--out", default=str(ROOT / "generated" / "recipe-photos"))
    ap.add_argument("--delay", type=float, default=2.0, help="seconds between requests")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not (128 <= args.size <= 1536 and args.size % 32 == 0):
        sys.exit("--size must be 128–1536 and a multiple of 32")
    key = os.environ.get("DEEPAI_API_KEY")
    key_file = Path.home() / ".deepai_key"
    if not key and key_file.exists():
        key = key_file.read_text().strip()
    if not key and not args.dry_run:
        sys.exit("No DeepAI key: export DEEPAI_API_KEY=your-key, or save it in ~/.deepai_key")

    entries = read_prompts(PROMPTS)
    todo = [e for e in entries if (e[0] == args.only if args.only else args.first <= e[0] <= args.last)]
    if not todo:
        sys.exit("No prompts match that selection.")
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    print(f"{len(todo)} prompt(s) → {out}  (model {args.model}, {args.size}×{args.size})")

    made = skipped = failed = 0
    for n, (rid, name, prompt, negative, filename) in enumerate(todo, 1):
        target = out / filename
        if target.exists():
            skipped += 1
            print(f"[{n}/{len(todo)}] #{rid} {name}: already there, skipped")
            continue
        if args.dry_run:
            print(f"[{n}/{len(todo)}] #{rid} {name} → {filename}\n  prompt: {prompt[:160]}…\n  negative: {negative[:100]}…")
            continue
        for attempt in range(1, 4):
            try:
                url = generate(key, prompt, negative, args.model, args.preference, args.size)
                download(url, target)
                made += 1
                print(f"[{n}/{len(todo)}] #{rid} {name}: saved {filename}")
                break
            except urllib.error.HTTPError as e:
                detail = e.read().decode(errors="replace")[:200]
                if e.code in (401, 403):
                    sys.exit(f"DeepAI refused the key ({e.code}): {detail}")
                if e.code in (402,):
                    sys.exit(f"Out of DeepAI credits ({e.code}): {detail}")
                wait = 10 * attempt
                print(f"  HTTP {e.code} on try {attempt}: {detail} — retrying in {wait}s")
                time.sleep(wait)
            except Exception as e:  # network hiccup, timeout, bad response
                wait = 10 * attempt
                print(f"  {e} on try {attempt} — retrying in {wait}s")
                time.sleep(wait)
        else:
            failed += 1
            print(f"[{n}/{len(todo)}] #{rid} {name}: FAILED after 3 tries")
        time.sleep(args.delay)

    print(f"\nDone: {made} made, {skipped} already there, {failed} failed.")
    if failed:
        print("Run the same command again to retry the failed ones.")


if __name__ == "__main__":
    main()
