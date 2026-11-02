function enableClicks() {
  document.querySelector("#board").
    addEventListener("click", function (e) {
      const myTurnFlag = document.getElementById("my-turn-flag");
      if (!myTurnFlag || myTurnFlag.dataset.myTurn !== "true") return;
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

function unmarkAvailableCells() {
  document.querySelectorAll(".hex").forEach(c => {
    c.classList.remove("selectable");
    c.classList.remove("selected");
  });
}

function prepForMove() {
  unmarkAvailableCells();
  // All viewers see selectable/selected hexes so observers can follow the
  // active player's move; clicking is gated to the current player in enableClicks.
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

  if (actionEl.dataset.type === "cityhall") {
    const clusters = JSON.parse(actionEl.dataset.clusters || "{}");
    buildable.forEach(([r, c]) => {
      const hex = document.getElementById(`map-cell-${r}-${c}`);
      if (!hex) return;
      hex.addEventListener("mouseenter", () => {
        const key = `${r},${c}`;
        (clusters[key] || []).forEach(([hr, hc]) => {
          document.getElementById(`map-cell-${hr}-${hc}`)?.classList.add("city-hall-preview");
        });
      });
      hex.addEventListener("mouseleave", () => {
        document.querySelectorAll(".city-hall-preview").forEach(el => el.classList.remove("city-hall-preview"));
      });
    });
  }
}

// The pull-tab swaps the sidebars with the Island. The tab itself is re-rendered by broadcasts,
// so listen on the document.
function initIslandTab() {
  function toggle() {
    const area = document.getElementById("game-area");
    const tab = document.getElementById("island-tab");
    if (!area || !tab) return;
    const on = area.classList.toggle("island-view");
    tab.setAttribute("aria-pressed", on);
    document.getElementById("board-viewport")?.dispatchEvent(new CustomEvent("island-view", { detail: { on } }));
  }
  document.addEventListener("click", (e) => { if (e.target.closest("#island-tab")) toggle(); });
  document.addEventListener("keydown", (e) => {
    if (e.key.toLowerCase() === "i" && !e.ctrlKey && !e.metaKey && !e.altKey && !/^(INPUT|TEXTAREA)$/.test(e.target.tagName)) toggle();
  });
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

  // The viewport spans the whole game area (the Island sits under the sidebars); `main` is the
  // part the map itself is fitted to.
  const main = viewport.parentElement;

  // Map plus Island, unscaled.
  function extentWidth() {
    const island = document.getElementById("island");
    return island ? island.offsetLeft + island.offsetWidth : board.offsetWidth;
  }

  function clampTranslation(newTx, newTy, newScale) {
    const vpW = viewport.clientWidth;
    const vpH = viewport.clientHeight;
    const mapW = board.offsetWidth * newScale;
    const scaledW = extentWidth() * newScale;
    const scaledH = board.offsetHeight * newScale;
    // A map narrower than its column is centred in it; wider, pan within map + Island.
    const clampedTx = mapW < main.clientWidth
      ? (main.clientWidth - mapW) / 2
      : Math.min(0, Math.max(vpW - scaledW, newTx));
    const clampedTy = scaledH >= vpH
      ? Math.min(0, Math.max(vpH - scaledH, newTy))
      : padTop;
    return [clampedTx, clampedTy];
  }

  function fitBoard() {
    const mainW = main.clientWidth;
    const vpH = viewport.clientHeight;
    const bW = board.offsetWidth;
    const bH = board.offsetHeight;
    if (!bW || !bH) return;
    scale = Math.min((mainW - pad * 2) / bW, (vpH - padTop - pad) / bH);
    minScale = scale;
    [tx, ty] = clampTranslation(0, 0, scale);
    applyTransform();
  }

  // Island view: the sidebars slide left and uncover the Island, so centre it in the strip
  // they left free. Leaving restores wherever the map was.
  let mapView = null;
  viewport.addEventListener("island-view", (e) => {
    const island = document.getElementById("island");
    if (!island) return;
    board.style.transition = "transform 0.35s ease";
    setTimeout(() => { board.style.transition = ""; }, 400);
    if (e.detail.on) {
      mapView = { tx, ty, scale };
      const vp = viewport.getBoundingClientRect();
      const box = island.getBoundingClientRect();
      const stripCentre = (viewport.clientWidth + (viewport.clientWidth - main.clientWidth)) / 2;
      const [cx, cy] = [(box.left - vp.left - tx + box.width / 2) / scale, (box.top - vp.top - ty + box.height / 2) / scale];
      [tx, ty] = clampTranslation(stripCentre - cx * scale, viewport.clientHeight / 2 - cy * scale, scale);
    } else if (mapView) {
      ({ scale } = mapView);
      [tx, ty] = clampTranslation(mapView.tx, mapView.ty, scale);
    }
    applyTransform();
  });

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

  fitBoard();
  // On first load (especially via Turbo nav), the sync fitBoard call above
  // can read viewport dimensions before layout has fully settled. Re-fit
  // after the next frame to pick up correct measurements.
  requestAnimationFrame(fitBoard);
  new ResizeObserver(fitBoard).observe(viewport);
}

// Re-mark selectable hexes after Turbo Stream updates.
// The 50ms debounce ensures prepForMove runs once after all streams have settled.
var prepDebounceTimer = null;
document.addEventListener("turbo:before-stream-render", () => {
  clearTimeout(prepDebounceTimer);
  prepDebounceTimer = setTimeout(prepForMove, 50);
});

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

// prepare for the first move
prepForMove();
// set up click targets
enableClicks();
// set up board zoom
initBoardZoom();
if (!window.islandTabBound) { window.islandTabBound = true; initIslandTab(); }
// set up sound triggers
initSoundTriggers();
