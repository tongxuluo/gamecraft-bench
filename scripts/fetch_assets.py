"""Download Kenney asset packs declared in scripts/catalog.json into the
configured asset library directory. Idempotent: skips packs whose extracted
dir already contains files.

Usage:
    python scripts/fetch_assets.py                  # default dest = $GAMECRAFT_BENCH_ASSET_LIBRARY
                                                    # or <repo>/assets/library
    python scripts/fetch_assets.py --dest /some/path
    python scripts/fetch_assets.py --only platformer-pack-remastered
    python scripts/fetch_assets.py --category 2D
    python scripts/fetch_assets.py --jobs 8         # parallel downloads
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CATALOG_PATH = REPO_ROOT / "scripts" / "catalog.json"
DEFAULT_DEST = REPO_ROOT / "assets" / "library"
USER_AGENT = "gamecraft-bench-fetch/0.1"
TIMEOUT = 60


def default_dest() -> Path:
    env = os.environ.get("GAMECRAFT_BENCH_ASSET_LIBRARY")
    return Path(env) if env else DEFAULT_DEST


def download(url: str, dest: Path) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    tmp = dest.with_suffix(dest.suffix + ".part")
    tmp.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp, open(tmp, "wb") as out:
        shutil.copyfileobj(resp, out, length=1 << 20)
    tmp.rename(dest)


def fetch_one(pack: dict, dest_root: Path, *, force: bool) -> tuple[str, str]:
    """Returns (slug, status). Status in {downloaded, skipped, failed:<msg>}."""
    cat = pack["category"]
    slug = pack["slug"]
    pack_dir = dest_root / cat / slug
    if not force and pack_dir.is_dir() and any(pack_dir.iterdir()):
        return slug, "skipped"

    zip_url = pack["zip_url"]
    zip_path = dest_root / cat / f"{slug}.zip"
    try:
        if not zip_path.exists():
            download(zip_url, zip_path)
        if pack_dir.exists():
            shutil.rmtree(pack_dir)
        pack_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(zip_path) as zf:
            zf.extractall(pack_dir)
        zip_path.unlink()
        return slug, "downloaded"
    except Exception as exc:  # noqa: BLE001
        if zip_path.exists():
            zip_path.unlink()
        return slug, f"failed: {exc!r}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", type=Path, default=default_dest(),
                    help="Output dir. Default: $GAMECRAFT_BENCH_ASSET_LIBRARY or <repo>/assets/library")
    ap.add_argument("--catalog", type=Path, default=CATALOG_PATH)
    ap.add_argument("--only", action="append", default=[],
                    help="Restrict to specific slugs. Repeatable.")
    ap.add_argument("--category", action="append", default=[],
                    help="Restrict to category (e.g. 2D, Audio, Textures). Repeatable.")
    ap.add_argument("--jobs", type=int, default=4)
    ap.add_argument("--force", action="store_true",
                    help="Re-download even when pack dir already exists.")
    args = ap.parse_args()

    catalog = json.loads(args.catalog.read_text())
    if args.only:
        wanted = set(args.only)
        catalog = [p for p in catalog if p["slug"] in wanted]
    if args.category:
        cats = set(args.category)
        catalog = [p for p in catalog if p["category"] in cats]

    if not catalog:
        print("no packs match filters", file=sys.stderr)
        return 1

    args.dest.mkdir(parents=True, exist_ok=True)
    total_mb = sum(p["size_bytes"] for p in catalog) / 1024 / 1024
    print(f"fetching {len(catalog)} packs (~{total_mb:.0f} MB) into {args.dest}",
          file=sys.stderr)

    statuses: dict[str, int] = {"downloaded": 0, "skipped": 0, "failed": 0}
    failures: list[str] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futs = [pool.submit(fetch_one, p, args.dest, force=args.force) for p in catalog]
        for done, fut in enumerate(concurrent.futures.as_completed(futs), 1):
            slug, status = fut.result()
            kind = "failed" if status.startswith("failed") else status
            statuses[kind] += 1
            marker = "✓" if kind != "failed" else "✗"
            print(f"  [{done:3d}/{len(catalog)}] {marker} {slug} ({status})",
                  file=sys.stderr)
            if kind == "failed":
                failures.append(f"{slug}: {status}")

    print(f"\nresults: {statuses}", file=sys.stderr)
    if failures:
        print("failures:", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
