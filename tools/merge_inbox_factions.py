#!/usr/bin/env python3
"""Merge faction assets from llm_inbox into factions_merged.json.

This script imports new factions from inbox files and merges them into
the canonical factions_merged.json. Existing factions are updated if
the inbox version has newer/different data.

Usage:
    python tools/merge_inbox_factions.py [--dry-run]
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, List, Tuple


ROOT = Path(__file__).resolve().parents[1]
MERGED_PATH = ROOT / "Core" / "Factions" / "data" / "factions_merged.json"
INBOX_DIR = ROOT / "llm_inbox" / "assets_update_02"

# Files to merge (in order - later files override earlier)
INBOX_FILES = [
    "spacewheat_factions.json",
    "new_factions.json",
]


def load_json(path: Path) -> List[Dict]:
    """Load JSON file, return empty list if not found."""
    if not path.exists():
        print(f"  [SKIP] {path.name} not found")
        return []
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_json(path: Path, data: List[Dict]) -> None:
    """Save JSON with pretty formatting."""
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def merge_factions(
    existing: List[Dict],
    incoming: List[Dict],
    source_name: str
) -> Tuple[List[Dict], Dict[str, str]]:
    """Merge incoming factions into existing list.

    Returns:
        (merged_list, changes_dict) where changes_dict maps name -> action
    """
    # Build lookup by name
    by_name = {f["name"]: f for f in existing}
    changes = {}

    for faction in incoming:
        name = faction["name"]
        if name in by_name:
            # Update existing
            by_name[name] = faction
            changes[name] = f"updated from {source_name}"
        else:
            # Add new
            by_name[name] = faction
            changes[name] = f"added from {source_name}"

    # Rebuild list (sorted by name for consistency)
    merged = sorted(by_name.values(), key=lambda f: f["name"])
    return merged, changes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be changed without writing",
    )
    args = parser.parse_args()

    print("=" * 60)
    print("FACTION INBOX MERGE")
    print("=" * 60)

    # Load existing merged factions
    print(f"\nLoading {MERGED_PATH.name}...")
    merged = load_json(MERGED_PATH)
    print(f"  Found {len(merged)} existing factions")

    all_changes = {}

    # Process each inbox file
    for inbox_file in INBOX_FILES:
        inbox_path = INBOX_DIR / inbox_file
        print(f"\nProcessing {inbox_file}...")
        incoming = load_json(inbox_path)
        if not incoming:
            continue
        print(f"  Found {len(incoming)} factions")

        merged, changes = merge_factions(merged, incoming, inbox_file)
        all_changes.update(changes)

        for name, action in sorted(changes.items()):
            print(f"    {name}: {action}")

    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    added = sum(1 for a in all_changes.values() if "added" in a)
    updated = sum(1 for a in all_changes.values() if "updated" in a)
    print(f"  Added: {added}")
    print(f"  Updated: {updated}")
    print(f"  Final count: {len(merged)} factions")

    if args.dry_run:
        print("\n[DRY RUN] No files written")
        return 0

    # Write merged file
    print(f"\nWriting {MERGED_PATH}...")
    save_json(MERGED_PATH, merged)
    print("  Done!")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
