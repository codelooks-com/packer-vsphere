#!/usr/bin/env python3
"""Detect new point releases for the Linux lines in ci/matrix.json.

Two discovery modes per line ("discover" object):
- sums-regex: the line's sums_url is version-stable (ubuntu major dirs);
  scan it for filenames matching `pattern`, pick the highest captured
  integer, and bump iso_url's basename in place.
- dir-listing: scrape `listing_url` HTML for `dir_pattern` directory names
  (point versions), pick the highest version tuple, and re-render iso_url
  and sums_url from `url_template`/`sums_template` ({ver} placeholder).

On a bump: rewrites ci/matrix.json (iso_url, sums_url) and the line's
ci/config var-file (iso_file, iso_content_library_item). Prints one
"BUMP <key>: <old> -> <new>" line per change; the workflow turns a dirty
tree into a PR. Exits non-zero only on errors, not on no-changes.
"""

import json
import pathlib
import re
import sys
import urllib.request

MATRIX = pathlib.Path("ci/matrix.json")


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "check-iso-updates"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read().decode(errors="replace")


def latest_sums_regex(entry: dict) -> tuple[str, str]:
    pattern = entry["discover"]["pattern"]
    body = fetch(entry["sums_url"])
    candidates = {}
    for match in re.finditer(pattern, body):
        candidates[int(match.group(1))] = match.group(0)
    if not candidates:
        raise RuntimeError(f"{entry['key']}: no filenames match {pattern!r}")
    newest = candidates[max(candidates)]
    base, _, _ = entry["iso_url"].rpartition("/")
    return f"{base}/{newest}", entry["sums_url"]


def latest_dir_listing(entry: dict) -> tuple[str, str]:
    disc = entry["discover"]
    body = fetch(disc["listing_url"])
    versions = set(re.findall(disc["dir_pattern"], body))
    if not versions:
        raise RuntimeError(f"{entry['key']}: no dirs match {disc['dir_pattern']!r}")
    newest = max(versions, key=lambda v: tuple(int(p) for p in v.split(".")))
    return (
        disc["url_template"].format(ver=newest),
        disc["sums_template"].format(ver=newest),
    )


def main() -> int:
    matrix = json.loads(MATRIX.read_text())
    changed = False
    for entry in matrix:
        if not entry.get("enabled") or "discover" not in entry:
            continue
        kind = entry["discover"]["type"]
        if kind == "sums-regex":
            new_url, new_sums = latest_sums_regex(entry)
        elif kind == "dir-listing":
            new_url, new_sums = latest_dir_listing(entry)
        else:
            raise RuntimeError(f"{entry['key']}: unknown discover type {kind!r}")
        old_file = entry["iso_url"].rsplit("/", 1)[1]
        new_file = new_url.rsplit("/", 1)[1]
        if new_file == old_file and new_url == entry["iso_url"]:
            print(f"OK   {entry['key']}: {old_file}")
            continue
        print(f"BUMP {entry['key']}: {old_file} -> {new_file}")
        cfg = pathlib.Path("ci/config") / entry["config"]
        text = cfg.read_text()
        old_item = old_file.removesuffix(".iso")
        new_item = new_file.removesuffix(".iso")
        if old_file not in text:
            raise RuntimeError(f"{cfg}: expected iso_file {old_file!r} not found")
        cfg.write_text(text.replace(old_file, new_file).replace(old_item, new_item))
        entry["iso_url"] = new_url
        entry["sums_url"] = new_sums
        changed = True
    if changed:
        MATRIX.write_text(json.dumps(matrix, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
