var gameId = null;

function sayHey() {
  console.log("Hey!");
}

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
      document.getElementById("build_cell").value = e.target.id;
      document.getElementById("build_form").submit();


      // setGameId();
      // const cellId = e.target.id;
      // console.log("Click target: " + cellId);
      // e.preventDefault();
      // const promise = fetch(
      //   "/games/" + gameId + "/build.json",
      //   {
      //     method: "POST",
      //     headers: {
      //       "Content-Type": "application/json",
      //       "X-CSRF-TOKEN": document.querySelector("meta[name='csrf-token']").content
      //     },
      //     body: JSON.stringify({ target: cellId })
      //   }
      // ).then(response => response.json())
      //   .then(result => handleBuildResult(result))
      //   .catch(error => console.log("BUILD ERROR: " + JSON.stringify(error)));
    });
}

function handleBuildResult(result) {
  location.reload();
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
  // set up click event
  enableClicks();
}

loaded();
