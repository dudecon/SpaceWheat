# Codex-Min Rig Plan

Goal: Provide a turn-by-turn rig that lets lightweight Codex-mini instances interact with the live Farm/QuantumInstrument simulation, cycle through quests/vocab, and log each "turn" for inspection.

## Core pieces
1. **Headless runner** - reuse `godot --headless --path . --script Tests/qii_vocab_sequence.gd` pattern but wrap it so a Codex agent can dispatch actions sequentially. This runner should expose a simple API (e.g. JSON via stdout or file) describing each turn's action, results, and resource state.
2. **FarmInstrument helper** - already created, exposes overlay toggles, resource queries, quest info. This becomes the back-end control surface for the rig (accept quests, open quest board, read resources, trigger overlays, etc.).
3. **Tokenized script tooling** - `lib_qii.sh` and token logs can serve as the rig's turn history; extend them to record outcomes (success/failure) and turn IDs.
4. **Codex-mini harness** - a wrapper script or Python CLI that launches Godot tests, reads the token log or JSON, and feeds the next turn via a simple instruction set (e.g., `turn 3: G3.Q for plot (0,0)`), then waits for completion before continuing.
5. **Documentation/README** - explain how to spin up the rig, what scripts exist, how to interpret token logs, and how to add new turns.

## Phases
- **Phase 1 (Orchestration layer).** Write a small orchestrator (bash/Python) that runs Godot headless, injects actions via FarmInstrument tokens, and collects results per turn.
- **Phase 2 (Feedback instrumentation).** Expand Godot probes to emit turn IDs plus per-action outcome metadata (resource delta, quest acceptance status) so the rig can close the loop.
- **Phase 3 (Docs & usage).** Provide README showing Codex-mini usage, available tools (scripts, FarmInstrument API), and how to extend sequences.

## Risks/gaps
- Need to decide how Codex-minis specify actions: via text file, token log, or RPC? The rig should standardize a compact command set (e.g., `QII +vocab → Village`), ideally reusing the `VOCAB_QII.tsv` vocabulary.
- Some actions currently fail (missing resources, terminals). The rig should include setup turns (seed resources, bind terminals) before measurement actions.
