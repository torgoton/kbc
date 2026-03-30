var gameId = null;
var myLastUpdatedAt = null;

function setGameId() {
  href = location.href;
  gameId = href.substring(href.indexOf("games/") + 6);
}

function highlightTerrain(card) {
  document.querySelectorAll(".hex").forEach(c => {
    c.classList.remove("selectable");
  });
  document.querySelectorAll(".terrain-" + card).forEach(c => {
    c.classList.add("selectable");
  });
}

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

function settlements_left() {
  return Number(document.querySelector("span.settlement-count").innerText);
}

function unmarkAvailableCells() {
  document.querySelectorAll(".hex").forEach(c => {
    c.classList.remove("selectable");
    c.classList.remove("selected");
  });
}

function prepForMove() {
  console.log("Is it my turn?");
  unmarkAvailableCells();
  if (!document.querySelector(".handle.my-turn")) {
    console.log(" - nope");
    return;
  }
  console.log("It's my turn!");
  const actionEl = document.getElementById("current-action");
  if (!actionEl) return;

  const buildable = JSON.parse(actionEl.dataset.buildable || "[]");
  buildable.forEach(([r, c]) => {
    document.getElementById(`map-cell-${r}-${c}`)?.classList.add("selectable");
  });

  if (actionEl.dataset.type === "paddock" && actionEl.dataset.from) {
    const parts = actionEl.dataset.from.replace(/[\[\] ]/g, "").split(",");
    document.getElementById(`map-cell-${parts[0].trim()}-${parts[1].trim()}`)?.classList.add("selected");
  }
}

function setupPolling() {
  // set up polling for updates
  setInterval(function () {
    // get the last updated at time
    const last_updated_at = document.querySelector("#last-updated-at").innerText;
    // if it's not the same as mine
    if (myLastUpdatedAt != last_updated_at) {
      // update my last updated at time
      myLastUpdatedAt = last_updated_at;
      console.log("UPDATE CHECK " + last_updated_at + " change detected");
      prepForMove();
    }
  }, 1000);
}

// Seed last-updated-at so the first poll tick doesn't trigger a spurious prepForMove
myLastUpdatedAt = document.querySelector("#last-updated-at")?.innerText ?? null;
// set up polling for updates
setupPolling();
// prepare for the first move
prepForMove();
// set up click targets
enableClicks();
