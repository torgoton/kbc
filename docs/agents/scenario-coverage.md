# Scenario Test Coverage Matrix

Tracks which rules, goals, tasks, and tiles have a `test/scenarios/` tracer
(the behavior-pinning test net — see `~/.claude/plans/i-want-to-improve-shimmering-muffin.md`
and the project's `project_test_net` memory). Update this when adding or
removing a scenario test.

Legend: ✅ covered · 🟡 partial (tile/class used as a generic exemplar, but its
own distinguishing behavior isn't exercised) · ⬜ not covered.

## Goals (`Scoring::GOAL_CLASSES`, `app/models/scoring/goals/`)

Tier-2 goals are scored via a `check_*_goal` callback in `TurnEngine` at build
time (accumulated in `game_player.bonus_scores`). Tier-1 goals are pure
`Scoring::Scorer` subclasses recomputed from the board at scoring time.

| Goal | Tier | Coverage | Test |
| --- | --- | --- | --- |
| ambassadors | 2 | ✅ | `goals/ambassadors_test.rb` |
| families | 2 | ✅ | `goals/families_test.rb` |
| shepherds | 2 | ✅ | `goals/shepherds_test.rb` |
| hermits | 1 | ✅ | `goals/hermits_test.rb` |
| castles | 1 | ✅ | `goals/castles_test.rb` |
| citizens | 1 | ✅ | `goals/citizens_test.rb` |
| discoverers | 1 | ✅ | `goals/discoverers_test.rb` |
| farmers | 1 | ✅ | `goals/farmers_test.rb` |
| fishermen | 1 | ✅ | `goals/fishermen_test.rb` |
| knights | 1 | ✅ | `goals/knights_test.rb` |
| merchants | 1 | ✅ | `goals/merchants_test.rb` |
| miners | 1 | ✅ | `goals/miners_test.rb` |
| workers | 1 | ✅ | `goals/workers_test.rb` |

## Tasks (`Scoring::TASK_CLASSES`, `app/models/scoring/tasks/`)

All Tier-1 (board-derived, no `TurnEngine` callback).

| Task | Coverage | Test |
| --- | --- | --- |
| advance | ✅ | `tasks/advance_test.rb` |
| compass_points | ✅ | `tasks/compass_points_test.rb` |
| fortress | ✅ | `tasks/fortress_test.rb` |
| home_country | ✅ | `tasks/home_country_test.rb` |
| place_of_refuge | ✅ | `tasks/place_of_refuge_test.rb` |
| road | ✅ | `tasks/road_test.rb` |

## Tiles (`app/models/tiles/`)

### Meeple / movement tiles

| Tile | Coverage | Test | Notes |
| --- | --- | --- | --- |
| WagonTile | ✅ | `tiles/meeple_movement_contract_test.rb` | relocate, pickup, forfeit, 3-step budget |
| LighthouseTile | ✅ | `tiles/meeple_movement_contract_test.rb` | same contract as wagon |
| Nomad::ResettlementTile | ✅ | `tiles/resettlement_movement_test.rb`, `rules/forfeit_test.rb`, `rules/undo_round_trip_test.rb` | stepped settlement move, forfeit-prefers-used, undo round trip |
| BarracksTile | ⬜ | — | places a warrior meeple |
| PaddockTile | ⬜ | — | 2-hex straight-line settlement jump (`STRAIGHT_LINES`) |
| BarnTile | ⬜ | — | moves a settlement |
| CaravanTile | ⬜ | — | moves a settlement, `selectable_settlements` |
| HarborTile | ⬜ | — | moves a settlement |

### Build-bonus tiles (`builds_settlement?`)

| Tile | Coverage | Test | Notes |
| --- | --- | --- | --- |
| FarmTile | 🟡 | `tiles/meeple_movement_contract_test.rb`, `rules/forfeit_test.rb` | only used as a generic forfeitable-tile exemplar; its extra-build effect is untested |
| OasisTile | 🟡 | `rules/tile_pickup_test.rb`, `rules/tile_usability_test.rb`, `tiles/meeple_movement_contract_test.rb` | pickup/usability mechanics covered; extra-build effect untested |
| ForestersLodgeTile | ⬜ | — | |
| FortTile | ⬜ | — | also `activatable?` (drawn-terrain constraint) |
| GardenTile | ⬜ | — | |
| MonasteryTile | ⬜ | — | |
| OracleTile | ⬜ | — | |
| TavernTile | ⬜ | — | also `activatable?`, `valid_destinations` |
| TowerTile | ⬜ | — | also `valid_destinations` |
| VillageTile | ⬜ | — | also `valid_destinations` |
| Nomad::DonationTile (+ 7 terrain variants: Canyon/Desert/Flower/Grass/Mountain/Timber/Water) | ⬜ | — | donate hand card for extra build |

### Other tiles

| Tile | Coverage | Test | Notes |
| --- | --- | --- | --- |
| Nomad::OutpostTile | 🟡 | `tiles/meeple_movement_contract_test.rb` | only used as the "Nomad tiles are never forfeited" exemplar; own `activatable?` untested |
| CityHallTile | ⬜ | — | `on_pickup`, `valid_destinations`, `activatable?` |
| CrossroadsTile | ⬜ | — | `activatable?` (Crossroads expansion) |
| QuarryTile | ⬜ | — | wall placement |
| Nomad::SwordTile | ⬜ | — | |
| Nomad::TreasureTile | ⬜ | — | pure scoring tile, no custom methods |
| CastleTile | ⬜ | — | location tile tied to the Castles goal |

## Rules / cross-cutting mechanics

| Mechanic | Coverage | Test |
| --- | --- | --- |
| Mandatory build (hand-terrain restriction, supply, count) | ✅ | `rules/mandatory_build_test.rb` |
| Legal builds (adjacency restriction) | ✅ | `rules/legal_builds_test.rb` |
| Tile pickup on build | ✅ | `rules/tile_pickup_test.rb` |
| Tile usability (held vs. spent-this-turn) | ✅ | `rules/tile_usability_test.rb` |
| Tile forfeit (prefers used copy) | ✅ | `rules/forfeit_test.rb` |
| Undo (single deliberate move) | ✅ | `rules/undo_test.rb` |
| Undo round trip (`assert_undo_round_trip`) | ✅ | `rules/undo_round_trip_test.rb` |
| Meeple movement contract (relocate/pickup/forfeit/budget) | ✅ | `tiles/meeple_movement_contract_test.rb` |
