# ADR 0002: Snapshot-based undo; retire move-replay

## Status

Accepted. Supersedes the "keep replay parity as the main regression safety harness" guidance in [ADR-0001](0001-retire-large-turn-engine-deepening-plans.md) (that ADR otherwise stands).

## Context

The game kept its state in three representations and spent most of `move_applicator.rb` (914 lines) keeping them consistent:

1. **Live state** — the AR `Game` (`board_contents`, players), mutated directly by `TurnEngine` as players act. The real game.
2. **Forward replay** — `GameReplayer` + `MoveApplicator::HashState` re-apply the `Move` log forward from `base_snapshot` and assert the result equals live state. **Called only from tests** (`game_replayer_test.rb`); it is not a runtime feature.
3. **Reverse undo** — `undo_last_move` + `MoveApplicator::LiveState` reverse the most recent moves to roll back. Powers the undo button.

`MoveApplicator.dispatch` routes each action to a same-named method on both backends, but `HashState#apply_build` applies a build forward while `LiveState#apply_build` reverses one — identical names, opposite semantics, selected by which backend is passed. Every action was therefore implemented up to three times (live mutation, forward replay, reverse undo), and every `Move` had to carry "before" context (`remaining_before`, `action_before`, `chosen_terrain_before`, `deck_after`, `phase_after`, …) so it could be replayed and reversed. This is event-sourcing scaffolding without the payoff: the `Move` log is not the source of truth, just a parallel record that must be continually reconciled. It is the residue of an event-sourcing direction that was demoted but never removed.

Replay's value is entirely derivative of using the `Move` log as a state mechanism. The only thing that reconstructs state from the log is `LiveState` undo; the property we actually care about — "does undo restore the right state?" — is now pinned **behaviourally** by the `test/scenarios/` net (undo round-trip mode). Replay-parity checks a lower-level *means* (is each `Move` individually faithful?), and it doesn't even check `bonus_scores` today (omitted from `capture_snapshot`), so tier-2 goal faithfulness already rests on the scenario net, not on replay.

ADR-0001 named replay parity as the main regression safety harness. That was written before the scenario test net existed. The net is a better harness — rules-based and refactor-surviving — so the premise has expired.

## Decision

Undo is implemented by **snapshot-restore**, not by reversing the move log:

- `capture_snapshot` is completed to cover all mutable state undo can reach (`board_contents`, deck/discard, `current_action`, per-player hand/supply/tiles/taken_from, plus the previously-omitted `bonus_scores`, `end_trigger_count`, `move_count`). `boards`/`goals`/`tasks` are immutable after start; `scores`/`state` only change at game completion, which is past `end_turn` (an irreversible boundary undo cannot cross).
- A snapshot is captured per request at `TurnEngine` construction (pre-click state) and attached to the deliberate `Move` recorded for that click via a new `moves.snapshot_before` column.
- `undo_last_move` finds the most recent reversible deliberate move, calls `Game#restore_snapshot!(move.snapshot_before)`, and deletes moves from that point forward. A click and all its consequences revert atomically from the one pre-click snapshot.

Retire move-replay entirely: delete `GameReplayer`, `Game#replayed_state`, `MoveApplicator` (whole file — both `HashState` and `LiveState`), `game_replayer_test.rb`, and the `games.base_snapshot` column. The `*_before` / `*_after` payload fields exist only to drive reverse/replay and are removed. `Move` keeps `deliberate` / `reversible` / `action` / `message` and becomes purely the activity feed and the undo spine.

## Consequences

- ~1,300 lines deleted; three state representations collapse to one (live state + a snapshot blob per undoable step). Undo correctness becomes "restore a blob" — eliminating the hand-written per-action reverse logic that produced three distinct `unapply!` bugs in the reverted May 2026 attempt.
- The undo snapshot stack is bounded to the current turn: `end_turn` is the irreversible boundary, so only snapshots since the last `end_turn` are ever reachable. Storage is trivial.
- `capture_snapshot` becomes the single canonical definition of "full restorable game state." A future mutable column must be added to it, or undo will silently fail to restore it — mitigate by building `capture_snapshot` as a near-complete column dump rather than a hand-picked list.
- The `test/scenarios/` net is the safety harness for this change; the undo round-trip tracers must stay green across the rewrite.
- This does not resurrect or reject the `Turn` / Sub-phase / Phase-consequence model from ADR-0001 — it removes a different, orthogonal piece of machinery.
