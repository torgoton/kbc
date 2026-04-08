function enableClicks() {
  document.querySelector("#board").
    addEventListener("click", function (e) {
      const hex = e.target.closest(".hex");
      if (!hex || !hex.classList.contains("selectable")) {
        // console.log("click not OK here");
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

// Re-mark selectable hexes after Turbo Stream updates.
// turbo:before-stream-render fires before each action is applied; the 50ms
// debounce ensures prepForMove runs once after all streams have settled.
let prepDebounceTimer = null;
document.addEventListener("turbo:before-stream-render", () => {
  clearTimeout(prepDebounceTimer);
  prepDebounceTimer = setTimeout(prepForMove, 50);
});

// prepare for the first move
prepForMove();
// set up click targets
enableClicks();
