#!/usr/bin/env python3
"""
Check biome image_path references against the filesystem.

- Scans Core/Biomes/data/*.json by default.
- Reports missing image files.
- Optionally replaces missing paths with "" to trigger fallback imagery.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any, Dict, List, Tuple


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATA_DIR = PROJECT_ROOT / "Core" / "Biomes" / "data"
ASSETS_BIOMES_DIR = PROJECT_ROOT / "Assets" / "Biomes"
FALLBACK_SENTINEL = ""  # Empty string triggers fallback in BiomeBackground


def _resolve_res_path(path: str) -> Path:
    if path.startswith("res://"):
        return PROJECT_ROOT / path.replace("res://", "", 1)
    return PROJECT_ROOT / path


def _load_json(path: Path) -> List[Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise ValueError(f"{path} root is not a list")
    return data


def _write_json(path: Path, data: List[Dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def _normalize_name(value: str) -> str:
    return "".join(ch for ch in value.lower() if ch.isalnum())


def _build_asset_map() -> Dict[str, str]:
    mapping: Dict[str, str] = {}
    if not ASSETS_BIOMES_DIR.exists():
        return mapping
    for img in ASSETS_BIOMES_DIR.glob("*.png"):
        stem = img.stem
        mapping[_normalize_name(stem)] = str(img.relative_to(PROJECT_ROOT))
    return mapping


def _fill_from_assets(data: List[Dict[str, Any]], asset_map: Dict[str, str]) -> int:
    filled = 0
    # Explicit alias map for known mismatches
    alias_map = {
        "bioticflux": "quantumfields",
    }
    for biome in data:
        if not isinstance(biome, dict):
            continue
        if biome.get("image_path"):
            continue
        name = biome.get("name", "")
        if not isinstance(name, str) or name == "":
            continue
        norm = _normalize_name(name)
        if norm in alias_map:
            norm = alias_map[norm]
        if norm in asset_map:
            biome["image_path"] = f"res://{asset_map[norm]}"
            filled += 1
    return filled


def _scan_file(path: Path, apply_fixes: bool, fill_missing: bool) -> Tuple[int, int, int]:
    data = _load_json(path)
    missing = 0
    total = 0
    filled = 0

    for biome in data:
        if not isinstance(biome, dict):
            continue
        name = biome.get("name", "<unknown>")
        image_path = biome.get("image_path", "")
        if not isinstance(image_path, str) or image_path == "":
            continue
        total += 1
        resolved = _resolve_res_path(image_path)
        if not resolved.exists():
            missing += 1
            print(f"[MISSING] {path.name}: {name} -> {image_path}")
            if apply_fixes:
                biome["image_path"] = FALLBACK_SENTINEL

    if fill_missing:
        asset_map = _build_asset_map()
        filled = _fill_from_assets(data, asset_map)

    if apply_fixes and missing > 0:
        _write_json(path, data)
    elif fill_missing and filled > 0:
        _write_json(path, data)

    return total, missing, filled


def main() -> int:
    parser = argparse.ArgumentParser(description="Check biome image paths in JSON files.")
    parser.add_argument(
        "paths",
        nargs="*",
        help="JSON files to scan (defaults to Core/Biomes/data/*.json)",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Rewrite JSON files, replacing missing image_path with empty string.",
    )
    parser.add_argument(
        "--fill-missing",
        action="store_true",
        help="Fill empty image_path fields by matching Assets/Biomes filenames.",
    )

    args = parser.parse_args()

    if args.paths:
        json_paths = [Path(p) for p in args.paths]
    else:
        json_paths = sorted(DEFAULT_DATA_DIR.glob("*.json"))

    if not json_paths:
        print("No JSON files found to scan.")
        return 1

    total_checked = 0
    total_missing = 0
    total_filled = 0
    for json_path in json_paths:
        if not json_path.exists():
            print(f"[SKIP] File not found: {json_path}")
            continue
        checked, missing, filled = _scan_file(json_path, args.apply, args.fill_missing)
        total_checked += checked
        total_missing += missing
        total_filled += filled

    print(f"\nChecked {total_checked} image references. Missing: {total_missing}. Filled: {total_filled}.")
    if args.apply and total_missing > 0:
        print("Missing paths replaced with empty string (fallback will be used).")
    if args.fill_missing and total_filled > 0:
        print("Empty image_path fields filled from Assets/Biomes filenames.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
