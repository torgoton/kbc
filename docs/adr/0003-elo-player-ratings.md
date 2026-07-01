# ADR 0003: Elo for player ratings

## Status

Accepted.

## Context

kbc had no way for players to gauge skill or self-select balanced opponents. Two goals drive this feature: incite players to finish games and try to win (a win must gain rating, a loss/resignation must cost it), and let players find opponents of similar skill by showing ratings where they choose a table.

The engine is already N-player-agnostic (scoring, turn order, and `Game#winners` all iterate `game_players`); the only hard 2-player assumption is UI glue. Final per-player point totals already exist in `games.scores`. There was no existing rating code.

## Decision

Plain **Elo**, not Glicko-2: Glicko-2 tracks a per-player rating deviation and volatility, which pays off when match frequency is uneven or opponents are unknown; kbc doesn't have that problem yet, and plain Elo's swings can be tuned with a provisional K-factor. Glicko-2 is the named upgrade path if matchmaking mismatches become a real complaint.

Outcome is **binary and unscaled** — a win is a win, a loss is a loss. No margin scoring: final score scales wildly by goal-set/available tiles, so margin-of-victory would be noise, not signal.

**Resignation counts as a normal loss**, no extra penalty. The incentive to finish a game comes from resigning locking in the loss rather than leaving the outcome ambiguous. Ties are a **draw (0.5 each)**, reusing the existing co-winner case.

**Ranking-based pairwise Elo**, not a single aggregate update: for each player, compute an Elo delta against every other player in the game using their relative rank (win/loss/tie), then sum. This handles N=2 today and N>2 later through one code path — no rewrite needed when more-than-2-player games ship. Resigned players are ranked below every non-resigned player (and tie among themselves at the bottom, though a game can only end with one player left unresigned, so that case cannot arise in practice) regardless of their board total — the point is to always rank a resignation as a loss.

**Storage:** `users.rating` holds the current rating; `game_players.rating_before`/`rating_after` snapshot the value at the moment each game was rated, giving history and delta display without a new table. Provisional game count (`User#rated_games_count`) is derived by counting `game_players` with `rating_after` present, rather than a counter column that needs to stay in sync.

**Update timing:** synchronous inside `Game#complete!`, inside the same transaction as saving scores, guarded so a game can only be rated once. Both natural completion and resignation route through `complete!`, so this is the one entry point.

**K-factor:** starts at 1500; **K=40** for a player's first 10 rated games (provisional, lets new ratings move quickly toward true skill), **K=20** after (stable). Tunable via one `Rating::CONFIG` constant. Ratings show a `?` suffix (e.g. `1500?`) while a player is provisional.

**No backfill.** Only games completed after ship are rated; ratings start fresh at 1500 for everyone.

## Consequences

- New `Rating` service (`app/services/rating.rb`) is the only place Elo math lives; `Game#complete!` calls it once, after scores are computed.
- Ratings are visible on the waiting-tables list (matchmaking), the end-game modal (delta), the in-game player card, and the nav. A leaderboard is deferred — the display need right now is "can I win this / did I gain," not ranking discovery.
- Abandonment (games that never finish) is out of scope; turn time-limits are the next feature and will define what "abandoned" means before those games can be rated.
- If N-player games ship, no rating-engine change is required — the pairwise ranking decomposition already generalizes.
