var gameId = null;

function setGameId() {
  href = location.href;
  gameId = href.substring(href.indexOf("games/") + 6);
}

function highlightTerrain(card) {
  document.querySelectorAll(".grid-item").forEach(c => {
    c.classList.remove("selectable");
  });
  document.querySelectorAll(".terrain-" + card).forEach(c => {
    c.classList.add("selectable");
  });
}

function enableClicks() {
  document.querySelector("#board").
    addEventListener("click", function (e) {
      const selectable = e.target.classList.contains("selectable");
      if (!selectable) {
        console.log("click not OK here");
        return;
      }
      console.log("Click target: " + e.target.id);
      e.preventDefault();
      document.getElementById("build_cell").value = e.target.parentElement.parentElement.id;
      document.getElementById("build_form").submit();
    });
}

function handleBuildResult(result) {
  location.reload();
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

function mark_available_cells() {
  // remove all selectable classes
  document.querySelectorAll(".cell-content").forEach(c => {
    c.classList.remove("selectable");
  });
  card = document.querySelector("span.player-card").innerText.toLowerCase();
  player_no = Number(document.querySelector(".handle .player-order").innerText);
  // mark the available cells
  // if it's my turn - it always is
  // and I have any settlements left
  // and I have any moves left
  if (settlements_left() > 0) {
    // find all my settlements
    my_settlements = document.querySelectorAll(".hex-settlement.player-" + player_no);
    // If I have none on the board
    if (my_settlements.length === 0) {
      // find all cells with the terrain type of the card
      document.querySelectorAll(".terrain-" + card).forEach(c => {
        // if it does not have a settlement
        if (!c.querySelector(".hex-settlement")) {
          // mark it selectable
          c.querySelector(".cell-content").classList.add("selectable");
        }
      });
    } else {
      // I do have some settlements
      // mark cells selectable
      // if they are adjacent to my settlements
      // and do not have a settlement
      // and have the terrain type of the card
      my_settlements.forEach(s => {
        // get the cell id of the settlement
        const cell_id = s.parentElement.parentElement.parentElement.id;
        // get the adjacent cells
        const adjacents = adjacent_list(cell_id);
        adjacents.forEach(a => {
          c = document.getElementById(a);
          // if it does not have a settlement
          if (!c.querySelector(".hex-settlement")) {
            // and has the terrain type of the card
            if (c.querySelector(".terrain-" + card)) {
              // mark it selectable
              c.querySelector(".cell-content").classList.add("selectable");
            }
          }
        });
      });
    }
  }
}

function loaded() {
  // is it my turn?
  console.log("Is it my turn?");
  if (!document.querySelector(".handle.my-turn")) {
    // no, quit
    console.log(" - nope");
    return;
  };
  console.log("It's my turn!");
  // show selectable cells
  mark_available_cells();
  // set up click event
  enableClicks();
}

loaded();
