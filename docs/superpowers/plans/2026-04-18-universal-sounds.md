# Universal Sounds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor sound effects so every player and observer hears identical sounds, driven from a single server source (the `Move` model), and shrink total sound-related code substantially.

**Architecture:** `Move#after_create_commit` broadcasts a custom `<turbo-stream action="play_sound">` to the game's Turbo channel. A client-side `Turbo.StreamActions.play_sound` calls `SoundManager.play(key)`. Undo deletes Moves, so `GamesController#undo_move` broadcasts its sound explicitly via a new `Game#broadcast_sound` method. All click-handler and stream-diff sound logic on the client is removed.

**Tech Stack:** Rails 8.1, Turbo Streams, ActionCable, plain JS (classic script).

**Reference spec:** `docs/superpowers/specs/2026-04-18-universal-sounds-design.md`

---

### Task 1: Add `Move` sound-mapping constant and `sound_key` method

**Files:**
- Modify: `app/models/move.rb`
- Test: `test/models/move_test.rb` (new file)

- [ ] **Step 1: Write failing tests for `sound_key`**

Create `test/models/move_test.rb`:

```ruby
require "test_helper"

class MoveTest < ActiveSupport::TestCase
  def build_move(action:, payload: nil)
    game = games(:game2player)
    gp = game_players(:chris)
    Move.new(game: game, game_player: gp, action: action, payload: payload, order: 1)
  end

  test "sound_key maps mapped actions to their keys" do
    expected = {
      "build" => "build",
      "select_settlement" => "select_settlement",
      "move_settlement" => "move",
      "pick_up_tile" => "tile_pickup",
      "forfeit_tile" => "tile_forfeit",
      "end_turn" => "end_turn",
      "end_game" => "game_end",
      "remove_settlement" => "removed",
      "activate_outpost" => "outpost",
      "place_wall" => "wall"
    }
    expected.each do |action, key|
      assert_equal key, build_move(action: action).send(:sound_key), "#{action} should map to #{key}"
    end
  end

  test "sound_key derives select_action sound from payload klass" do
    move = build_move(action: "select_action", payload: { "klass" => "PaddockTile" })
    assert_equal "paddock", move.send(:sound_key)

    move = build_move(action: "select_action", payload: { "klass" => "OasisTile" })
    assert_equal "oasis", move.send(:sound_key)
  end

  test "sound_key returns nil for unmapped actions" do
    assert_nil build_move(action: "score_goal").send(:sound_key)
    assert_nil build_move(action: "select_action").send(:sound_key)
    assert_nil build_move(action: "select_action", payload: {}).send(:sound_key)
  end
end
```

- [ ] **Step 2: Run test and verify failure**

Run: `bin/rails test test/models/move_test.rb`
Expected: FAIL with `NoMethodError: undefined method 'sound_key'` (or similar).

- [ ] **Step 3: Add constant and `sound_key` to `Move`**

Replace `app/models/move.rb` with:

```ruby
# == Schema Information (keep existing schema comment block at top of file unchanged)
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

  private

  def sound_key
    return SOUNDS[action] if SOUNDS.key?(action)
    payload["klass"].delete_suffix("Tile").downcase if action == "select_action" && payload&.dig("klass")
  end
end
```

(Preserve the schema-info comment block already present at the top of the file.)

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/move_test.rb`
Expected: 3 runs, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/models/move.rb test/models/move_test.rb
git commit -m "Add Move#sound_key mapping action → sound"
```

---

### Task 2: Add `Move#broadcast_sound` hook that emits a Turbo Stream

**Files:**
- Modify: `app/models/move.rb`
- Test: `test/models/move_test.rb`

- [ ] **Step 1: Write failing test for broadcast behavior**

Append to `test/models/move_test.rb`:

```ruby
  test "creating a Move broadcasts a play_sound turbo stream with the mapped key" do
    game = games(:game2player)
    gp = game_players(:chris)
    assert_turbo_stream_broadcasts("game_#{game.id}") do
      game.moves.create!(game_player: gp, action: "build", order: 1)
    end
  end

  test "creating a Move with unmapped action does not broadcast" do
    game = games(:game2player)
    gp = game_players(:chris)
    assert_no_turbo_stream_broadcasts("game_#{game.id}") do
      game.moves.create!(game_player: gp, action: "score_goal", order: 2)
    end
  end
```

Ensure `require "turbo/broadcastable/test_helper"` is present near the top of `test/models/move_test.rb` (add it right after `require "test_helper"`).

- [ ] **Step 2: Run test and verify failure**

Run: `bin/rails test test/models/move_test.rb`
Expected: Failures on the two new tests (no broadcasts captured / unexpected broadcast).

- [ ] **Step 3: Add `after_create_commit` hook**

Edit `app/models/move.rb`. After `belongs_to :game_player`, add:

```ruby
  after_create_commit :broadcast_sound
```

Inside the `private` section, add (next to `sound_key`):

```ruby
  def broadcast_sound
    key = sound_key
    return unless key
    Turbo::StreamsChannel.broadcast_render_to(
      "game_#{game_id}",
      inline: %(<turbo-stream action="play_sound" key="#{key}"></turbo-stream>)
    )
  end
```

Final file looks like:

```ruby
# (schema comment preserved)
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

- [ ] **Step 4: Run Move tests**

Run: `bin/rails test test/models/move_test.rb`
Expected: 5 runs, 0 failures.

- [ ] **Step 5: Run full test suite to catch regressions**

Run: `bin/rails test`
Expected: green. If existing tests that create Moves now trigger unexpected broadcasts and fail, those tests likely need `assert_turbo_stream_broadcasts`/`assert_no_turbo_stream_broadcasts` scoping — but the current broadcast assertions in `game_test.rb` are on `user_*` channels, not `game_*`, so they should remain unaffected. Investigate any failures before proceeding.

- [ ] **Step 6: Commit**

```bash
git add app/models/move.rb test/models/move_test.rb
git commit -m "Broadcast play_sound Turbo Stream on Move create"
```

---

### Task 3: Add `Game#broadcast_sound` for non-Move sounds

**Files:**
- Modify: `app/models/move.rb` (extract shared regex constant)
- Modify: `app/models/game.rb`
- Test: `test/models/game_test.rb`

Task 2 introduced an inline `/\A[a-z_]+\z/` guard in `Move#broadcast_sound` to prevent HTML injection via the `key` attribute. `Game#broadcast_sound` will broadcast through the same inline-HTML path with a caller-supplied key and must carry the same guard. To keep the guard from drifting, extract the regex into a `SOUND_KEY_FORMAT` constant on `Move` and reference it from both sites.

- [ ] **Step 1: Extract `SOUND_KEY_FORMAT` on `Move`**

In `app/models/move.rb`, directly after the `SOUNDS = { ... }.freeze` constant, add:

```ruby
  SOUND_KEY_FORMAT = /\A[a-z_]+\z/
```

Change the guard in `broadcast_sound` from:

```ruby
    return unless key&.match?(/\A[a-z_]+\z/)
```

to:

```ruby
    return unless key&.match?(SOUND_KEY_FORMAT)
```

Run: `bin/rails test test/models/move_test.rb`
Expected: 6 runs, 0 failures (no behavior change).

- [ ] **Step 2: Write failing tests for `Game#broadcast_sound`**

Append to `test/models/game_test.rb` before the final `private` block (around line 1117):

```ruby
  test "broadcast_sound emits a play_sound turbo stream to the game channel" do
    game = games(:game2player)
    broadcasts = capture_turbo_stream_broadcasts("game_#{game.id}") do
      game.broadcast_sound("undo")
    end
    assert broadcasts.any? { |b| b.include?(%(action="play_sound")) && b.include?(%(key="undo")) },
      "expected a play_sound[key=undo] broadcast, got: #{broadcasts.inspect}"
  end

  test "broadcast_sound refuses to broadcast a malicious key" do
    game = games(:game2player)
    assert_no_turbo_stream_broadcasts("game_#{game.id}") do
      game.broadcast_sound(%(foo"><script>alert(1)</script><x))
    end
  end
```

If `test/models/game_test.rb` doesn't already have `include Turbo::Broadcastable::TestHelper` and `require "turbo/broadcastable/test_helper"`, verify by reading the file header — the existing `assert_turbo_stream_broadcasts` usage around line 1079 implies the setup is already in place; if not, add the require and include.

- [ ] **Step 3: Run tests and verify failure**

Run: `bin/rails test test/models/game_test.rb -n /broadcast_sound/`
Expected: FAIL with `NoMethodError: undefined method 'broadcast_sound'`.

- [ ] **Step 4: Add the method**

In `app/models/game.rb`, inside the `Game` class (next to `broadcast_game_update`, still in public methods), add:

```ruby
  def broadcast_sound(key)
    return unless key&.match?(Move::SOUND_KEY_FORMAT)
    Turbo::StreamsChannel.broadcast_render_to(
      "game_#{id}",
      inline: %(<turbo-stream action="play_sound" key="#{key}"></turbo-stream>)
    )
  end
```

- [ ] **Step 5: Run tests to verify pass**

Run: `bin/rails test test/models/game_test.rb -n /broadcast_sound/`
Expected: PASS.

Run: `bin/rails test`
Expected: green.

- [ ] **Step 6: Commit**

```bash
git add app/models/move.rb app/models/game.rb test/models/game_test.rb
git commit -m "Add Game#broadcast_sound with shared key-sanitization guard"
```

---

### Task 4: Wire undo sound in controller

**Files:**
- Modify: `app/controllers/games_controller.rb`
- Test: `test/controllers/games_controller_test.rb`

- [ ] **Step 1: Write failing test**

The existing controller test sets up login via `setup { post session_url, params: { email_address: "chris@example.com", password: "password" } }` — the new test inherits that. `assert_turbo_stream_broadcasts` only checks for >0 broadcasts, so we need `capture_turbo_stream_broadcasts` to inspect content (because `broadcast_game_update` already broadcasts to `game_{id}`). Append to `test/controllers/games_controller_test.rb` near the existing `undo_move` tests (around line 362):

```ruby
  test "undo_move broadcasts the undo play_sound turbo stream" do
    game = games(:game2player)
    game.moves.create!(
      game_player: game_players(:chris),
      action: "build",
      deliberate: true,
      reversible: true,
      order: 1
    )
    broadcasts = capture_turbo_stream_broadcasts("game_#{game.id}") do
      post undo_move_game_url(game)
    end
    assert broadcasts.any? { |b| b.include?(%(action="play_sound")) && b.include?(%(key="undo")) },
      "expected a play_sound[key=undo] broadcast, got: #{broadcasts.inspect}"
  end
```

- [ ] **Step 2: Run test and verify failure**

Run: `bin/rails test test/controllers/games_controller_test.rb -n test_undo_move_broadcasts_the_undo_play_sound_turbo_stream`
Expected: FAIL — no broadcast matching `play_sound` / `key="undo"` captured.

- [ ] **Step 3: Add the explicit broadcast**

In `app/controllers/games_controller.rb`, modify `undo_move`:

```ruby
  def undo_move
    Rails.logger.debug("UNDO MOVE action")
    engine = TurnEngine.new(@game)
    engine.undo_last_move if engine.undo_allowed?
    respond_to do |format|
      format.html { redirect_to @game }
      format.turbo_stream { head :no_content }
    end
    @game.broadcast_sound("undo")
    @game.broadcast_game_update
  end
```

- [ ] **Step 4: Run tests to verify pass**

Run: `bin/rails test test/controllers/games_controller_test.rb -n test_undo_move_broadcasts_the_undo_sound`
Expected: PASS.

Also run: `bin/rails test test/controllers/games_controller_test.rb`
Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/games_controller.rb test/controllers/games_controller_test.rb
git commit -m "Broadcast undo sound from GamesController#undo_move"
```

---

### Task 5: Shrink `GamesHelper` to a single `sound_paths` method

**Files:**
- Modify: `app/helpers/games_helper.rb`
- Delete: `test/helpers/games_helper_test.rb`

- [ ] **Step 1: Replace `app/helpers/games_helper.rb`**

Overwrite with exactly:

```ruby
module GamesHelper
  def sound_paths
    Dir[Rails.root.join("app/assets/sounds/*.ogg")].each_with_object({}) do |f, h|
      name = File.basename(f, ".ogg")
      h[name] = asset_path(File.basename(f))
    end
  end
end
```

- [ ] **Step 2: Delete the obsolete helper tests**

```bash
git rm test/helpers/games_helper_test.rb
```

- [ ] **Step 3: Run tests to verify nothing unexpectedly depends on the removed helpers**

Run: `bin/rails test`
Expected: all green. If failures reference `sound_preload_keys`, `sound_asset_paths`, `current_action_moves_settlement?`, or `FIXED_SOUND_KEYS`, that means a partial or test still uses them — fix in place by either removing the usage (next task handles the partials) or reverting only the portion of this task that breaks things and re-ordering work.

- [ ] **Step 4: Commit**

```bash
git add app/helpers/games_helper.rb
git commit -m "Reduce GamesHelper to a single sound_paths method"
```

---

### Task 6: Simplify `show.html.erb` sound-config div

**Files:**
- Modify: `app/views/games/show.html.erb`

- [ ] **Step 1: Replace the sound-config block**

In `app/views/games/show.html.erb`, replace lines 8-11:

```erb
<div id="sound-config"
     data-sound-preload="<%= sound_preload_keys(game).to_json %>"
     data-sound-paths="<%= sound_asset_paths(sound_preload_keys(game)).to_json %>"
     hidden></div>
```

with:

```erb
<div id="sound-config" data-sound-paths="<%= sound_paths.to_json %>" hidden></div>
```

- [ ] **Step 2: Sanity-check**

Run: `bin/rails test`
Expected: green.

- [ ] **Step 3: Commit**

```bash
git add app/views/games/show.html.erb
git commit -m "Simplify sound-config to use unified sound_paths"
```

---

### Task 7: Strip sound-only data attributes from partials

**Files:**
- Modify: `app/views/games/_tiles.html.erb`
- Modify: `app/views/games/_end_turn.html.erb`
- Modify: `app/views/games/_turn_state.html.erb`

- [ ] **Step 1: Remove `data-tile-count` from `_tiles.html.erb`**

In `app/views/games/_tiles.html.erb`:

- Line 3: change `<div class="player-tiles" data-tile-count="<%= regular_tiles.size %>">` to `<div class="player-tiles">`
- Line 29: change `<div class="player-tiles nomad-tiles" data-tile-count="<%= nomad_tiles.size %>">` to `<div class="player-tiles nomad-tiles">`

- [ ] **Step 2: Remove `#my-turn-flag` from `_end_turn.html.erb`**

Open `app/views/games/_end_turn.html.erb` and delete line 2:

```erb
<span id="my-turn-flag" data-my-turn="<%= my_turn %>" hidden></span>
```

The `my_turn` local is still used on line 3/5 for conditional button rendering, so keep the `local_assigns.fetch` line.

- [ ] **Step 3: Remove `data-moves-settlement` from `_turn_state.html.erb`**

In `app/views/games/_turn_state.html.erb`, line 4-8 currently reads:

```erb
<span id="current-action"
  data-type="<%= game.current_action&.dig('type') %>"
  data-from="<%= game.current_action&.dig('from') %>"
  data-buildable="<%= engine.buildable_cells.to_json %>"
  data-moves-settlement="<%= current_action_moves_settlement?(game) %>">
</span>
```

Change to:

```erb
<span id="current-action"
  data-type="<%= game.current_action&.dig('type') %>"
  data-from="<%= game.current_action&.dig('from') %>"
  data-buildable="<%= engine.buildable_cells.to_json %>">
</span>
```

- [ ] **Step 4: Verify view tests**

Run: `bin/rails test`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add app/views/games/_tiles.html.erb app/views/games/_end_turn.html.erb app/views/games/_turn_state.html.erb
git commit -m "Remove sound-only data attributes from partials"
```

---

### Task 8: Rewrite `app/javascript/sound.js`

**Files:**
- Modify: `app/javascript/sound.js`

- [ ] **Step 1: Replace file contents**

Overwrite `app/javascript/sound.js` with:

```javascript
// sound.js — loaded as a classic script before gameboard.js
// Exposes SoundManager as a global and registers the play_sound Turbo Stream action.
var SoundManager = (() => {
  const MUTE_KEY   = "kbc_muted";
  const VOLUME_KEY = "kbc_volume";

  let sounds = {};
  let muted  = false;
  let volume = 1.0;
  let ready  = false;

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

    const paths = JSON.parse(config.dataset.soundPaths || "{}");
    Object.entries(paths).forEach(([k, p]) => {
      const audio = new Audio(p);
      audio.preload = "auto";
      sounds[k] = audio;
    });

    volume = parseFloat(localStorage.getItem(VOLUME_KEY) ?? "1");
    muted  = localStorage.getItem(MUTE_KEY) === "true";
    applyVolumeAll();

    // Unlock audio on first user gesture (autoplay policy).
    const unlock = () => {
      Object.values(sounds).forEach(audio => {
        audio.volume = 0;
        audio.play().catch(() => {});
      });
      document.getElementById("audio-unlock-prompt")?.remove();
      ["click", "keydown", "pointerdown"].forEach(ev =>
        document.removeEventListener(ev, unlock, true));
    };
    ["click", "keydown", "pointerdown"].forEach(ev =>
      document.addEventListener(ev, unlock, true));
  }

  function play(name) {
    const audio = sounds[name];
    if (!audio) return;
    audio.currentTime = 0;
    applyVolume(audio);
    audio.play().catch(() => {});
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

  return {
    init, play, setVolume, toggleMute,
    isMuted: () => muted,
    getVolume: () => volume
  };
})();

Turbo.StreamActions.play_sound = function () {
  SoundManager.play(this.getAttribute("key"));
};
```

- [ ] **Step 2: Smoke-test the file loads**

Run: `bin/rails test`
Expected: green (no change in Ruby tests, but verifies nothing else broke).

- [ ] **Step 3: Commit**

```bash
git add app/javascript/sound.js
git commit -m "Rewrite sound.js around single play_sound Turbo action"
```

---

### Task 9: Strip click and diff sound logic from `gameboard.js`

**Files:**
- Modify: `app/javascript/gameboard.js`

- [ ] **Step 1: Replace `enableClicks` (drop sound branches)**

Change `enableClicks` to:

```javascript
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

- [ ] **Step 2: Replace the stream-listener block**

Find the block starting with `// Re-mark selectable hexes after Turbo Stream updates.` and ending at the close of the `document.addEventListener("turbo:before-stream-render", ...)` handler. Delete:

- the `streamSnapshotPending`, `streamSnapshot`, `gameEndSoundPlayed`, `undoPending` state
- the `captureStreamSnapshot` function
- the `triggerStreamSounds` function
- the existing `turbo:before-stream-render` handler

Replace with:

```javascript
// Re-mark selectable hexes after Turbo Stream updates.
// The 50ms debounce ensures prepForMove runs once after all streams have settled.
let prepDebounceTimer = null;
document.addEventListener("turbo:before-stream-render", () => {
  clearTimeout(prepDebounceTimer);
  prepDebounceTimer = setTimeout(prepForMove, 50);
});
```

- [ ] **Step 3: Simplify `initSoundTriggers` to volume/mute UI only**

Replace `initSoundTriggers` with:

```javascript
function initSoundTriggers() {
  SoundManager.init();

  // Mute toggle
  document.getElementById("mute-btn")?.addEventListener("click", () => {
    const nowMuted = SoundManager.toggleMute();
    const btn = document.getElementById("mute-btn");
    if (btn) {
      btn.innerHTML = nowMuted ? "&#128264;" : "&#128266;";
      btn.classList.toggle("muted", nowMuted);
    }
  });

  // Volume slider
  document.getElementById("volume-slider")?.addEventListener("input", (e) => {
    SoundManager.setVolume(e.target.value);
  });

  // Restore volume control UI state from localStorage
  const slider  = document.getElementById("volume-slider");
  const muteBtn = document.getElementById("mute-btn");
  if (slider) slider.value = SoundManager.getVolume();
  if (muteBtn) {
    muteBtn.innerHTML = SoundManager.isMuted() ? "&#128264;" : "&#128266;";
    muteBtn.classList.toggle("muted", SoundManager.isMuted());
  }
}
```

- [ ] **Step 4: Verify file ends with the same init calls at the bottom**

The last 8 lines of `gameboard.js` should remain:

```javascript
// prepare for the first move
prepForMove();
// set up click targets
enableClicks();
// set up board zoom
initBoardZoom();
// set up sound triggers
initSoundTriggers();
```

- [ ] **Step 5: Run tests to make sure nothing else broke**

Run: `bin/rails test`
Expected: green.

- [ ] **Step 6: Commit**

```bash
git add app/javascript/gameboard.js
git commit -m "Remove click and diff sound logic from gameboard.js"
```

---

### Task 10: Delete `my_turn.ogg` and add `wall.ogg`

**Files:**
- Delete: `app/assets/sounds/my_turn.ogg`
- Add: `app/assets/sounds/wall.ogg` (user-supplied)

- [ ] **Step 1: Delete `my_turn.ogg`**

```bash
git rm app/assets/sounds/my_turn.ogg
```

- [ ] **Step 2: Add `wall.ogg`**

Ask the user for the `wall.ogg` asset and place it at `app/assets/sounds/wall.ogg`.

- [ ] **Step 3: Stage and commit**

```bash
git add app/assets/sounds/wall.ogg
git commit -m "Drop my_turn.ogg, add wall.ogg"
```

---

### Task 11: Full manual smoke test in the browser

**Files:** none

- [ ] **Step 1: Start the server**

Run: `make up`

- [ ] **Step 2: Open two browser windows as two different users in the same game**

- [ ] **Step 3: Verify same sounds play in both windows**

Perform each of these actions in one window; confirm the other window hears the same sound:

- Build a settlement → both hear `build`
- Pick up a tile (by building adjacent to a location hex) → both hear `tile_pickup` after `build`
- End turn → both hear `end_turn`
- Activate a tile with a click (e.g., Paddock) → both hear the tile's sound (`paddock`)
- Select a settlement for move → both hear `select_settlement`
- Move the settlement → both hear `move`
- Undo → both hear `undo`
- Forfeit a tile (by moving a settlement away) → both hear `tile_forfeit`
- Place a wall (if a quarry is in play) → both hear `wall`
- Remove a settlement (sword tile) → both hear `removed`
- Activate outpost → both hear `outpost`
- Trigger a game end → both hear `game_end`

- [ ] **Step 4: Verify no `my_turn` sound plays for anyone, ever**

- [ ] **Step 5: Verify mute and volume still work in one window without affecting the other**

- [ ] **Step 6: Shut down the server**

Run: `make down`

- [ ] **Step 7: If all verified, commit any trailing changes or note "manual smoke test passed" in the PR description**

No commit needed if nothing changed.

---

### Task 12: Final sweep — dead code / leftover references

**Files:** varies

- [ ] **Step 1: Search for any lingering references to removed symbols**

Run each:

```bash
grep -rn "sound_preload_keys\|sound_asset_paths\|current_action_moves_settlement\|FIXED_SOUND_KEYS" app test
grep -rn "my-turn-flag\|my_turn\.ogg\|data-moves-settlement\|data-tile-count\|data-sound-preload" app test
grep -rn "playAfterLast\|triggerStreamSounds\|captureStreamSnapshot\|streamSnapshot\|gameEndSoundPlayed\|undoPending" app
```

Expected: no results. (Exception: `docs/superpowers/` will still reference old concepts in the prior sound spec — leave those files alone; they're historical.)

- [ ] **Step 2: Fix anything that surfaces**

Remove the dead reference. If a partial or test still uses it, update it to match the new architecture. Commit each fix separately with a descriptive message.

- [ ] **Step 3: Run full test suite one more time**

Run: `bin/rails test && bin/rubocop`
Expected: all green.

- [ ] **Step 4: Push the branch**

```bash
git push -u origin fix-sound-targeting
```

(Do not open the PR from here — the user will do that, or request it explicitly.)
