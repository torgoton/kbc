# ADR 0001: Retire Large Turn Engine Deepening Plans

## Status

Accepted

## Context

KBC's current turn implementation is centered on `TurnEngine`, `TurnPhase`, `Move`, `MoveApplicator`, and replay tests. `TurnEngine` carries a large amount of behavior: validation, phase transition, mutation, move logging, tile pickup, bonus scoring, undo payload construction, and data used by views.

Earlier planning documents under `docs/superpowers/plans/` proposed a broad new `Turn` stack with Sub-phases, Phase consequences, consequence persistence, undo, and later mandatory-build migration. Those plans were deleted because they were too pre-decided and too large to use as current guidance. They also risked misleading future agents into continuing a parallel architecture that has not been proven in the codebase.

The domain language in `CONTEXT.md` is still useful:

- A **Turn** owns turn-level state and transitions between Sub-phases.
- A **Sub-phase** owns one phase of activity inside a Turn.
- A **Phase consequence** records one effect of a player action.

The decision here is about implementation sequence, not about rejecting those concepts.

## Decision

Do not resurrect the deleted large turn-engine deepening plans as implementation instructions.

Future turn refactors should start with smaller, evidence-producing seams:

1. Extract canonical board query predicates before introducing a new turn stack.
2. Keep replay parity as the main regression safety harness.
3. Migrate one narrow user-visible turn path at a time.
4. Introduce Phase consequences only where they replace real duplicated mutation or undo/replay complexity.
5. Avoid maintaining a long-lived parallel turn architecture unless the first migrated path proves the interface is deep enough to keep.

The first recommended implementation move is to extract board query predicates from `TurnEngine`, tile classes, and view-support paths into a small, well-tested module or `BoardState` interface. Candidate predicates include mandatory buildability, adjacent buildable terrain cells, all buildable terrain cells, selectable settlements, and bounded terrain reachability for meeple movement.

## Consequences

Future agents should not treat the old `docs/superpowers/plans/2026-05-07-turn-engine-deepening-*` files as missing work to recreate.

Refactors should be incremental and parity-tested. A useful slice should be able to answer:

- Which existing behavior moved behind the new interface?
- Which callers got simpler?
- Which replay, undo, or controller tests prove the behavior stayed working?
- What performance work becomes possible because the interface now owns a repeated query or side effect?

If a future refactor introduces Phase consequences, they should be tied directly to replay or undo value. A consequence type should carry enough data to replay and reverse its effect, and tests should verify live state and replayed state still match.

## Notes

This ADR intentionally leaves room for a future `Turn` module. It rejects the prior large upfront migration plan, not the domain model.
