#!/usr/bin/env python3
"""Preview Lindblad migration from factions to biomes (non-destructive).

Rule:
  - Lindblad terms belong to the biome that contains the SOURCE emoji.
  - This script only writes preview outputs; it never edits source files.

Outputs:
  - exports/biomes_lindblad_preview.json
  - exports/biome_lindblad_report.md
"""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from copy import deepcopy
from pathlib import Path
from typing import Dict, List, Tuple


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BIOMES = ROOT / "Core" / "Biomes" / "data" / "biomes.json"
DEFAULT_FACTIONS = ROOT / "Core" / "Factions" / "data" / "factions.json"
DEFAULT_OUT_DIR = ROOT / "exports"


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
        default="skip",
        help="How to handle emojis present in multiple biomes (default: skip)",
    )
    args = parser.parse_args()

    biomes = _load_json(args.biomes)
    factions = _load_json(args.factions)

    biome_map = {b["name"]: b for b in biomes}
    for biome in biomes:
        biome.setdefault("icon_components", {})

    emoji_to_biomes: Dict[str, List[str]] = defaultdict(list)
    for biome in biomes:
        for emoji in biome.get("emojis", []):
            emoji_to_biomes[emoji].append(biome["name"])

    moved_counts = defaultdict(lambda: {"out": 0, "in": 0, "decay": 0})
    ambiguous = defaultdict(list)  # emoji -> biomes
    missing = defaultdict(list)  # emoji -> [kind]
    conflicts = []

    for faction in factions:
        # Lindblad outgoing
        l_out = faction.get("lindblad_outgoing", {}) or {}
        for emoji, targets in l_out.items():
            assigned = _assign_biomes(emoji, emoji_to_biomes, args.multi)
            if not assigned:
                if emoji in emoji_to_biomes:
                    ambiguous[emoji] = emoji_to_biomes[emoji]
                else:
                    missing[emoji].append("outgoing")
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

    out_biomes = deepcopy(biomes)
    out_file = args.out_dir / "biomes_lindblad_preview.json"
    _write_json(out_file, out_biomes)

    # Report
    lines = []
    lines.append("# Biome Lindblad Preview Report")
    lines.append("")
    lines.append(f"Biomes source: `{args.biomes}`")
    lines.append(f"Factions source: `{args.factions}`")
    lines.append(f"Multi-biome mode: `{args.multi}`")
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
    lines.append("## Ambiguous emoji (present in multiple biomes)")
    if ambiguous:
        for emoji in sorted(ambiguous.keys()):
            biomes_list = ", ".join(ambiguous[emoji])
            lines.append(f"- {emoji}: {biomes_list}")
    else:
        lines.append("- (none)")

    lines.append("")
    lines.append("## Missing emoji (not found in any biome)")
    if missing:
        for emoji in sorted(missing.keys()):
            kinds = ", ".join(sorted(set(missing[emoji])))
            lines.append(f"- {emoji}: {kinds}")
    else:
        lines.append("- (none)")

    lines.append("")
    lines.append("## Conflicts")
    if conflicts:
        for item in conflicts:
            lines.append(f"- {item}")
    else:
        lines.append("- (none)")

    report_path = args.out_dir / "biome_lindblad_report.md"
    _write_text(report_path, "\n".join(lines) + "\n")

    print(f"Wrote: {out_file}")
    print(f"Wrote: {report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
