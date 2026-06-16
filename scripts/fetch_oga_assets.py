"""Download OpenGameArt entries declared in scripts/catalog_oga.json into
the configured OGA library directory. Idempotent: skips entries whose
extracted dir already contains files.

Layout per entry:
    <dest>/<slug>/
        LICENSE.txt        # license + tags + source URL
        <files...>         # raw downloaded files; archives are extracted

Usage:
    python scripts/fetch_oga_assets.py                  # default dest
    python scripts/fetch_oga_assets.py --dest /some/path
    python scripts/fetch_oga_assets.py --only some-slug
    python scripts/fetch_oga_assets.py --license CC0    # only CC0 entries
    python scripts/fetch_oga_assets.py --jobs 8
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CATALOG_PATH = REPO_ROOT / "scripts" / "catalog_oga.json"
DEFAULT_DEST = REPO_ROOT / "assets" / "library-oga"
USER_AGENT = "gamecraft-bench-oga-fetch/0.1"
TIMEOUT = 120


def default_dest() -> Path:
    env = os.environ.get("GAMECRAFT_BENCH_OGA_LIBRARY")
    return Path(env) if env else DEFAULT_DEST


def download(url: str, dest: Path) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    tmp = dest.with_suffix(dest.suffix + ".part")
    tmp.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp, open(tmp, "wb") as out:
        shutil.copyfileobj(resp, out, length=1 << 20)
    tmp.rename(dest)


def extract(archive: Path, into: Path) -> bool:
    """Best-effort extract. Returns True if the archive was extracted (and
    therefore the original can be removed)."""
    name = archive.name.lower()
    try:
        if name.endswith(".zip"):
            with zipfile.ZipFile(archive) as zf:
                zf.extractall(into)
            return True
        if name.endswith((".tar.gz", ".tgz", ".tar.bz2", ".tbz", ".tar.xz", ".txz", ".tar")):
            shutil.unpack_archive(str(archive), str(into))
            return True
        if name.endswith(".7z") and shutil.which("7z"):
            subprocess.run(
                ["7z", "x", "-y", f"-o{into}", str(archive)],
                check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            return True
        if name.endswith(".rar") and shutil.which("unrar"):
            subprocess.run(
                ["unrar", "x", "-y", str(archive), str(into) + "/"],
                check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            return True
    except Exception:
        return False
    return False


def write_license(entry: dict, into: Path) -> None:
    lines = [
        f"Title: {entry.get('title', entry['slug'])}",
        f"Source: {entry.get('url', '')}",
        f"License: {entry.get('license', 'unknown')}",
    ]
    tags = entry.get("tags") or []
    if tags:
        lines.append(f"Tags: {', '.join(tags)}")
    (into / "LICENSE.txt").write_text("\n".join(lines) + "\n")


def fetch_one(entry: dict, dest_root: Path, *, force: bool) -> tuple[str, str]:
    """Returns (slug, status). Status in {downloaded, skipped, failed:<msg>}."""
    slug = entry["slug"]
    pack_dir = dest_root / slug
    if not force and pack_dir.is_dir() and any(p.name != "LICENSE.txt" for p in pack_dir.iterdir()):
        return slug, "skipped"

    if pack_dir.exists():
        shutil.rmtree(pack_dir)
    pack_dir.mkdir(parents=True, exist_ok=True)
    write_license(entry, pack_dir)

    try:
        for f in entry["files"]:
            url = f["url"]
            local = pack_dir / f["name"]
            download(url, local)
            if extract(local, pack_dir):
                local.unlink()
        return slug, "downloaded"
    except Exception as exc:
        return slug, f"failed: {exc!r}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", type=Path, default=default_dest(),
                    help="Output dir. Default: $GAMECRAFT_BENCH_OGA_LIBRARY or <repo>/assets/library-oga")
    ap.add_argument("--catalog", type=Path, default=CATALOG_PATH)
    ap.add_argument("--only", action="append", default=[],
                    help="Restrict to specific slugs. Repeatable.")
    ap.add_argument("--license", action="append", default=[],
                    help="Restrict to license string (e.g. CC0). Repeatable.")
    ap.add_argument("--max-mb", type=float, default=None,
                    help="Skip entries whose total size exceeds this many MB.")
    ap.add_argument("--jobs", type=int, default=4)
    ap.add_argument("--force", action="store_true",
                    help="Re-download even when entry dir already exists.")
    args = ap.parse_args()

    catalog = json.loads(args.catalog.read_text())
    if args.only:
        wanted = set(args.only)
        catalog = [e for e in catalog if e["slug"] in wanted]
    if args.license:
        lics = set(args.license)
        catalog = [e for e in catalog if e.get("license") in lics]
    if args.max_mb is not None:
        cutoff = args.max_mb * 1024 * 1024
        catalog = [
            e for e in catalog
            if sum(f.get("size_bytes", 0) for f in e["files"]) <= cutoff
        ]

    if not catalog:
        print("no entries match filters", file=sys.stderr)
        return 1

    args.dest.mkdir(parents=True, exist_ok=True)
    total_mb = sum(sum(f.get("size_bytes", 0) for f in e["files"]) for e in catalog) / 1024 / 1024
    sized = total_mb > 0
    note = f"~{total_mb:.0f} MB" if sized else "size unknown until download"
    print(f"fetching {len(catalog)} entries ({note}) into {args.dest}",
          file=sys.stderr)

    statuses: dict[str, int] = {"downloaded": 0, "skipped": 0, "failed": 0}
    failures: list[str] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futs = [pool.submit(fetch_one, e, args.dest, force=args.force) for e in catalog]
        for done, fut in enumerate(concurrent.futures.as_completed(futs), 1):
            slug, status = fut.result()
            kind = "failed" if status.startswith("failed") else status
            statuses[kind] += 1
            marker = "ok" if kind != "failed" else "!!"
            print(f"  [{done:4d}/{len(catalog)}] {marker} {slug} ({status})",
                  file=sys.stderr)
            if kind == "failed":
                failures.append(f"{slug}: {status}")

    print(f"\nresults: {statuses}", file=sys.stderr)
    if failures:
        print("failures:", file=sys.stderr)
        for f in failures[:30]:
            print(f"  - {f}", file=sys.stderr)
        if len(failures) > 30:
            print(f"  ... +{len(failures) - 30} more", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
