# Sound Effects Design

**Date:** 2026-04-08

## Overview

Add sound effects to KBC that play for the player making choices. Volume and mute persist per browser via `localStorage`. Sounds are preloaded selectively — only those relevant to the current game's tile set are fetched.

## Sound Inventory

| Key | Trigger |
|---|---|
| `build` | Hex click with no `data-from` on `#current-action` (mandatory build or build-type tile action) |
| `move` | Hex click with `data-from` present (move destination) |
| `select_settlement` | `data-from` appears on `#current-action` post-stream (settlement chosen for move) |
| `tile_pickup` | Tile count in player hand increases post-stream (automatic pickup) |
| `tile_forfeit` | Tile count in player hand decreases post-stream (tile forfeit) |
| `my_turn` | `data-my-turn` flips to `"true"` post-stream |
| `game_end` | `#end-game-modal` appears in DOM post-stream (fires once, guarded by flag) |
| `undo` | `.undo-btn` click |
| `end_turn` | End-turn button click |
| `tavern` | Tavern tile button click |
| `paddock` | Paddock tile button click |
| `oasis` | Oasis tile button click |
| `farm` | Farm tile button click |
| `harbor` | Harbor tile button click |
| `oracle` | Oracle tile button click |
| `barn` | Barn tile button click |
| `tower` | Tower tile button click |
| `mandatory` | Mandatory tile button click |

Nine non-tile sounds are always preloaded. Tile sounds are preloaded only for tile types active in the current game.

## Asset Format

OGG/Opus. Supported natively in Firefox, Chrome, Edge, and Safari 14.1+. No fallback format needed. Files live in `app/assets/sounds/`, named by key (e.g. `build.ogg`, `tavern.ogg`). Propshaft fingerprints and serves them automatically.

## Future Adaptation (All Viewers Hear Sounds)

The `SoundManager.play(name)` interface is trigger-agnostic. When sounds should broadcast to all viewers, the server includes a `data-sound` attribute on a hidden element in its Turbo Stream broadcasts. The existing `turbo:before-stream-render` debounce handler reads it and calls `play()`. No changes to `SoundManager` itself.

## Architecture

### `app/javascript/sound.js` — `SoundManager` module

Plain JS object (not a class), exported as default. Imported by `gameboard.js`.

**`init()`**
- Reads `data-sound-preload` (key list) and `data-sound-paths` (key→fingerprinted URL map) JSON from `#sound-config` DOM element
- Creates `Audio` objects for each key using the fingerprinted URL, stores in internal map
- Restores volume and mute state from `localStorage` (`kbc_volume`, `kbc_muted`)
- Applies restored state to all loaded `Audio` objects

**`play(name)`**
- Looks up `Audio` object by key; silently no-ops if not preloaded
- Resets `currentTime` to 0 (supports rapid re-triggers)
- Applies current volume/mute before calling `.play()`

**`setVolume(v)`**
- Clamps to 0–1
- Saves to `localStorage` as `kbc_volume`
- Applies to all loaded `Audio` objects

**`toggleMute()`**
- Flips mute state; saves to `localStorage` as `kbc_muted`
- Applies immediately to all loaded `Audio` objects
- Volume value is preserved separately so unmuting restores prior level

### `app/javascript/gameboard.js` — trigger wiring

Imports `SoundManager` and calls `SoundManager.init()` on load.

**Click-based triggers:**
- `.undo-btn` click → `play("undo")`
- End-turn button click → `play("end_turn")`
- Hex click (in `enableClicks()`): check `#current-action[data-from]` — absent → `play("build")`, present → `play("move")`
- Tile button click (`.player-tiles button`) → read tile type from button context → `play("<type>")`

**Post-stream triggers (in `turbo:before-stream-render` debounce handler):**
- Snapshot `data-my-turn` before stream; compare after → flipped to `"true"` → `play("my_turn")`
- Snapshot `data-from` on `#current-action` before stream; compare after → appeared → `play("select_settlement")`
- Snapshot `data-tile-count` on the player's own `.player-tiles` container (index 0 in the player list; server adds this attribute) before stream; compare after → increased → `play("tile_pickup")`, decreased → `play("tile_forfeit")`
- Check `#end-game-modal` existence after stream → appeared → `play("game_end")` (once, guarded by flag)

### Server-side changes

**`app/views/games/_game.html.erb`**

Add one element inside the game layout:

```erb
<div id="sound-config"
     data-sound-preload="<%= sound_preload_keys(game).to_json %>"
     data-sound-paths="<%= sound_asset_paths(sound_preload_keys(game)).to_json %>">
</div>
```

`sound_preload_keys(game)` is a helper that returns the nine fixed keys plus tile keys derived from `game.boards` (e.g. `"TavernBoard"` → `"tavern"`).

`sound_asset_paths` returns a hash of `{ key => fingerprinted_asset_path }` so JS never hardcodes Propshaft filenames.

**`app/helpers/games_helper.rb`** (or `application_helper.rb`)

```ruby
FIXED_SOUND_KEYS = %w[build move select_settlement tile_pickup tile_forfeit
                      my_turn game_end undo end_turn].freeze

def sound_preload_keys(game)
  tile_keys = game.boards.map { |name, _| name.delete_suffix("Board").downcase }
  (FIXED_SOUND_KEYS + tile_keys).uniq
end

def sound_asset_paths(keys)
  keys.index_with { |k| asset_path("sounds/#{k}.ogg") }
end
```

### Volume control UI

Added to the turn-state bar in `_game.html.erb`:

- Mute toggle button (speaker icon / muted icon)
- Range slider (`<input type="range" min="0" max="1" step="0.01">`)

Wired in `gameboard.js` to `SoundManager.toggleMute()` and `SoundManager.setVolume(v)`. On load, control values reflect state restored from `localStorage`. Renders for all users (observers included) since it is a per-browser preference.

## Turn Sequence Reference

```
Turn starts       → my_turn
  Mandatory build → build [→ tile_pickup if applicable]
  Tile action:
    Select tile   → <tile-type>
    If move-type:
      Select hex  → select_settlement
      Dest hex    → move [→ tile_forfeit if forfeited]
    If build-type:
      Click hex   → build [→ tile_pickup if applicable]
  Undo            → undo
End turn          → end_turn
Game ends         → game_end
```
