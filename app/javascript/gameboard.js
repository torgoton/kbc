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

function unmarkAvailableCells() {
  document.querySelectorAll(".hex").forEach(c => {
    c.classList.remove("selectable");
    c.classList.remove("selected");
  });
}

function prepForMove() {
  unmarkAvailableCells();
  const myTurnFlag = document.getElementById("my-turn-flag");
  if (!myTurnFlag || myTurnFlag.dataset.myTurn !== "true") return;
  const actionEl = document.getElementById("current-action");
  if (!actionEl) return;

  const buildable = JSON.parse(actionEl.dataset.buildable || "[]");
  buildable.forEach(([r, c]) => {
    document.getElementById(`map-cell-${r}-${c}`)?.classList.add("selectable");
  });

  if (actionEl.dataset.from) {
    const parts = actionEl.dataset.from.replace(/[\[\] ]/g, "").split(",");
    document.getElementById(`map-cell-${parts[0].trim()}-${parts[1].trim()}`)?.classList.add("selected");
  }
}

function initBoardZoom() {
  const viewport = document.getElementById("board-viewport");
  const board = document.getElementById("board");
  if (!viewport || !board) return;

  let scale = 1, tx = 0, ty = 0, minScale = 0.2;
  const pad = 12, padTop = 4;

  function applyTransform() {
    board.style.transform = `translate(${tx}px, ${ty}px) scale(${scale})`;
  }

  function clampTranslation(newTx, newTy, newScale) {
    const vpW = viewport.clientWidth;
    const vpH = viewport.clientHeight;
    const scaledW = board.offsetWidth * newScale;
    const scaledH = board.offsetHeight * newScale;
    // When zoomed in (board larger than viewport), prevent panning past edges.
    // When at minScale (board smaller in one dimension), snap to padded position.
    const clampedTx = scaledW >= vpW
      ? Math.min(0, Math.max(vpW - scaledW, newTx))
      : (vpW - scaledW) / 2;
    const clampedTy = scaledH >= vpH
      ? Math.min(0, Math.max(vpH - scaledH, newTy))
      : padTop;
    return [clampedTx, clampedTy];
  }

  function fitBoard() {
    const vpW = viewport.clientWidth;
    const vpH = viewport.clientHeight;
    const bW = board.offsetWidth;
    const bH = board.offsetHeight;
    if (!bW || !bH) return;
    scale = Math.min((vpW - pad * 2) / bW, (vpH - padTop - pad) / bH);
    minScale = scale;
    [tx, ty] = clampTranslation(0, 0, scale);
    applyTransform();
  }

  let dragging = false, hasDragged = false, dragX = 0, dragY = 0;

  viewport.addEventListener("mousedown", (e) => {
    if (e.button !== 0) return;
    dragging = true;
    hasDragged = false;
    dragX = e.clientX;
    dragY = e.clientY;
    viewport.classList.add("grabbing");
    e.preventDefault();
  });

  window.addEventListener("mousemove", (e) => {
    if (!dragging) return;
    const dx = e.clientX - dragX;
    const dy = e.clientY - dragY;
    dragX = e.clientX;
    dragY = e.clientY;
    if (Math.abs(dx) > 2 || Math.abs(dy) > 2) hasDragged = true;
    [tx, ty] = clampTranslation(tx + dx, ty + dy, scale);
    applyTransform();
  });

  window.addEventListener("mouseup", () => {
    dragging = false;
    viewport.classList.remove("grabbing");
  });

  // Suppress hex clicks that are actually the end of a drag.
  // Capture phase ensures this runs before enableClicks()'s listener.
  viewport.addEventListener("click", (e) => {
    if (hasDragged) {
      e.stopPropagation();
      hasDragged = false;
    }
  }, true);

  viewport.addEventListener("wheel", (e) => {
    e.preventDefault();
    const rect = viewport.getBoundingClientRect();
    const cx = e.clientX - rect.left;
    const cy = e.clientY - rect.top;
    const factor = e.deltaY < 0 ? 1.1 : 1 / 1.1;
    const newScale = Math.max(minScale, Math.min(5, scale * factor));
    const newTx = cx - (newScale / scale) * (cx - tx);
    const newTy = cy - (newScale / scale) * (cy - ty);
    [tx, ty] = clampTranslation(newTx, newTy, newScale);
    scale = newScale;
    applyTransform();
  }, { passive: false });

  requestAnimationFrame(fitBoard);
}

// Re-mark selectable hexes after Turbo Stream updates.
// turbo:before-stream-render fires before each action is applied; the 50ms
// debounce ensures prepForMove runs once after all streams have settled.
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
  if (countAfter > countBefore) SoundManager.playAfterLast("tile_pickup");
  if (countAfter < countBefore) SoundManager.playAfterLast("tile_forfeit");

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

function initSoundTriggers() {
  SoundManager.init();

  // End turn — delegate from turn-state bar (stable ancestor)
  document.getElementById("turn-state-bar")?.addEventListener("click", (e) => {
    if (e.target.closest("#end-turn-area button, #end-turn-area [type='submit']")) {
      SoundManager.play("end_turn");
    }
  });

  // Undo and tile selection — delegate from players-area (stable ancestor)
  document.getElementById("players-area")?.addEventListener("click", (e) => {
    if (e.target.closest(".undo-btn")) { SoundManager.play("undo"); return; }
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

// prepare for the first move
prepForMove();
// set up click targets
enableClicks();
// set up board zoom
initBoardZoom();
// set up sound triggers
initSoundTriggers();
