"""Rebuild scripts/catalog.json from kenney.nl.

Walks Kenney's category listings (2D, Audio, Textures), then fetches each
pack page to extract the zip URL, file size, and tags. Output is a JSON
manifest of every pack the benchmark cares about.

Usage:
    python scripts/build_catalog.py
    python scripts/build_catalog.py --out scripts/catalog.json --jobs 8

Run this only when you want to refresh the manifest (e.g. Kenney published
new packs, or download URLs/hashes changed). Day to day users should just
read the checked-in catalog.json.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import re
import sys
import urllib.request
from pathlib import Path

CATEGORIES = ["2D", "Audio", "Textures"]
LIST_URL = "https://kenney.nl/assets/category:{cat}/page:{page}"
PACK_URL = "https://kenney.nl/assets/{slug}"
USER_AGENT = "gamecraft-bench-build-catalog/0.1"
TIMEOUT = 30

SLUG_RE = re.compile(r"href='https://kenney\.nl/assets/([a-z0-9-]+)'")
ZIP_RE = re.compile(r"href='(https://kenney\.nl/media/pages/assets/[^']+\.zip)'")
TAG_RE = re.compile(r"href='https://kenney\.nl/assets/tag:([^']+)'")
SERIES_RE = re.compile(r"href='https://kenney\.nl/assets/series:([^']+)'")
TITLE_RE = re.compile(r"<h1[^>]*>([^<]+)</h1>")


def http_get(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return resp.read().decode("utf-8", errors="replace")


def http_size(url: str) -> int:
    req = urllib.request.Request(url, method="HEAD", headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return int(resp.headers.get("Content-Length", "0"))


def list_category(cat: str) -> list[str]:
    """Walk page:1, page:2, ... until an empty page."""
    slugs: list[str] = []
    seen: set[str] = set()
    page = 1
    while True:
        try:
            html = http_get(LIST_URL.format(cat=cat, page=page))
        except Exception as exc:  # noqa: BLE001
            print(f"  page {page} fetch failed: {exc}", file=sys.stderr)
            break
        new = [s for s in SLUG_RE.findall(html) if s not in seen]
        if not new:
            break
        for s in new:
            seen.add(s)
            slugs.append(s)
        page += 1
    return slugs


def scrape_pack(slug: str, category: str) -> dict:
    out = {"slug": slug, "category": category}
    try:
        html = http_get(PACK_URL.format(slug=slug))
        zip_m = ZIP_RE.search(html)
        if not zip_m:
            out["error"] = "no zip url"
            return out
        zip_url = zip_m.group(1)
        title_m = TITLE_RE.search(html)
        out.update(
            title=title_m.group(1).strip() if title_m else slug,
            zip_url=zip_url,
            tags=sorted(set(TAG_RE.findall(html))),
            series=sorted(set(SERIES_RE.findall(html))),
            size_bytes=http_size(zip_url),
        )
    except Exception as exc:  # noqa: BLE001
        out["error"] = repr(exc)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).resolve().parent / "catalog.json",
    )
    ap.add_argument("--jobs", type=int, default=8)
    args = ap.parse_args()

    print("listing categories ...", file=sys.stderr)
    by_cat: dict[str, list[str]] = {}
    for cat in CATEGORIES:
        slugs = list_category(cat)
        print(f"  {cat}: {len(slugs)} packs", file=sys.stderr)
        by_cat[cat] = slugs

    # Dedupe by slug, prefer the first category that listed it (categories
    # ordered above by priority). 2D wins over Audio/Textures for the rare
    # case a pack appears in multiple listings.
    pack_category: dict[str, str] = {}
    for cat, slugs in by_cat.items():
        for s in slugs:
            pack_category.setdefault(s, cat)

    print(f"scraping {len(pack_category)} unique packs ...", file=sys.stderr)
    results: list[dict] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futs = {pool.submit(scrape_pack, s, c): s for s, c in pack_category.items()}
        for n, fut in enumerate(concurrent.futures.as_completed(futs), 1):
            results.append(fut.result())
            if n % 20 == 0 or n == len(futs):
                print(f"  {n}/{len(futs)}", file=sys.stderr)

    # Drop entries that errored before we had a chance to record details.
    bad = [r for r in results if "error" in r]
    good = [r for r in results if "error" not in r]
    good.sort(key=lambda r: (r["category"], r["slug"]))

    args.out.write_text(json.dumps(good, indent=2))
    print(f"\nwrote {args.out}: {len(good)} packs", file=sys.stderr)
    if bad:
        print(f"  {len(bad)} packs failed:", file=sys.stderr)
        for r in bad:
            print(f"   - {r['slug']}: {r['error']}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
