export const KBC = {
    setup: () => ({ cells: Array(9).fill(null) }),

    // KBC setup
    // 1. select 4 (of 8) game board sections and assemble into
    //    a rectangular game board
    // 2. place Location Tiles on each Location Hex
    // 3. shuffle (25) terrain cards into a deck
    // 4. select 3 (of 9) Goal cards for scoring
    // 5. give each player 40 settlements and 0 points
    // 6. deal each player 1 terrain card
    // 7. select start player

    moves: {
      clickCell: ({ G, playerID }, id) => {
        G.cells[id] = playerID;
      },
    },

    // Turn sequence
    // 1. display current terrain card
    // 2. set each Extra tile to unused.
    // 3. take actions in any order
    //   a. Mandatory Action
    //      Place 3 settlements according to placement rules
    //   b. Extra Actions
    //      Each earned action tile allows you to perform that
    //      action once per turn.
    // 4. discard terrain card and draw one from the deck

    // After each turn
    // 1. first player to empty their supply of settlements triggers
    //    end of game - game ends at end of "last" player's turn
    // 2. If deck is empty, shuffle discards into a new deck

    // End of game
    // Score castles and each goal card
    // High score wins - ties share victory
  };
