"""Scrape OpenGameArt for CC0/CC-BY 2D-art entries and produce a JSON manifest.

Mirrors scripts/build_catalog.py (Kenney) in spirit. Does NOT download
files; that's fetch_oga_assets.py's job.

Output schema (per entry):
    {
      "slug": "200-free-lorestrome-portraits",
      "title": "200 Free Lorestrome Portraits",
      "url": "https://opengameart.org/content/<slug>",
      "license": "CC0",
      "tags": ["portrait", "pixel"],
      "files": [
          {"url": "...zip", "name": "portraits.zip", "size_bytes": 1234567}
      ]
    }

Walks search result pages 1..MAX_PAGES, dedupes by slug, then concurrently
fetches each entry's detail page. Designed to be idempotent — pass
``--resume`` to merge into an existing catalog.

Usage:
    python scripts/build_catalog_oga.py
    python scripts/build_catalog_oga.py --max-pages 30 --jobs 8 --resume
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

USER_AGENT = "gamecraft-bench-oga-catalog/0.1"
TIMEOUT = 30
LISTING_URL = (
    "https://opengameart.org/art-search-advanced"
    "?keys="
    "&field_art_type_tid%5B%5D=9"               # 2D Art
    "&field_art_licenses_tid%5B%5D=4"           # CC0
    "&field_art_licenses_tid%5B%5D=17981"       # CC-BY 4.0
    "&field_art_licenses_tid%5B%5D=2"           # CC-BY 3.0
    "&sort_by=count&sort_order=DESC"
    "&page={page}"
)

SLUG_RE = re.compile(r'href="/content/([a-z0-9-]+)"')
FILE_RE = re.compile(
    r'"(https://opengameart\.org/sites/default/files/(?!css/|js/)[^"]+)"'
)
TITLE_RE = re.compile(r"<h1[^>]*>([^<]+)</h1>")
LICENSE_RE = re.compile(r"\b(CC0|CC-BY 4\.0|CC-BY 3\.0|CC-BY-SA|GPL [23]\.0|OGA-BY)\b")
TAG_RE = re.compile(r'/art-search-advanced\?[^"]*field_art_tags_tid_op[^"]*">([^<]+)</a')

# Files under these patterns are previews/thumbs and shouldn't be the
# primary asset.
SKIP_FILE_RE = re.compile(r"_preview|_thumb|preview-small|/styles/")


def http_get(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return resp.read().decode("utf-8", errors="replace")


def collect_slugs(max_pages: int, log) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for p in range(max_pages):
        try:
            html = http_get(LISTING_URL.format(page=p))
        except Exception as exc:
            log(f"  page {p}: fetch error {exc!r}")
            continue
        new = [s for s in SLUG_RE.findall(html) if s not in seen]
        if not new:
            log(f"  page {p}: empty, stopping")
            break
        for s in new:
            seen.add(s)
            out.append(s)
        log(f"  page {p}: +{len(new)} (total {len(out)})")
    return out


def scrape_entry(slug: str) -> dict:
    out: dict = {
        "slug": slug,
        "url": f"https://opengameart.org/content/{slug}",
    }
    try:
        html = http_get(out["url"])
    except Exception as exc:
        return {**out, "error": f"fetch: {exc!r}"}

    title_m = TITLE_RE.search(html)
    out["title"] = title_m.group(1).strip() if title_m else slug

    lic_m = LICENSE_RE.search(html)
    out["license"] = lic_m.group(1) if lic_m else "unknown"

    tags = sorted({urllib.parse.unquote(t).strip().lower() for t in TAG_RE.findall(html)})
    out["tags"] = tags

    # Candidate file URLs. Filter previews/thumbnails out. We don't HEAD
    # each URL to check size — that doubles the per-entry latency. The
    # downloader (fetch_oga_assets.py) is responsible for size sanity.
    files: list[dict] = []
    seen: set[str] = set()
    for url in FILE_RE.findall(html):
        if SKIP_FILE_RE.search(url):
            continue
        if url in seen:
            continue
        seen.add(url)
        files.append(
            {
                "url": url,
                "name": urllib.parse.unquote(url.rsplit("/", 1)[-1]),
            }
        )
    out["files"] = files
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path,
                    default=Path(__file__).resolve().parent / "catalog_oga.json")
    ap.add_argument("--max-pages", type=int, default=30,
                    help="Listing pages to walk; ~25 entries each.")
    ap.add_argument("--jobs", type=int, default=8)
    ap.add_argument("--resume", action="store_true",
                    help="Merge with an existing output file; skip already-scraped slugs.")
    args = ap.parse_args()

    log = lambda m: print(m, file=sys.stderr, flush=True)

    existing: dict[str, dict] = {}
    if args.resume and args.out.is_file():
        for entry in json.loads(args.out.read_text()):
            existing[entry["slug"]] = entry
        log(f"resuming with {len(existing)} previously-scraped entries")

    log(f"listing pages 0..{args.max_pages - 1} ...")
    slugs = collect_slugs(args.max_pages, log)
    log(f"got {len(slugs)} unique slugs")

    todo = [s for s in slugs if s not in existing]
    log(f"{len(todo)} new to scrape, {len(slugs) - len(todo)} cached")

    results: list[dict] = list(existing.values())
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futs = {pool.submit(scrape_entry, s): s for s in todo}
        done = 0
        t0 = time.time()
        for fut in concurrent.futures.as_completed(futs):
            results.append(fut.result())
            done += 1
            if done % 25 == 0 or done == len(todo):
                rate = done / max(0.001, time.time() - t0)
                log(f"  scraped {done}/{len(todo)} ({rate:.1f}/s)")

    # Drop entries with no usable files (preview-only or scrape error).
    # Dedupe by slug (in case the same slug shows up across pages or via
    # related-content links inside an entry's own page).
    by_slug: dict[str, dict] = {}
    for r in results:
        if not r.get("files"):
            continue
        by_slug[r["slug"]] = r
    keep = sorted(by_slug.values(), key=lambda r: r["slug"])
    drop = len(results) - len(keep)
    args.out.write_text(json.dumps(keep, indent=2))
    log(f"wrote {args.out}: {len(keep)} entries (dropped {drop})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
