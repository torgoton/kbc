# Kingdom Builder (kbc)

A browser-based implementation of the [Kingdom Builder](https://new.queen-games.com/kingdom-builder/) board game designed by Donald X. Vaccarino and published by Queen Games. Built for players who already know the game and want to play online without a physical copy.

**Live:** [kbc.chrisschumann.dev](https://kbc.chrisschumann.dev) — accounts are required to play. If you'd like to try it, click the "Request an account" link or reach out directly to request one.

- run the whole stack in development mode with `make up` (or `docker compose up --build`)

---

## What it is

Kingdom Builder is an area control strategy game where players build across a modular board, scoring points based on a randomly-drawn combination of three objective cards each game. The board is assembled from a random selection of four map boards, so no two games have the same layout.

This implementation covers the full base game, the first expansion (Nomads), and the second expansion (Crossroads). It is not a tutorial and does not explain the rules. It is meant for people who have played the physical game and want a faithful digital version.

Each player plays in their own browser. Games can be played asynchronously; state is persisted at all times. Current support is for 2 players, with up to 5 planned.

---

## Stack

- **Ruby on Rails 8:** server-side game logic, routing, persistence
- **Hotwire (Turbo):** real-time board updates between players without a separate WebSocket layer or frontend framework
- **Plain JavaScript:** no framework; JS is used only where the DOM requires it
- **Hand-written CSS:** ~600 lines from scratch; no utility framework
- **PostgreSQL:** game state persistence

Dependencies are intentionally minimal. There is no npm build step and no asset pipeline beyond what Rails 8 ships with.

---

## Implementation notes

### Game logic

Kingdom Builder has non-trivial placement rules: each turn, a player must place all three of their settlements on the terrain type shown on their drawn card, subject to adjacency constraints. Location powers (triggered by settling adjacent to special tiles) add further branching. All of this logic lives in the Rails model layer and is covered by unit tests.

Test coverage is thorough by design. The rule system is complex enough that manual verification doesn't scale; the tests exist to make refactoring safe.

### Real-time updates

Turbo Streams push board state changes to both players after each turn. This keeps the client thin: no polling, no client-side game state, no synchronization logic. The board the server knows about is the board both players see.

### CSS

The board rendering is done entirely in CSS and HTML, no canvas. Space-adjacent placement, terrain coloring, settlement display, and responsive layout are all handled in the hand-written stylesheet.

---

## Running locally

**Please let me know if this section needs corrections!**

Requires Ruby and PostgreSQL. No Node or npm needed.

With Docker, run the containerized stack with `make up` (equivalent to `docker compose up --build`). For a native setup, set your database credentials in `config/database.yml`.

```bash
git clone https://github.com/torgoton/kbc.git
cd kbc
make up
```

In the app, request at least two accounts, then from a Rails console set the approved column in the users table to true.

### Container notes

`docker compose` runs the app in `RAILS_ENV=development` against the `kbc_development` database. The Rails server listens on port `3000` inside the container; override the host port with `KBC_HOST_PORT` (default `3000`). Postgres is published to the host on `KBC_DB_PORT` (default `5432`).

Start, stop, and tear down the stack:

```bash
make up
make stop      # pause containers
make down      # stop and remove containers (database data is preserved)
```

The `app` directory is mounted into the container, so code changes sync immediately while Rails runs in development mode. The container runs as root, so files it creates in the mounted source tree (e.g. `tmp/cache`, `log/`) will be root-owned on the host; run `docker run --rm -v "$PWD":/work alpine chown -R "$(id -u):$(id -g)" /work` if that blocks cleanup.

Reset the database (`make reset` will prompt before deleting the database volume):

```bash
make reset
```

Connect to Postgres from inside the container:

```bash
docker compose exec db psql -U postgres -d kbc_development
```

Or from the host via the published port (use your configured `KBC_DB_PORT`):

```bash
psql -h localhost -p ${KBC_DB_PORT:-5432} -U postgres -d kbc_development
```

---

## Status

Playable and complete for the base game and first two expansions (Nomads and Crossroads). The live site requires accounts; there is no guest access at this time. The game is designed for players who know Kingdom Builder — there is no in-app rules reference or tutorial.

Planned: support for up to 5 players and a guest/demo mode.
