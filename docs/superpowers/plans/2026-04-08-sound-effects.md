# Sound Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-event sound effects to KBC with per-browser volume/mute controls persisted in `localStorage`.

**Architecture:** `sound.js` is a classic (non-module) script that defines a global `SoundManager` object; it is loaded via `javascript_include_tag` before `gameboard.js` so that both share the browser's global scope. `gameboard.js` calls `SoundManager.play(key)` at existing interaction points and in the post-stream debounce handler. The Rails helper `sound_preload_keys` derives which tile sounds to preload from `game.boards`; asset paths are computed server-side and injected into a `#sound-config` DOM element so JS never hardcodes fingerprinted filenames.

**Tech Stack:** Ruby on Rails 8.1, Propshaft, vanilla JS (classic scripts), Web Audio via native `Audio` API, `localStorage` for persistence, OGG/Opus audio format.

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `app/javascript/sound.js` | SoundManager: preload, play, volume, mute |
| Create | `test/helpers/games_helper_test.rb` | Unit tests for sound helper methods |
| Modify | `app/helpers/games_helper.rb` | `sound_preload_keys`, `sound_asset_paths` |
| Modify | `app/views/games/show.html.erb` | `#sound-config` element; load `sound.js` before `gameboard.js` |
| Modify | `app/views/games/show.turbo_stream.erb` | Load `sound.js` before `gameboard.js` |
| Modify | `app/views/games/_tiles.html.erb` | Add `data-tile-count` attribute |
| Modify | `app/views/games/_game.html.erb` | Volume control UI in turn-state bar |
| Modify | `app/javascript/gameboard.js` | Import SoundManager; wire all triggers |

Sound files (OGG/Opus) are placed in `app/assets/sounds/` by the developer when recorded. The helper and JS both handle missing files gracefully — `sound_asset_paths` rescues missing assets, and `SoundManager.play` no-ops for unknown keys.

---

## Task 1: Rails helper methods

**Files:**
- Create: `test/helpers/games_helper_test.rb`
- Modify: `app/helpers/games_helper.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/helpers/games_helper_test.rb
require "test_helper"

class GamesHelperTest < ActionView::TestCase
  test "sound_preload_keys includes all fixed keys" do
    game = Minitest::Mock.new
    game.expect :boards, []

    keys = sound_preload_keys(game)

    %w[build move select_settlement tile_pickup tile_forfeit
       my_turn game_end undo end_turn].each do |k|
      assert_includes keys, k, "expected fixed key #{k.inspect} in preload list"
    end
  end

  test "sound_preload_keys includes tile keys derived from game boards" do
    game = Minitest::Mock.new
    game.expect :boards, [["Tavern", 0], ["Paddock", 1], ["Oasis", 2], ["Farm", 3]]

    keys = sound_preload_keys(game)

    assert_includes keys, "tavern"
    assert_includes keys, "paddock"
    assert_includes keys, "oasis"
    assert_includes keys, "farm"
    assert_not_includes keys, "harbor"
  end

  test "sound_preload_keys contains no duplicates" do
    game = Minitest::Mock.new
    game.expect :boards, [["Tavern", 0], ["Paddock", 1]]

    keys = sound_preload_keys(game)

    assert_equal keys, keys.uniq
  end

  test "sound_asset_paths does not raise when sound files are absent" do
    assert_nothing_raised { sound_asset_paths(%w[build move undo]) }
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/helpers/games_helper_test.rb
```

Expected: 4 failures — `NoMethodError: undefined method 'sound_preload_keys'`

- [ ] **Step 3: Implement helper methods**

```ruby
# app/helpers/games_helper.rb
module GamesHelper
  FIXED_SOUND_KEYS = %w[
    build move select_settlement tile_pickup tile_forfeit
    my_turn game_end undo end_turn
  ].freeze

  # Returns the list of sound keys to preload for this game:
  # always the 9 fixed event sounds, plus one key per tile type in play.
  # game.boards is an array of [board_name, rotation] pairs, e.g. [["Tavern", 0], ["Paddock", 1]].
  def sound_preload_keys(game)
    tile_keys = game.boards.map { |name, _| name.downcase }
    (FIXED_SOUND_KEYS + tile_keys).uniq
  end

  # Returns a hash of { sound_key => fingerprinted_asset_path } for all keys
  # whose .ogg file exists in app/assets/sounds/. Silently skips missing files
  # so the game works before all recordings are in place.
  def sound_asset_paths(keys)
    keys.each_with_object({}) do |k, hash|
      hash[k] = asset_path("sounds/#{k}.ogg")
    rescue StandardError
      # File not yet added to app/assets/sounds/ — JS will skip unknown keys
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bin/rails test test/helpers/games_helper_test.rb
```

Expected: 4 runs, 0 failures, 0 errors

- [ ] **Step 5: Commit**

```bash
git add app/helpers/games_helper.rb test/helpers/games_helper_test.rb
git commit -m "Add sound_preload_keys and sound_asset_paths helpers"
```

---

## Task 2: Sound config element and script loading order

**Files:**
- Modify: `app/views/games/show.html.erb`
- Modify: `app/views/games/show.turbo_stream.erb`

- [ ] **Step 1: Add `#sound-config` and correct script order to `show.html.erb`**

The current file ends with:
```erb
<%= javascript_include_tag "gameboard" %>
```

Replace that line and add the sound-config element:
```erb
<div id="sound-config"
     data-sound-preload="<%= sound_preload_keys(game).to_json %>"
     data-sound-paths="<%= sound_asset_paths(sound_preload_keys(game)).to_json %>"
     hidden></div>
<%= javascript_include_tag "sound" %>
<%= javascript_include_tag "gameboard" %>
```

- [ ] **Step 2: Update `show.turbo_stream.erb` script loading order**

Current content:
```erb
<%= render partial: "games/game", locals: { game:, my_player:, engine: TurnEngine.new(game), scores: game.live_scores } %>
<%= javascript_include_tag "gameboard" %>
```

Replace `javascript_include_tag "gameboard"` line:
```erb
<%= render partial: "games/game", locals: { game:, my_player:, engine: TurnEngine.new(game), scores: game.live_scores } %>
<%= javascript_include_tag "sound" %>
<%= javascript_include_tag "gameboard" %>
```

(`#sound-config` is not re-added here — it lives only in the initial page render in `show.html.erb` and is never replaced by streams.)

- [ ] **Step 3: Create placeholder sounds directory**

```bash
mkdir -p app/assets/sounds
```

Add a `.keep` file so git tracks the directory:
```bash
touch app/assets/sounds/.keep
```

- [ ] **Step 4: Run the test suite to confirm nothing is broken**

```bash
bin/rails test
```

Expected: all existing tests pass (the new `#sound-config` element is hidden and harmless)

- [ ] **Step 5: Commit**

```bash
git add app/views/games/show.html.erb app/views/games/show.turbo_stream.erb app/assets/sounds/.keep
git commit -m "Add sound-config element and load sound.js before gameboard.js"
```

---

## Task 3: data-tile-count attribute on player tiles

**Files:**
- Modify: `app/views/games/_tiles.html.erb`

The post-stream trigger for `tile_pickup` and `tile_forfeit` works by snapshotting the tile count before a stream renders and comparing after. This requires a `data-tile-count` attribute on the `.player-tiles` div.

- [ ] **Step 1: Add `data-tile-count` to `_tiles.html.erb`**

Current opening line:
```erb
<div class="player-tiles">
```

Replace with:
```erb
<div class="player-tiles" data-tile-count="<%= (player.tiles || []).size %>">
```

- [ ] **Step 2: Verify in browser**

Start the server (`make up`) and open a game. Inspect the `.player-tiles` element — it should have `data-tile-count="0"` (or the actual count if the player holds tiles).

- [ ] **Step 3: Run the test suite**

```bash
bin/rails test
```

Expected: all tests pass

- [ ] **Step 4: Commit**

```bash
git add app/views/games/_tiles.html.erb
git commit -m "Add data-tile-count attribute to player-tiles for sound trigger detection"
```

---

## Task 4: Volume control UI

**Files:**
- Modify: `app/views/games/_game.html.erb`

- [ ] **Step 1: Add volume control to the turn-state bar**

Current `_game.html.erb` opens with:
```erb
<div id="turn-state-bar">
  <div id="dashboard-link-area">
    <%= link_to "Dashboard", dashboard_path %>
  </div>
  <div id="turn-state">
```

Add the sound controls div between `#dashboard-link-area` and `#turn-state`:
```erb
<div id="turn-state-bar">
  <div id="dashboard-link-area">
    <%= link_to "Dashboard", dashboard_path %>
  </div>
  <div id="sound-controls">
    <button id="mute-btn" type="button" aria-label="Toggle mute">&#128266;</button>
    <input id="volume-slider" type="range" min="0" max="1" step="0.01"
           aria-label="Volume">
  </div>
  <div id="turn-state">
```

(`&#128266;` is 🔊; `gameboard.js` will swap the label to `&#128264;` (🔇) when muted.)

- [ ] **Step 2: Verify in browser**

The turn-state bar should show a speaker button and a range slider. They won't function until Task 6 wires them up.

- [ ] **Step 3: Run the test suite**

```bash
bin/rails test
```

Expected: all tests pass

- [ ] **Step 4: Commit**

```bash
git add app/views/games/_game.html.erb
git commit -m "Add volume control UI to turn-state bar"
```

---

## Task 5: SoundManager module

**Files:**
- Create: `app/javascript/sound.js`

This is a classic (non-module) script. `SoundManager` is defined as a top-level `const`, accessible to `gameboard.js` since both run as classic scripts in the same browsing context. `init()` is guarded so re-execution on Turbo Stream responses is a no-op.

- [ ] **Step 1: Create `app/javascript/sound.js`**

```js
// sound.js — loaded as a classic script before gameboard.js
// Exposes SoundManager as a global accessible to gameboard.js.
const SoundManager = (() => {
  const MUTE_KEY   = "kbc_muted";
  const VOLUME_KEY = "kbc_volume";

  let sounds    = {};   // { key: HTMLAudioElement }
  let muted     = false;
  let volume    = 1.0;
  let ready     = false;

  function applyVolume(audio) {
    audio.volume = muted ? 0 : volume;
  }

  function applyVolumeAll() {
    Object.values(sounds).forEach(applyVolume);
  }

  function init() {
    if (ready) return;
    ready = true;

    const config = document.getElementById("sound-config");
    if (!config) return;

    const keys  = JSON.parse(config.dataset.soundPreload || "[]");
    const paths = JSON.parse(config.dataset.soundPaths   || "{}");

    keys.forEach(k => {
      if (!paths[k]) return;   // file not yet recorded
      const audio = new Audio(paths[k]);
      audio.preload = "auto";
      sounds[k] = audio;
    });

    volume = parseFloat(localStorage.getItem(VOLUME_KEY) ?? "1");
    muted  = localStorage.getItem(MUTE_KEY) === "true";
    applyVolumeAll();
  }

  function play(name) {
    const audio = sounds[name];
    if (!audio) return;
    audio.currentTime = 0;
    applyVolume(audio);
    audio.play().catch(() => {});   // ignore autoplay policy errors
  }

  function setVolume(v) {
    volume = Math.min(1, Math.max(0, parseFloat(v)));
    localStorage.setItem(VOLUME_KEY, volume);
    applyVolumeAll();
  }

  function toggleMute() {
    muted = !muted;
    localStorage.setItem(MUTE_KEY, muted);
    applyVolumeAll();
    return muted;
  }

  function isMuted() { return muted; }
  function getVolume() { return volume; }

  return { init, play, setVolume, toggleMute, isMuted, getVolume };
})();
```

- [ ] **Step 2: Verify the file is served correctly**

Start the server (`make up`), navigate to a game, open DevTools console and run:

```js
SoundManager.isMuted()   // should return false
SoundManager.getVolume() // should return 1
```

- [ ] **Step 3: Commit**

```bash
git add app/javascript/sound.js
git commit -m "Add SoundManager module for sound effect playback"
```

---

## Task 6: gameboard.js — init, click triggers, and volume control

**Files:**
- Modify: `app/javascript/gameboard.js`

- [ ] **Step 1: Add `SoundManager.init()` call and click-based triggers**

At the bottom of `gameboard.js`, the current boot sequence is:
```js
// prepare for the first move
prepForMove();
// set up click targets
enableClicks();
// set up board zoom
initBoardZoom();
```

**Before** those lines, add the sound init and a new `initSoundTriggers` function, then call it:

```js
function initSoundTriggers() {
  SoundManager.init();

  // Undo button — delegate from turn-state bar (stable ancestor)
  document.getElementById("turn-state-bar")?.addEventListener("click", (e) => {
    if (e.target.closest(".undo-btn")) SoundManager.play("undo");
    if (e.target.closest("#end-turn-area button, #end-turn-area [type='submit']")) {
      SoundManager.play("end_turn");
    }
  });

  // Tile selection — delegate from players-area (stable ancestor)
  document.getElementById("players-area")?.addEventListener("click", (e) => {
    const tileEl = e.target.closest(".tile-activatable");
    if (!tileEl) return;
    const container = tileEl.querySelector(".tile-container");
    if (!container) return;
    const type = [...container.classList].find(c => c !== "tile-container");
    if (type) SoundManager.play(type);
  });

  // Mute toggle
  document.getElementById("mute-btn")?.addEventListener("click", () => {
    const nowMuted = SoundManager.toggleMute();
    const btn = document.getElementById("mute-btn");
    if (btn) btn.innerHTML = nowMuted ? "&#128264;" : "&#128266;";
  });

  // Volume slider
  document.getElementById("volume-slider")?.addEventListener("input", (e) => {
    SoundManager.setVolume(e.target.value);
  });

  // Restore volume control UI state from localStorage
  const slider = document.getElementById("volume-slider");
  const muteBtn = document.getElementById("mute-btn");
  if (slider) slider.value = SoundManager.getVolume();
  if (muteBtn) muteBtn.innerHTML = SoundManager.isMuted() ? "&#128264;" : "&#128266;";
}
```

Also modify `enableClicks()` to play the build or move sound. Find the existing click handler:

```js
function enableClicks() {
  document.querySelector("#board").
    addEventListener("click", function (e) {
      const hex = e.target.closest(".hex");
      if (!hex || !hex.classList.contains("selectable")) {
        return;
      }
      console.log("Click target: " + hex.id);
      e.preventDefault();
      const parts = hex.id.split("-");
      document.getElementById("build_row").value = parts[2];
      document.getElementById("build_col").value = parts[3];
      document.getElementById("action_submit").click();
    });
}
```

Replace it with:

```js
function enableClicks() {
  document.querySelector("#board").
    addEventListener("click", function (e) {
      const hex = e.target.closest(".hex");
      if (!hex || !hex.classList.contains("selectable")) {
        return;
      }
      console.log("Click target: " + hex.id);
      e.preventDefault();
      const parts = hex.id.split("-");
      document.getElementById("build_row").value = parts[2];
      document.getElementById("build_col").value = parts[3];
      // data-from present means a settlement is selected for move → destination click
      const dataFrom = document.getElementById("current-action")?.dataset.from;
      SoundManager.play(dataFrom ? "move" : "build");
      document.getElementById("action_submit").click();
    });
}
```

Update the boot sequence at the bottom:

```js
// prepare for the first move
prepForMove();
// set up click targets
enableClicks();
// set up board zoom
initBoardZoom();
// set up sound triggers
initSoundTriggers();
```

- [ ] **Step 2: Verify in browser**

Open a game. Click a selectable hex — check the console logs. Click the undo button (if enabled). Click an activatable tile. Each should log no errors. (Sounds will play once .ogg files exist.)

Check that the volume slider and mute button respond — muting should swap the icon; sliding should update volume.

- [ ] **Step 3: Run the test suite**

```bash
bin/rails test
```

Expected: all tests pass

- [ ] **Step 4: Commit**

```bash
git add app/javascript/gameboard.js
git commit -m "Wire click-based sound triggers and volume control in gameboard.js"
```

---

## Task 7: gameboard.js — post-stream sound triggers

**Files:**
- Modify: `app/javascript/gameboard.js`

Post-stream triggers detect state changes caused by Turbo Stream updates (my turn, select settlement, tile pickup/forfeit, game end). The pattern: snapshot relevant DOM state on the first `turbo:before-stream-render` event in a batch, then compare after the debounce fires.

- [ ] **Step 1: Add snapshot helpers and the post-stream trigger logic**

Find the existing debounce block in `gameboard.js`:

```js
let prepDebounceTimer = null;
document.addEventListener("turbo:before-stream-render", () => {
  clearTimeout(prepDebounceTimer);
  prepDebounceTimer = setTimeout(prepForMove, 50);
});
```

Replace it with:

```js
let prepDebounceTimer     = null;
let streamSnapshotPending = false;
let streamSnapshot        = null;
let gameEndSoundPlayed    = false;

function captureStreamSnapshot() {
  return {
    myTurn:    document.getElementById("my-turn-flag")?.dataset.myTurn,
    dataFrom:  document.getElementById("current-action")?.dataset.from,
    tileCount: document.querySelector(".player-tiles")?.dataset.tileCount,
    hasEndModal: !!document.getElementById("end-game-modal")
  };
}

function triggerStreamSounds(before) {
  if (!before) return;
  const after = captureStreamSnapshot();

  // My turn started
  if (before.myTurn !== "true" && after.myTurn === "true") {
    SoundManager.play("my_turn");
  }

  // Settlement selected for move (data-from appeared)
  if (!before.dataFrom && after.dataFrom) {
    SoundManager.play("select_settlement");
  }

  // Tile count changed
  const countBefore = parseInt(before.tileCount ?? "0", 10);
  const countAfter  = parseInt(after.tileCount  ?? "0", 10);
  if (countAfter > countBefore) SoundManager.play("tile_pickup");
  if (countAfter < countBefore) SoundManager.play("tile_forfeit");

  // Game ended
  if (!before.hasEndModal && after.hasEndModal && !gameEndSoundPlayed) {
    gameEndSoundPlayed = true;
    SoundManager.play("game_end");
  }
}

document.addEventListener("turbo:before-stream-render", () => {
  if (!streamSnapshotPending) {
    streamSnapshotPending = true;
    streamSnapshot = captureStreamSnapshot();
  }
  clearTimeout(prepDebounceTimer);
  prepDebounceTimer = setTimeout(() => {
    prepForMove();
    triggerStreamSounds(streamSnapshot);
    streamSnapshot        = null;
    streamSnapshotPending = false;
    prepDebounceTimer     = null;
  }, 50);
});
```

- [ ] **Step 2: Verify in browser**

Play through a turn:
- When another player ends their turn and it becomes your turn, the `my_turn` sound should fire.
- When you click a settlement to move with a movement tile, `select_settlement` should fire.
- Building adjacent to a tile location should trigger `tile_pickup`.
- A Paddock move that forfeits a tile should trigger `tile_forfeit`.
- The end-game modal appearing should trigger `game_end` once.

(All sounds are silent until `.ogg` files are placed in `app/assets/sounds/`.)

- [ ] **Step 3: Run the test suite**

```bash
bin/rails test
```

Expected: all tests pass

- [ ] **Step 4: Commit**

```bash
git add app/javascript/gameboard.js
git commit -m "Add post-stream sound triggers for turn, selection, tile, and game-end events"
```

---

## Task 8: Add your sound files

**Files:**
- Add: `app/assets/sounds/*.ogg`

Place your recorded OGG/Opus files in `app/assets/sounds/`. The expected filenames match the sound keys exactly:

**Fixed sounds (always loaded):**
- `build.ogg`
- `move.ogg`
- `select_settlement.ogg`
- `tile_pickup.ogg`
- `tile_forfeit.ogg`
- `my_turn.ogg`
- `game_end.ogg`
- `undo.ogg`
- `end_turn.ogg`

**Tile sounds (loaded only for tiles in this game):**
- `tavern.ogg`
- `paddock.ogg`
- `oasis.ogg`
- `farm.ogg`
- `harbor.ogg`
- `oracle.ogg`
- `barn.ogg`
- `tower.ogg`
- `mandatory.ogg`

You can add them incrementally — the system silently skips any key whose file is absent. Sounds activate on next page load after the file is added (Propshaft picks up new assets automatically in development).

- [ ] **Step 1: Add files as they are recorded**

```bash
# Example — copy your recorded files into place:
cp ~/recordings/build.ogg app/assets/sounds/build.ogg
# etc.
```

- [ ] **Step 2: Verify in browser**

Open a game, open DevTools Network tab, filter by "ogg" — the preloaded files should appear as fetched. Play through actions and confirm sounds fire.

- [ ] **Step 3: Commit files as they are added**

```bash
git add app/assets/sounds/
git commit -m "Add sound effect recordings"
```

---

## Self-Review Notes

- `game.boards` entries are `["Tavern", 0]` (not `"TavernBoard"`) — verified against `Boards::Board::BOARD_CLASSES` keys.
- `SoundManager.init()` is guarded by `ready` flag — safe to call on every Turbo Stream response.
- `tile_forfeit` is used throughout (matching `apply_tile_forfeit` in the model and the finalized spec language).
- Event delegation is used for all click triggers (undo, end_turn, tile buttons) so listeners survive Turbo Stream DOM replacement.
- `game_end` sound is guarded by `gameEndSoundPlayed` flag to prevent re-firing on subsequent stream updates after the modal appears.
- `sound_asset_paths` rescues any `StandardError` so missing asset files never break page rendering.
- `#sound-config` lives in `show.html.erb` (not in a streamed partial) so it is stable across the session.
