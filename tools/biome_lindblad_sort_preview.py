#!/usr/bin/env python3
"""Migrate Lindblad terms from factions to biomes.

Rule:
  - Lindblad terms belong to the biome that contains the SOURCE emoji.
  - With --write, updates biomes_merged.json directly.
  - Without --write, only writes preview outputs.

Outputs (always):
  - exports/biomes_lindblad_preview.json
  - exports/biome_lindblad_report.md

With --write:
  - Core/Biomes/data/biomes_merged.json (updated in place)
"""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from copy import deepcopy
from pathlib import Path
from typing import Dict, List, Tuple


ROOT = Path(__file__).resolve().parents[1]
# Default to merged files (the canonical game sources)
DEFAULT_BIOMES = ROOT / "Core" / "Biomes" / "data" / "biomes_merged.json"
DEFAULT_FACTIONS = ROOT / "Core" / "Factions" / "data" / "factions_merged.json"
DEFAULT_OUT_DIR = ROOT / "exports"

# Special biome name for orphan Lindblads (emojis not in any biome)
ORPHAN_BIOME = "_orphan_lindblads"


def _load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def _write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def _write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _merge_outgoing(comp: Dict, target: str, rate: float) -> None:
    l_out = comp.setdefault("lindblad_outgoing", {})
    l_out[target] = l_out.get(target, 0.0) + rate


def _merge_incoming(comp: Dict, source: str, rate: float) -> None:
    l_in = comp.setdefault("lindblad_incoming", {})
    l_in[source] = l_in.get(source, 0.0) + rate


def _merge_decay(comp: Dict, decay: Dict) -> Tuple[float, float]:
    """Merge decay by taking the higher rate. Returns (prev_rate, new_rate)."""
    rate = float(decay.get("rate", 0.0))
    target = decay.get("target", "🍂")
    existing = comp.get("decay", {})
    prev_rate = float(existing.get("rate", 0.0))
    if rate > prev_rate:
        comp["decay"] = {"rate": rate, "target": target}
        return prev_rate, rate
    return prev_rate, prev_rate


def _assign_biomes(
    emoji: str,
    emoji_to_biomes: Dict[str, List[str]],
    multi_mode: str,
) -> List[str]:
    biomes = emoji_to_biomes.get(emoji, [])
    if len(biomes) <= 1:
        return biomes
    if multi_mode == "first":
        return [biomes[0]]
    if multi_mode == "all":
        return list(biomes)
    return []


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--biomes", type=Path, default=DEFAULT_BIOMES)
    parser.add_argument("--factions", type=Path, default=DEFAULT_FACTIONS)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument(
        "--multi",
        choices=["skip", "first", "all"],
        default="all",
        help="How to handle emojis present in multiple biomes (default: all)",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Write directly to biomes_merged.json (instead of just preview)",
    )
    parser.add_argument(
        "--orphan",
        choices=["skip", "collect"],
        default="collect",
        help="How to handle orphan emojis: skip (ignore) or collect (store in _orphan section)",
    )
    args = parser.parse_args()

    print("=" * 60)
    print("LINDBLAD MIGRATION: Factions -> Biomes")
    print("=" * 60)
    print(f"Biomes: {args.biomes}")
    print(f"Factions: {args.factions}")
    print(f"Multi-biome mode: {args.multi}")
    print(f"Orphan mode: {args.orphan}")
    print(f"Write mode: {'ENABLED' if args.write else 'preview only'}")
    print()

    biomes = _load_json(args.biomes)
    factions = _load_json(args.factions)

    biome_map = {b["name"]: b for b in biomes}
    for biome in biomes:
        biome.setdefault("icon_components", {})

    # Create orphan collector if needed
    orphan_lindblads = {"outgoing": {}, "incoming": {}, "decay": {}}

    emoji_to_biomes: Dict[str, List[str]] = defaultdict(list)
    for biome in biomes:
        for emoji in biome.get("emojis", []):
            emoji_to_biomes[emoji].append(biome["name"])

    moved_counts = defaultdict(lambda: {"out": 0, "in": 0, "decay": 0})
    ambiguous = defaultdict(list)  # emoji -> biomes
    missing = defaultdict(list)  # emoji -> [kind]
    conflicts = []

    for faction in factions:
        faction_name = faction.get("name", "unknown")

        # Lindblad outgoing
        l_out = faction.get("lindblad_outgoing", {}) or {}
        for emoji, targets in l_out.items():
            assigned = _assign_biomes(emoji, emoji_to_biomes, args.multi)
            if not assigned:
                if emoji in emoji_to_biomes:
                    ambiguous[emoji] = emoji_to_biomes[emoji]
                else:
                    missing[emoji].append("outgoing")
                    # Collect orphan if enabled
                    if args.orphan == "collect":
                        if emoji not in orphan_lindblads["outgoing"]:
                            orphan_lindblads["outgoing"][emoji] = {}
                        for target, rate in targets.items():
                            orphan_lindblads["outgoing"][emoji][target] = (
                                orphan_lindblads["outgoing"][emoji].get(target, 0.0) + float(rate)
                            )
                continue
            for biome_name in assigned:
                comp = biome_map[biome_name]["icon_components"].setdefault(emoji, {})
                for target, rate in targets.items():
                    _merge_outgoing(comp, target, float(rate))
                    moved_counts[biome_name]["out"] += 1

        # Lindblad incoming
        l_in = faction.get("lindblad_incoming", {}) or {}
        for emoji, sources in l_in.items():
            assigned = _assign_biomes(emoji, emoji_to_biomes, args.multi)
            if not assigned:
                if emoji in emoji_to_biomes:
                    ambiguous[emoji] = emoji_to_biomes[emoji]
                else:
                    missing[emoji].append("incoming")
                    # Collect orphan if enabled
                    if args.orphan == "collect":
                        if emoji not in orphan_lindblads["incoming"]:
                            orphan_lindblads["incoming"][emoji] = {}
                        for source, rate in sources.items():
                            orphan_lindblads["incoming"][emoji][source] = (
                                orphan_lindblads["incoming"][emoji].get(source, 0.0) + float(rate)
                            )
                continue
            for biome_name in assigned:
                comp = biome_map[biome_name]["icon_components"].setdefault(emoji, {})
                for source, rate in sources.items():
                    _merge_incoming(comp, source, float(rate))
                    moved_counts[biome_name]["in"] += 1

        # Decay
        decay = faction.get("decay", {}) or {}
        for emoji, decay_spec in decay.items():
            assigned = _assign_biomes(emoji, emoji_to_biomes, args.multi)
            if not assigned:
                if emoji in emoji_to_biomes:
                    ambiguous[emoji] = emoji_to_biomes[emoji]
                else:
                    missing[emoji].append("decay")
                    # Collect orphan if enabled
                    if args.orphan == "collect":
                        rate = float(decay_spec.get("rate", 0.0))
                        target = decay_spec.get("target", "🍂")
                        existing = orphan_lindblads["decay"].get(emoji, {})
                        if rate > float(existing.get("rate", 0.0)):
                            orphan_lindblads["decay"][emoji] = {"rate": rate, "target": target}
                continue
            for biome_name in assigned:
                comp = biome_map[biome_name]["icon_components"].setdefault(emoji, {})
                prev_rate, new_rate = _merge_decay(comp, decay_spec)
                if new_rate > prev_rate:
                    moved_counts[biome_name]["decay"] += 1
                elif new_rate < prev_rate:
                    conflicts.append(
                        f"{biome_name}:{emoji} decay rate {prev_rate} kept over {new_rate}"
                    )

    # Add orphan section to biomes if any orphans collected
    orphan_count = (
        len(orphan_lindblads["outgoing"]) +
        len(orphan_lindblads["incoming"]) +
        len(orphan_lindblads["decay"])
    )
    if orphan_count > 0 and args.orphan == "collect":
        # Create orphan biome entry
        orphan_biome = {
            "name": ORPHAN_BIOME,
            "description": "Collected Lindblad terms for emojis not found in any biome",
            "emojis": [],
            "icon_components": {},
        }
        # Populate orphan icon_components
        for emoji, targets in orphan_lindblads["outgoing"].items():
            comp = orphan_biome["icon_components"].setdefault(emoji, {})
            comp["lindblad_outgoing"] = targets
            if emoji not in orphan_biome["emojis"]:
                orphan_biome["emojis"].append(emoji)
        for emoji, sources in orphan_lindblads["incoming"].items():
            comp = orphan_biome["icon_components"].setdefault(emoji, {})
            comp["lindblad_incoming"] = sources
            if emoji not in orphan_biome["emojis"]:
                orphan_biome["emojis"].append(emoji)
        for emoji, decay_spec in orphan_lindblads["decay"].items():
            comp = orphan_biome["icon_components"].setdefault(emoji, {})
            comp["decay"] = decay_spec
            if emoji not in orphan_biome["emojis"]:
                orphan_biome["emojis"].append(emoji)

        biomes.append(orphan_biome)
        print(f"Collected {orphan_count} orphan Lindblad terms into {ORPHAN_BIOME}")

    out_biomes = deepcopy(biomes)

    # Always write preview
    out_file = args.out_dir / "biomes_lindblad_preview.json"
    _write_json(out_file, out_biomes)
    print(f"Wrote preview: {out_file}")

    # Write to canonical file if --write enabled
    if args.write:
        canonical_path = ROOT / "Core" / "Biomes" / "data" / "biomes_merged.json"
        _write_json(canonical_path, out_biomes)
        print(f"Wrote canonical: {canonical_path}")

    # Report
    lines = []
    lines.append("# Biome Lindblad Migration Report")
    lines.append("")
    lines.append(f"Biomes source: `{args.biomes}`")
    lines.append(f"Factions source: `{args.factions}`")
    lines.append(f"Multi-biome mode: `{args.multi}`")
    lines.append(f"Orphan mode: `{args.orphan}`")
    lines.append(f"Write mode: `{'enabled' if args.write else 'preview only'}`")
    lines.append("")

    lines.append("## Moved counts by biome")
    for biome_name in sorted(moved_counts.keys()):
        c = moved_counts[biome_name]
        lines.append(
            f"- {biome_name}: outgoing {c['out']}, incoming {c['in']}, decay {c['decay']}"
        )
    if not moved_counts:
        lines.append("- (none)")

    lines.append("")
    lines.append("## Ambiguous emoji (assigned to multiple biomes)")
    if ambiguous:
        for emoji in sorted(ambiguous.keys()):
            biomes_list = ", ".join(ambiguous[emoji])
            lines.append(f"- {emoji}: {biomes_list}")
    else:
        lines.append("- (none)")

    lines.append("")
    lines.append("## Orphan emoji (not found in any biome)")
    if missing:
        for emoji in sorted(missing.keys()):
            kinds = ", ".join(sorted(set(missing[emoji])))
            status = "collected" if args.orphan == "collect" else "skipped"
            lines.append(f"- {emoji}: {kinds} ({status})")
        lines.append("")
        lines.append(f"Total orphan emojis: {len(missing)}")
        lines.append(f"Orphan handling: {args.orphan}")
    else:
        lines.append("- (none)")

    lines.append("")
    lines.append("## Conflicts")
    if conflicts:
        for item in conflicts:
            lines.append(f"- {item}")
    else:
        lines.append("- (none)")

    lines.append("")
    lines.append("## Summary")
    total_moved = sum(
        c["out"] + c["in"] + c["decay"]
        for c in moved_counts.values()
    )
    lines.append(f"- Total Lindblad terms migrated: {total_moved}")
    lines.append(f"- Biomes with Lindblad data: {len(moved_counts)}")
    lines.append(f"- Orphan terms collected: {orphan_count}")

    report_path = args.out_dir / "biome_lindblad_report.md"
    _write_text(report_path, "\n".join(lines) + "\n")
    print(f"Wrote report: {report_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
