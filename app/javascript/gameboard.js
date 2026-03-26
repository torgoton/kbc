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
      document.getElementById("build_cell").value = hex.id;
      document.getElementById("action_submit").click();
    });
}

function settlements_left() {
  return Number(document.querySelector("span.settlement-count").innerText);
}

function adjacent_list(cell_id) {
  let candidates = [];
  const ADJACENCIES = [ [ [ 0, -1 ], [ 0, 1 ], [ -1, -1 ], [ -1, 0 ], [ 1, -1 ], [ 1, 0 ] ],
                        [ [ 0, -1 ], [ 0, 1 ], [ -1,  0 ], [ -1, 1 ], [ 1,  0 ], [ 1, 1 ] ] ]

  const row = Number(cell_id.split("-")[2]);
  const col = Number(cell_id.split("-")[3]);

  ADJACENCIES[row % 2].forEach(a => {
    const adj_row = row + a[0];
    const adj_col = col + a[1];
    if (adj_row >= 0 && adj_row <= 19 && adj_col >= 0 && adj_col <= 19) {
      candidates.push("map-cell-" + adj_row + "-" + adj_col);
    }
  });
  return candidates;
}

function unmarkAvailableCells() {
  document.querySelectorAll(".hex").forEach(c => {
    c.classList.remove("selectable");
    c.classList.remove("selected");
  });
}

function cellKeyToCellId(key) {
  const parts = key.replace(/[\[\] ]/g, "").split(",");
  return `map-cell-${parts[0]}-${parts[1]}`;
}

function paddockDestinations(cellId) {
  const BUILDABLE = ["terrain-c", "terrain-d", "terrain-f", "terrain-t", "terrain-g"];
  // Each entry is [even_row_step, odd_row_step] for one of the 6 straight-line directions.
  const STRAIGHT_LINES = [
    [ [0, -1], [0, -1] ],   // W
    [ [0,  1], [0,  1] ],   // E
    [ [-1, -1], [-1, 0] ],  // NW
    [ [-1,  0], [-1, 1] ],  // NE
    [ [1, -1],  [1, 0] ],   // SW
    [ [1,  0],  [1, 1] ]    // SE
  ];
  const row = Number(cellId.split("-")[2]);
  const col = Number(cellId.split("-")[3]);
  const results = [];
  STRAIGHT_LINES.forEach(steps => {
    const [dr1, dc1] = steps[row % 2];
    const r1 = row + dr1, c1 = col + dc1;
    if (r1 < 0 || r1 > 19 || c1 < 0 || c1 > 19) return;
    const [dr2, dc2] = steps[r1 % 2];
    const r2 = r1 + dr2, c2 = c1 + dc2;
    if (r2 < 0 || r2 > 19 || c2 < 0 || c2 > 19) return;
    const id = `map-cell-${r2}-${c2}`;
    const cell = document.getElementById(id);
    if (!cell) return;
    if (cell.querySelector(".hex-settlement")) return;
    if (BUILDABLE.some(cls => cell.classList.contains(cls))) results.push(id);
  });
  return results;
}

function markSelectableSettlements() {
  const playerNo = parseInt(document.querySelector(".handle .player-order").innerText);
  document.querySelectorAll(`.hex-settlement.player-${playerNo}`).forEach(s => {
    const cell = s.closest(".hex");
    if (!cell) return;
    if (paddockDestinations(cell.id).length > 0) {
      cell.classList.add("selectable");
    }
  });
}

function markPaddockDestinations(from) {
  const fromCell = document.getElementById(from);
  if (fromCell) fromCell.classList.add("selected");
  paddockDestinations(from).forEach(id => {
    const cell = document.getElementById(id);
    if (cell) cell.classList.add("selectable");
  });
}

function markOasisDestinations() {
  const playerNo = parseInt(document.querySelector(".handle .player-order").innerText);
  let found = false;

  document.querySelectorAll(`.hex-settlement.player-${playerNo}`).forEach(s => {
    const cell = s.closest(".hex");
    if (!cell) return;
    adjacent_list(cell.id).forEach(adjId => {
      const adjCell = document.getElementById(adjId);
      if (!adjCell || adjCell.querySelector(".hex-settlement")) return;
      if (adjCell.classList.contains("terrain-d")) {
        adjCell.classList.add("selectable");
        found = true;
      }
    });
  });

  if (found) return;

  document.querySelectorAll(".terrain-d").forEach(c => {
    if (!c.querySelector(".hex-settlement")) {
      c.classList.add("selectable");
    }
  });
}

function markAvailableCells() {
  card = document.querySelector("span.player-card").innerText.toLowerCase();
  player_no = parseInt(document.querySelector(".handle .player-order").innerText);
  mandatory_element = document.querySelector("span.mandatory-count");
  if (mandatory_element) {
    mandatory_count = parseInt(mandatory_element.innerText);
  } else {
    mandatory_count = 0;
  }
  any_near_me = false;
  // mark the available cells
  // if it's my turn - it always is
  // and I have any settlements left
  // and I have any moves left
  if (settlements_left() > 0 && mandatory_count > 0) {
    // find all my settlements
    my_settlements = document.querySelectorAll(".hex-settlement.player-" + player_no);
    // If I have any on the board
    if (my_settlements.length != 0)  {
      // I do have some settlements
      // mark cells selectable
      // if they are adjacent to my settlements
      // and do not have a settlement
      // and have the terrain type of the card
      my_settlements.forEach(s => {
        // get the cell id of the settlement
        const cell_id = s.parentElement.parentElement.id;
        // get the adjacent cells
        const adjacents = adjacent_list(cell_id);
        adjacents.forEach(a => {
          c = document.getElementById(a);
          // if it does not have a settlement
          if (!c.querySelector(".hex-settlement")) {
            // and has the terrain type of the card
            if (c.classList.contains("terrain-" + card)) {
              // mark it selectable
              c.classList.add("selectable");
              any_near_me = true;
            }
          }
        });
      });
    }
    if (!any_near_me) {
      // find all cells with the terrain type of the card
      document.querySelectorAll(".terrain-" + card).forEach(c => {
        // if it does not have a settlement
        if (!c.querySelector(".hex-settlement")) {
          // mark it selectable
          c.classList.add("selectable");
        }
      });
    }
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

function prepForMove() {
  console.log("Is it my turn?");
  unmarkAvailableCells();
  if (!document.querySelector(".handle.my-turn")) {
    console.log(" - nope");
    return;
  }
  console.log("It's my turn!");
  const actionEl = document.getElementById("current-action");
  const actionType = actionEl ? actionEl.dataset.type : "mandatory";
  const actionFrom = actionEl ? actionEl.dataset.from : null;

  if (actionType === "paddock") {
    if (actionFrom) {
      markPaddockDestinations(cellKeyToCellId(actionFrom));
    } else {
      markSelectableSettlements();
    }
  } else if (actionType === "oasis") {
    markOasisDestinations();
  } else {
    markAvailableCells();
  }
}

// set up polling for updates
setupPolling();
// prepare for the first move
prepForMove();
// set up click targets
enableClicks();
