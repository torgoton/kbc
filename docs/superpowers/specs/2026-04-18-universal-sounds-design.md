# Universal Sound Effects — Design Spec

**Date:** 2026-04-18
**Branch:** `fix-sound-targeting`

## Goal

Every player and observer of a game hears the same sound effects, driven by a single server source of truth. Zero special cases. Minimize total sound-related code size.

## Motivation

Current implementation plays some sounds locally on click (active player only), some via stream-state diffs (mostly all clients, one personal case), and preloads sounds through a per-game helper that inspects board composition. This has accumulated roughly:

- 44 lines of helper code (`app/helpers/games_helper.rb`) + 56 lines of tests
- 100+ lines of JS split between `sound.js` and `gameboard.js` covering click delegation, state-snapshot diffing, and playback queuing
- Several data attributes on partials that exist only to feed the client diff logic

All of this replaces with: a single `Move#after_create_commit` hook, one explicit `broadcast_sound("undo")` call, and one custom Turbo Stream action on the client.

## Architecture

```
User click
  → Controller
  → TurnEngine
  → Move.create  ──(after_create_commit)──►  Turbo Stream "play_sound" to game channel
  → broadcast_game_update                    └─► every client: SoundManager.play(key)
```

Undo is the only special path: it deletes Move records instead of creating them, so the controller broadcasts the `undo` sound explicitly.

Every persisted game event is already a `Move` record. Treating Move as the canonical event log aligns with the planned event-sourcing migration (see project memory).

## Components

### Server

#### `Move` model

Add an action → sound-key mapping, an `after_create_commit` hook, and a helper to derive the key:

```ruby
class Move < ApplicationRecord
  SOUNDS = {
    "build"             => "build",
    "select_settlement" => "select_settlement",
    "move_settlement"   => "move",
    "pick_up_tile"      => "tile_pickup",
    "forfeit_tile"      => "tile_forfeit",
    "end_turn"          => "end_turn",
    "end_game"          => "game_end",
    "remove_settlement" => "removed",
    "activate_outpost"  => "outpost",
    "place_wall"        => "wall"
  }.freeze

  belongs_to :game
  belongs_to :game_player

  after_create_commit :broadcast_sound

  private

  def broadcast_sound
    key = sound_key
    return unless key
    Turbo::StreamsChannel.broadcast_render_to(
      "game_#{game_id}",
      inline: %(<turbo-stream action="play_sound" key="#{key}"></turbo-stream>)
    )
  end

  def sound_key
    return SOUNDS[action] if SOUNDS.key?(action)
    payload["klass"].delete_suffix("Tile").downcase if action == "select_action" && payload&.dig("klass")
  end
end
```

Unmapped actions (`score_goal`, `select_action` with no klass, anything new) return nil — no broadcast, no error.

#### `Game` model

Add one public method for non-Move-driven sounds (currently only `undo`):

```ruby
def broadcast_sound(key)
  Turbo::StreamsChannel.broadcast_render_to(
    "game_#{id}",
    inline: %(<turbo-stream action="play_sound" key="#{key}"></turbo-stream>)
  )
end
```

#### `GamesController#undo_move`

Add one line before `@game.broadcast_game_update`:

```ruby
@game.broadcast_sound("undo")
```

#### `GamesHelper`

Replace all existing helpers with:

```ruby
module GamesHelper
  def sound_paths
    Dir[Rails.root.join("app/assets/sounds/*.ogg")]
      .each_with_object({}) { |f, h| h[File.basename(f, ".ogg")] = asset_path(File.basename(f)) }
  end
end
```

Deleted: `FIXED_SOUND_KEYS`, `sound_preload_keys`, `sound_asset_paths`, `current_action_moves_settlement?`.

#### View changes

`show.html.erb`:
```erb
<div id="sound-config" data-sound-paths="<%= sound_paths.to_json %>" hidden></div>
```

Remove any partial data attributes whose sole purpose was sound inference (`data-my-turn`, `data-moves-settlement`, `data-tile-count`). Keep attributes still used for hex highlighting (`data-buildable`, `data-from`).

#### Assets

- Add `app/assets/sounds/wall.ogg` (user-supplied).
- Delete `app/assets/sounds/my_turn.ogg` (personal-only sound, removed).

### Client

#### `sound.js`

Simplified: preload from a single `data-sound-paths` JSON blob, expose `init/play/setVolume/toggleMute/isMuted/getVolume`, and register the custom Turbo Stream action. No `playAfterLast`, no `lastPlayed`.

```js
var SoundManager = (() => {
  const MUTE_KEY = "kbc_muted", VOLUME_KEY = "kbc_volume";
  let sounds = {}, muted = false, volume = 1.0, ready = false;

  const applyVolume    = a => a.volume = muted ? 0 : volume;
  const applyVolumeAll = () => Object.values(sounds).forEach(applyVolume);

  function init() {
    if (ready) return; ready = true;
    const config = document.getElementById("sound-config");
    if (!config) return;
    const paths = JSON.parse(config.dataset.soundPaths || "{}");
    Object.entries(paths).forEach(([k, p]) => {
      const a = new Audio(p); a.preload = "auto"; sounds[k] = a;
    });
    volume = parseFloat(localStorage.getItem(VOLUME_KEY) ?? "1");
    muted  = localStorage.getItem(MUTE_KEY) === "true";
    applyVolumeAll();
    const unlock = () => {
      Object.values(sounds).forEach(a => { a.volume = 0; a.play().catch(() => {}); });
      document.getElementById("audio-unlock-prompt")?.remove();
      ["click","keydown","pointerdown"].forEach(ev => document.removeEventListener(ev, unlock, true));
    };
    ["click","keydown","pointerdown"].forEach(ev => document.addEventListener(ev, unlock, true));
  }

  function play(name) {
    const a = sounds[name]; if (!a) return;
    a.currentTime = 0; applyVolume(a); a.play().catch(() => {});
  }

  function setVolume(v) {
    volume = Math.min(1, Math.max(0, parseFloat(v)));
    localStorage.setItem(VOLUME_KEY, volume); applyVolumeAll();
  }
  function toggleMute() {
    muted = !muted; localStorage.setItem(MUTE_KEY, muted); applyVolumeAll(); return muted;
  }

  return { init, play, setVolume, toggleMute,
           isMuted: () => muted, getVolume: () => volume };
})();

Turbo.StreamActions.play_sound = function () {
  SoundManager.play(this.getAttribute("key"));
};
```

#### `gameboard.js`

Delete:

- sound branches inside `enableClicks` (the `dataFrom`/`movesSettlement` play calls)
- `triggerStreamSounds`, `captureStreamSnapshot`
- `streamSnapshot`, `streamSnapshotPending`, `undoPending`, `gameEndSoundPlayed` state
- click delegation on `#turn-state-bar` and `#players-area` for end-turn / undo / tile activation (the `initSoundTriggers` function's click handlers; keep its mute/volume UI wiring and `SoundManager.init()` call)

Simplify `turbo:before-stream-render` to just debounce `prepForMove`:

```js
let prepDebounceTimer = null;
document.addEventListener("turbo:before-stream-render", () => {
  clearTimeout(prepDebounceTimer);
  prepDebounceTimer = setTimeout(prepForMove, 50);
});
```

Keep: `prepForMove`, `initBoardZoom`, the click handler on `#board` (stripped of sound logic), mute/volume UI wiring, `SoundManager.init()`.

## Data Flow

1. User performs an action (build, move, end turn, activate tile, etc.).
2. Controller invokes `TurnEngine`; engine creates one or more `Move` records.
3. Each Move's `after_create_commit` hook broadcasts a `<turbo-stream action="play_sound" key="...">` to `game_#{id}`.
4. Controller calls `broadcast_game_update`, which broadcasts partial updates for turn-state, board, log, players, etc.
5. All subscribed clients receive stream actions in order:
   - `play_sound` actions → `SoundManager.play(key)`
   - Partial updates → DOM replace
6. Undo: controller calls `@game.broadcast_sound("undo")` before `broadcast_game_update`.

## Edge Cases

- **Multiple moves per user action** (e.g., build → `build` + `pick_up_tile`, or end-turn → `end_turn` + `end_game`): sounds broadcast and play in order, may overlap slightly. Accepted.
- **Unmapped Move actions** (`score_goal`, `select_action` with no klass payload): `sound_key` returns nil; no broadcast.
- **Autoplay unlock**: preserved via first-gesture silent-play loop in `init()`.
- **Mute/volume**: unchanged, client-side, per-browser via localStorage.
- **Dropped personal sound**: `my_turn.ogg` and all code paths that played it are removed. The `end_turn` sound (which all clients hear) serves as the turn-change signal.
- **Click-to-sound latency**: the acting player now hears their own action sound after one round-trip (typically 10–50ms local, up to ~200ms remote) instead of instantly. Accepted as the price of universality and simpler code.

## Testing

**Added:**
- `test/models/move_test.rb`:
  - Table-driven test: each mapped action creates a Move that broadcasts its expected sound key.
  - `select_action` with `payload["klass"] = "PaddockTile"` broadcasts `paddock`; same for `OasisTile` → `oasis`.
  - Unmapped action (`score_goal`, `select_action` without klass) does not broadcast.

**Deleted:**
- `test/helpers/games_helper_test.rb` (all cases reference removed helpers).

**Unchanged:**
- Existing controller/engine tests — none assert sound behavior.

## Non-Goals

- Sound ordering / queuing across overlapping moves. Server broadcasts in creation order; client plays immediately. No client-side queue.
- Sound-specific access control. Anyone on the game channel hears everything; observers and players are equal.
- Backwards compatibility with the old click-sound UX.

## File Summary

**Modified:**
- `app/models/move.rb`
- `app/models/game.rb` (add `broadcast_sound`)
- `app/controllers/games_controller.rb` (one line in `undo_move`)
- `app/helpers/games_helper.rb` (replace contents)
- `app/javascript/sound.js`
- `app/javascript/gameboard.js`
- `app/views/games/show.html.erb`
- `app/views/games/_tiles.html.erb` (remove `data-tile-count` from both `.player-tiles` divs)
- `app/views/games/_end_turn.html.erb` (remove `#my-turn-flag` span)
- `app/views/games/_turn_state.html.erb` (remove `data-moves-settlement` attribute)

**Added:**
- `app/assets/sounds/wall.ogg` (user-supplied)
- `test/models/move_test.rb`

**Deleted:**
- `app/assets/sounds/my_turn.ogg`
- `test/helpers/games_helper_test.rb`
