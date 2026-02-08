#!/usr/bin/env python3
"""Audit biome image references and asset spelling in SpaceWheat."""

import argparse
import json
from collections import defaultdict
from pathlib import Path
import difflib
import sys


def parse_args():
    parser = argparse.ArgumentParser(
        description="Verify each biome entry points to an existing image asset and flag mismatches."
    )
    parser.add_argument(
        "--biome-json",
        default="Core/Biomes/data/biomes_merged.json",
        help="Path to the merged biome data JSON file.",
    )
    parser.add_argument(
        "--assets-dir",
        default="Assets/Biomes",
        help="Directory that should contain the biome image files.",
    )
    parser.add_argument(
        "--min-match-score",
        type=float,
        default=0.55,
        help="Lower bound for fuzzy-match suggestions when an image name is missing.",
    )
    return parser.parse_args()


def normalize_image_name(image_path):
    if not image_path:
        return ""
    if image_path.startswith("res://"):
        image_path = image_path[6:]
    return Path(image_path).name


def collect_assets(asset_dir):
    assets = []
    for entry in Path(asset_dir).iterdir():
        if not entry.is_file():
            continue
        if entry.suffix.lower() != ".png":
            continue
        if ":" in entry.name or entry.name.endswith(".import"):
            continue
        assets.append(entry)
    return sorted(assets)


def load_biomes(biome_json):
    with open(biome_json, encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, list):
        raise ValueError("Biome JSON should be a list of entries.")
    return data


def build_asset_index(assets):
    by_name = {asset.name: asset for asset in assets}
    by_lower = defaultdict(list)
    for asset in assets:
        by_lower[asset.name.lower()].append(asset)
    return by_name, by_lower


def report(biomes, assets, args):
    by_name, by_lower = build_asset_index(assets)
    asset_names = sorted(by_name)
    referenced_files = defaultdict(list)
    missing_reports = []
    for entry in biomes:
        name = entry.get("name", "<unnamed>")
        image_path = entry.get("image_path", "")
        image_name = normalize_image_name(image_path)
        note_lines = []
        if not image_path:
            note_lines.append("no image_path assigned")
        else:
            if image_name in by_name:
                referenced_files[image_name].append(name)
            else:
                lower_matches = by_lower.get(image_name.lower())
                if lower_matches:
                    asset_name = lower_matches[0].name
                    note_lines.append(
                        f"case mismatch: builds reference {image_name} but actual file is {asset_name}"
                    )
                    referenced_files[asset_name].append(name)
                else:
                    suggestions = [
                        match for match in difflib.get_close_matches(
                            image_name, asset_names, n=3, cutoff=args.min_match_score
                        )
                    ]
                    if suggestions:
                        note_lines.append(
                            "file not found; best matches: " + ", ".join(suggestions)
                        )
                    else:
                        note_lines.append("file not found and no close match"
                                          if image_name else "image_path references empty name")
        if note_lines:
            missing_reports.append((name, image_path, image_name, note_lines))
    unreferenced = [name for name in asset_names if name not in referenced_files]

    if missing_reports:
        print("Biomes with missing or mismatched images:")
        for biome, path, image_name, notes in missing_reports:
            joined_notes = "; ".join(notes)
            print(f"- {biome}: {path or '<empty>'} -> {joined_notes}")
        print()
    else:
        print("All biome image references point to existing assets.")
        print()

    if unreferenced:
        print("Biomes are not using these biome art files:")
        for name in unreferenced:
            print(f"- {name}")
    else:
        print("Every asset under Assets/Biomes is referenced by at least one biome.")
    print()
    print("Summary: ")
    print(f"  total biomes checked: {len(biomes)}")
    print(f"  assets inspected: {len(asset_names)}")
    print(f"  missing/mismatched references: {len(missing_reports)}")
    print(f"  unused assets: {len(unreferenced)}")


def main():
    args = parse_args()
    biome_path = Path(args.biome_json)
    asset_dir = Path(args.assets_dir)
    if not biome_path.exists():
        print("biome data not found:", biome_path, file=sys.stderr)
        sys.exit(1)
    if not asset_dir.exists():
        print("asset directory not found:", asset_dir, file=sys.stderr)
        sys.exit(1)
    biomes = load_biomes(biome_path)
    assets = collect_assets(asset_dir)
    report(biomes, assets, args)


if __name__ == "__main__":
    main()
