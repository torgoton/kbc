require "test_helper"
require "turbo/broadcastable/test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  setup do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
  end

  test "hexes adjacent to a warrior render with the warrior-blocked class" do
    game = games(:game2player)
    game.board_contents = BoardState.new.tap { |s| s.place_warrior(5, 4, 0) }
    game.save!

    get game_url(game)

    assert_select "#map-cell-5-5.warrior-blocked"
    assert_select "#map-cell-0-0.warrior-blocked", count: 0
  end

  test "game show includes a tile element for the mandatory action" do
    game = games(:game2player)
    chris = game_players(:chris)
    chris.tiles = [ { "klass" => "MandatoryTile", "used" => false } ]
    chris.save

    get game_url(game)

    assert_select ".tile-container.mandatory"
  end

  test "mandatory tile renders as tile-used when the turn is endable" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.mandatory_count = 0
    game.save
    chris.tiles = [ { "klass" => "MandatoryTile", "used" => false } ]
    chris.save

    get game_url(game)

    assert_select ".player-tile.tile-used .tile-container.mandatory"
  end

  test "mandatory tile does not render as tile-used when mandatory builds remain" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.mandatory_count = 3
    game.save
    chris.tiles = [ { "klass" => "MandatoryTile", "used" => false } ]
    chris.save

    get game_url(game)

    assert_select ".player-tile.tile-used .tile-container.mandatory", count: 0
  end

  test "game show renders a system log entry (no game_player) as a system move" do
    game = games(:game2player)
    game.moves.create!(game_player: nil, action: "end_game", message: "Game ended.", order: 1)

    get game_url(game)

    assert_select ".move.system", text: "Game ended."
  end

  test "the current player's active tile shows as tile-active to other players" do
    # paula_turn_game: paula is the current player; chris (logged in) is watching.
    game = games(:paula_turn_game)
    game.update!(current_action: { "type" => "farm" })
    game_players(:paula_in_paula_turn_game).update!(tiles: [ { "klass" => "FarmTile", "used" => false } ])
    game_players(:chris_in_paula_turn_game).update!(tiles: [ { "klass" => "FarmTile", "used" => false } ])

    get game_url(game)

    # Only the current player's (paula's) farm tile is active, not the observer's own.
    assert_select ".player-tile.tile-active .tile-container.farm", count: 1
  end

  test "observer viewing a game they're not in only sees the current player's terrain card" do
    # chris is logged in but is not a player in paula_jules_game.
    game = games(:paula_jules_game)
    paula = game_players(:paula_in_paula_jules_game)
    jules = game_players(:jules_in_paula_jules_game)
    paula.update!(hand: [ "D" ])
    jules.update!(hand: [ "M" ])
    game.update!(current_player: jules)

    get game_url(game)

    # jules is the current player: their card is publicly displayed per the rules.
    assert_select ".player-card.card-M"
    # paula is not the current player and chris is not paula: her card must stay hidden.
    assert_select ".player-card.card-D", count: 0
  end

  test "select_action sets current_action type on the game" do
    game = games(:game2player)
    post select_action_game_url(game), params: { action_type: "paddock" }

    assert_response :redirect
    assert_equal "paddock", game.reload.current_action["type"]
  end

  test "POST action dispatches to select_settlement when paddock action has no from" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.current_action = { "type" => "paddock" }
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.save

    post action_game_url(game), params: { build_row: 5, build_col: 5 }

    game.reload
    assert_equal "[5, 5]", game.current_action["from"], "select_settlement must have set from"
  end

  test "POST action dispatches to move_settlement when paddock action has from set" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
    game.save
    chris.update!(tiles: [ { "klass" => "PaddockTile", "from" => "[2, 0]", "used" => false } ])
    dest = TurnEngine.new(game).buildable_cells.first
    raise "fixed board should offer a legal paddock destination" unless dest

    post action_game_url(game), params: { build_row: dest[0], build_col: dest[1] }

    game.reload
    assert game.board_contents.empty?(5, 5), "settlement must have moved"
    assert_equal chris.order, game.board_contents.player_at(*dest)
  end

  test "POST action dispatches to select_settlement when harbor action has no from" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.current_action = { "type" => "harbor" }
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.save

    post action_game_url(game), params: { build_row: 5, build_col: 5 }

    game.reload
    assert_equal "[5, 5]", game.current_action["from"], "select_settlement must have set from"
  end

  test "POST action dispatches to move_settlement when harbor action has from set" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 7, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "harbor", "from" => "[5, 5]" }
    game.save
    chris.update!(tiles: [ { "klass" => "HarborTile", "from" => "[2, 0]", "used" => false } ])
    dest = TurnEngine.new(game).buildable_cells.first
    raise "fixed board should offer a legal harbor destination" unless dest

    post action_game_url(game), params: { build_row: dest[0], build_col: dest[1] }

    game.reload
    assert game.board_contents.empty?(5, 5), "settlement must have moved from origin"
    assert_equal chris.order, game.board_contents.player_at(*dest)
  end

  test "POST action dispatches to activate_tile_build when tower action" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 3, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "tower" }
    game.save
    chris.update!(tiles: [ { "klass" => "TowerTile", "from" => "[3, 5]", "used" => false } ])

    post action_game_url(game), params: { build_row: 0, build_col: 0 }

    game.reload
    assert_equal chris.order, game.board_contents.player_at(0, 0), "tower tile must have built at border"
  end

  test "remove_meeple in a non-meeple phase degrades to no_content, not a 500" do
    game = games(:game2player)
    game.update!(current_action: { "type" => "mandatory" })

    post remove_meeple_game_url(game), params: { row: 5, col: 5 }

    assert_response :no_content
  end

  test "select_meeple in a non-meeple phase degrades to no_content, not a 500" do
    game = games(:game2player)
    game.update!(current_action: { "type" => "mandatory" })

    post select_meeple_game_url(game), params: { row: 5, col: 5 }

    assert_response :no_content
  end

  test "End turn button is absent for non-current player" do
    game = games(:game2player)
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    get game_url(game)

    assert_select "button", text: "End turn", count: 0
  end

  test "End turn button is absent when game is completed" do
    game = games(:game2player)
    game.update!(state: "completed")

    get game_url(game)

    assert_select "button", text: "End turn", count: 0
  end

  test "POST action does nothing when the requesting player is not the current player" do
    game = games(:game2player)
    game.boards = [ [ 4, 0 ], [ 5, 0 ], [ 0, 0 ], [ 1, 0 ] ]
    game.board_contents = BoardState.new
    game.mandatory_count = 3
    game.save
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    assert_no_difference -> { game.reload.move_count.to_i } do
      post action_game_url(game), params: { build_row: 3, build_col: 6 }
    end

    assert game.reload.board_contents.empty?(3, 6)
  end

  test "POST select_action does nothing when the requesting player is not the current player" do
    game = games(:game2player)
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    post select_action_game_url(game), params: { action_type: "paddock" }

    assert_equal "mandatory", game.reload.current_action["type"]
  end

  test "POST end_turn does nothing when the requesting player is not the current player" do
    game = games(:game2player)
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    post end_turn_game_url(game)

    assert_equal 0, game.reload.mandatory_count, "turn must not have advanced"
    assert_equal game_players(:chris).id, game.reload.current_player_id, "current player must not have changed"
  end

  test "POST undo_move does nothing when the requesting player is not the current player" do
    game = games(:game2player)
    # Give the game an undoable last move so undo would otherwise fire.
    game.moves.create!(
      order: (game.moves.maximum(:order) || 0) + 1,
      game_player: game_players(:chris),
      action: "build_settlement",
      deliberate: true,
      reversible: true,
      snapshot_before: game.capture_snapshot
    )
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    assert_no_difference -> { game.reload.moves.count } do
      post undo_move_game_url(game)
    end
  end

  test "POST end_turn does not call end_turn when paddock action is in progress" do
    game = games(:game2player)
    game.mandatory_count = 0
    game.current_action = { "type" => "paddock" }
    game.save

    post end_turn_game_url(game)

    assert_equal "paddock", game.reload.current_action["type"]
  end

  test "POST end_turn does not call end_turn when mandatory builds are incomplete" do
    game = games(:game2player)
    game.mandatory_count = 3
    game.save

    post end_turn_game_url(game)

    assert_equal 3, game.reload.mandatory_count
  end

  test "game show renders a button for an activatable PaddockTile" do
    game = games(:game2player)
    game.boards = [ [ 5, 0 ], [ 1, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(0, 0, game.current_player.order) }
    game.board_contents = state
    game.save!
    chris = game_players(:chris)
    chris.tiles = [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => false }
    ]
    chris.save

    get game_url(game)

    assert_select "form[action='#{select_action_game_path(game)}'] button", minimum: 1
  end

  test "game show does not render tile action buttons when it is not the viewer's turn" do
    game = games(:game2player)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.mandatory_count = 0
    game.save
    paula = game_players(:paula)
    paula.tiles = [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false }
    ]
    paula.save
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    get game_url(game)

    assert_select "form[action='#{select_action_game_path(game)}'] button", count: 0
  end

  test "game show does not render a button for a used PaddockTile" do
    game = games(:game2player)
    chris = game_players(:chris)
    chris.tiles = [
      { "klass" => "MandatoryTile", "used" => false },
      { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => true }
    ]
    chris.save

    get game_url(game)

    assert_select "form[action='#{select_action_game_path(game)}'] button", count: 0
  end

  test "game show includes current-action span with data attributes" do
    game = games(:game2player)
    get game_url(game)
    assert_select "span#current-action[data-type='mandatory']"
  end

  test "game show renders each player's provisional rating badge" do
    game = games(:game2player)

    get game_url(game)

    assert_select ".rating-badge", text: "(1500?)", count: 2
  end

  test "game show renders rating deltas in the end game modal once rated" do
    game = games(:game2player)
    game.update!(
      state: "completed",
      scores: { "0" => { "total" => 10 }, "1" => { "total" => 5 } }
    )
    game_players(:chris).update!(rating_before: 1500, rating_after: 1510)
    game_players(:paula).update!(rating_before: 1500, rating_after: 1490)

    get game_url(game)

    assert_select "#end-game-modal .rating-row .score-value", text: /1500.*1510.*\+10/
    assert_select "#end-game-modal .rating-row .score-value", text: /1500.*1490.*-10/
  end

  test "game show renders treasure bonus scores in the end game modal" do
    game = games(:game2player)
    game.update!(
      state: "completed",
      scores: {
        "0" => { "castles" => { "score" => 1 }, "total" => 1 },
        "1" => { "castles" => { "score" => 1 }, "treasure" => { "score" => 3 }, "total" => 4 }
      }
    )

    get game_url(game)

    assert_select "#end-game-modal .score-table tbody tr td", text: "Treasure"
    assert_select "#end-game-modal .score-table .score-value", text: "3"
  end

  test "POST action dispatches to place_wall when quarry action" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 4, 0 ], [ 5, 0 ], [ 0, 0 ], [ 1, 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(3, 5, chris.order) }
    game.current_action = { "type" => "quarry", "walls_placed" => 0 }
    game.save
    chris.update!(tiles: [ { "klass" => "QuarryTile", "from" => "[2, 0]", "used" => false } ])

    post action_game_url(game), params: { build_row: 3, build_col: 6 }

    assert_equal "Wall", game.reload.board_contents.tile_klass(3, 6), "quarry action must place a wall, not a settlement"
  end

  test "POST action auto-ends quarry action when no valid walls remain after first placement" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 4, 0 ], [ 5, 0 ], [ 0, 0 ], [ 1, 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(3, 5, chris.order) }
    game.current_action = { "type" => "quarry", "walls_placed" => 0 }
    game.save
    chris.update!(tiles: [ { "klass" => "QuarryTile", "from" => "[2, 0]", "used" => false } ])

    post action_game_url(game), params: { build_row: 3, build_col: 6 }

    assert_equal "mandatory", game.reload.current_action["type"], "quarry action must auto-end when no valid placements remain"
  end

  test "GET new renders the new game form" do
    get new_game_url
    assert_response :success
  end

  test "GET new renders a speed select offering blitz and normal" do
    get new_game_url
    assert_select "select[name=?]", "game[speed]" do
      assert_select "option[value=blitz]"
      assert_select "option[value=normal]"
    end
  end

  test "GET new renders a help dialog explaining timed games" do
    get new_game_url
    assert_select "dialog"
  end

  test "POST create creates a game and redirects to dashboard" do
    assert_difference("Game.count", 1) do
      post games_url
    end
    assert_redirected_to dashboard_path
  end

  test "POST create logs the table opening and game options as deliberate, irreversible moves" do
    post games_url
    game = Game.last

    opened = game.moves.find_by(action: "open_table")
    assert_equal "Chris opened the table", opened.message
    assert_equal game.game_players.find_by(player: users(:chris)), opened.game_player
    assert opened.deliberate
    assert_not opened.reversible

    options = game.moves.find_by(action: "game_options")
    assert_equal "Game options: Untimed", options.message
    assert_nil options.game_player_id
    assert options.deliberate
    assert_not options.reversible
  end

  test "POST create with a speed param sets the game's speed" do
    post games_url, params: { game: { speed: "blitz" } }
    assert_equal "blitz", Game.last.speed
  end

  test "POST create without a speed param leaves the game untimed" do
    post games_url
    assert_nil Game.last.speed
  end

  test "POST create logs the chosen speed in the game_options move message" do
    post games_url, params: { game: { speed: "blitz" } }
    options = Game.last.moves.find_by(action: "game_options")
    assert_includes options.message, "Blitz"
  end

  test "POST create rejects a speed that is not a recognized option" do
    assert_no_difference("Game.count") do
      post games_url, params: { game: { speed: "warp" } }
    end
    assert_response :unprocessable_content
  end

  test "POST action with mandatory current_action dispatches build_settlement" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new
    game.current_action = { "type" => "mandatory" }
    game.mandatory_count = Game::MANDATORY_COUNT
    game.save
    chris.update!(hand: [ "G" ])
    target = TurnEngine.new(game).buildable_cells.first
    raise "fixed board should offer a legal mandatory build" unless target

    post action_game_url(game), params: { build_row: target[0], build_col: target[1] }

    assert_equal chris.order, game.reload.board_contents.player_at(*target)
  end

  test "POST action with oasis current_action dispatches activate_tile_build" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(0, 2, chris.order) }
    game.current_action = { "type" => "oasis" }
    game.save
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
    chris.save

    post action_game_url(game), params: { build_row: 0, build_col: 1 }

    assert_equal chris.order, game.reload.board_contents.player_at(0, 1)
  end

  test "POST action with donation tile current_action dispatches activate_tile_build" do
    game = games(:game2player)
    chris = game_players(:chris)
    # OasisBoard has Desert at [0,0]; place settlement elsewhere so fallback path is used
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "donationdesert", "klass" => "DonationDesertTile", "remaining" => 3 }
    game.save
    chris.tiles = [ { "klass" => "DonationDesertTile", "from" => "[0, 5]", "used" => false } ]
    chris.save

    post action_game_url(game), params: { build_row: 0, build_col: 0 }

    assert_equal chris.order, game.reload.board_contents.player_at(0, 0)
  end

  test "GET show as turbo_stream renders without error" do
    get game_url(games(:game2player)), as: :turbo_stream

    assert_response :success
  end

  test "POST join adds the current user to the game" do
    game = Game.create!(state: "waiting")
    game.add_player(users(:chris))

    post session_url, params: { email_address: "paula@example.com", password: "password" }
    post join_game_url(game)

    assert_includes game.reload.players, users(:paula)
  end

  test "POST join redirects to the game" do
    game = Game.create!(state: "waiting")
    game.add_player(users(:chris))

    post session_url, params: { email_address: "paula@example.com", password: "password" }
    post join_game_url(game)

    assert_redirected_to game_path(game)
  end

  test "POST join logs the joining player as a deliberate, irreversible move" do
    game = Game.create!(state: "waiting")
    game.add_player(users(:chris))

    post session_url, params: { email_address: "paula@example.com", password: "password" }
    post join_game_url(game)

    joined = game.reload.moves.find_by(action: "join_table")
    assert_equal "Paula joined the table", joined.message
    assert_equal game.game_players.find_by(player: users(:paula)), joined.game_player
    assert joined.deliberate
    assert_not joined.reversible
  end

  test "POST join starts a timed game without stamping anyone's clock_started_at" do
    game = Game.create!(state: "waiting", speed: "blitz")
    game.add_player(users(:chris))

    post session_url, params: { email_address: "paula@example.com", password: "password" }
    post join_game_url(game)

    assert game.reload.playing?
    game.game_players.each { |gp| assert_nil gp.clock_started_at }
  end

  test "POST undo_move redirects to the game" do
    game = games(:game2player)
    post undo_move_game_url(game)
    assert_redirected_to game_path(game)
  end

  test "POST action does nothing when game is completed" do
    game = games(:game2player)
    game.update!(state: "completed")
    move_count_before = game.moves.count

    post action_game_url(game), params: { build_row: 0, build_col: 0 }, as: :turbo_stream

    assert_equal move_count_before, game.moves.count
  end

  test "POST select_action does nothing when game is completed" do
    game = games(:game2player)
    game.update!(state: "completed")
    action_before = game.current_action

    post select_action_game_url(game), params: { action_type: "oasis" }, as: :turbo_stream

    assert_equal action_before, game.reload.current_action
  end

  test "POST end_turn does nothing when game is completed" do
    game = games(:game2player)
    game.update!(state: "completed", mandatory_count: 0)
    move_count_before = game.moves.count

    post end_turn_game_url(game), as: :turbo_stream

    assert_equal move_count_before, game.moves.count
  end

  test "POST undo_move does nothing when game is completed" do
    game = games(:game2player)
    game.update!(state: "completed")
    move_count_before = game.moves.count

    post undo_move_game_url(game), as: :turbo_stream

    assert_equal move_count_before, game.moves.count
  end

  test "undo_move broadcasts the undo play_sound turbo stream" do
    game = games(:game2player)
    broadcasts = capture_turbo_stream_broadcasts("game_#{game.id}") do
      post undo_move_game_url(game)
    end
    assert broadcasts.any? { |b| b.to_s.include?(%(action="play_sound")) && b.to_s.include?(%(key="undo")) },
      "expected a play_sound[key=undo] broadcast, got: #{broadcasts.inspect}"
  end

  test "POST create broadcasts dashboard update to non-participating users" do
    paula = users(:paula)

    assert_turbo_stream_broadcasts("user_#{paula.id}") do
      post games_url
    end
  end

  test "join broadcasts dashboard update to the joining user" do
    post session_url, params: { email_address: "paula@example.com", password: "password" }
    paula = users(:paula)

    assert_turbo_stream_broadcasts("user_#{paula.id}") do
      post join_game_url(games(:waiting_game))
    end
  end

  test "join broadcasts game update so waiting players see the game start" do
    game = games(:waiting_game)
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    assert_turbo_stream_broadcasts("game_#{game.id}") do
      post join_game_url(game)
    end
  end

  test "build broadcasts board, turn-state, common-resources, a log entry, and private updates" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new
    game.current_action = { "type" => "mandatory" }
    game.mandatory_count = Game::MANDATORY_COUNT
    game.save
    chris.update!(hand: [ "G" ])
    target = TurnEngine.new(game).buildable_cells.first
    raise "fixed board should offer a legal mandatory build" unless target

    post action_game_url(game), params: { build_row: target[0], build_col: target[1] }

    public_broadcasts = capture_turbo_stream_broadcasts("game_#{game.id}")
    targets = public_broadcasts.map { |e| e["target"] }
    assert_includes targets, "board"
    assert_includes targets, "turn-state"
    assert_includes targets, "common-resources"

    log_entry = public_broadcasts.find { |e| e["target"] == "log" }
    assert_match "built a settlement", log_entry.text

    private_targets = capture_turbo_stream_broadcasts("game_player_#{chris.id}_private").map { |e| e["target"] }
    assert_includes private_targets, "game_player_#{chris.id}"
    assert_includes private_targets, "end-turn-area"
  end

  test "activating a tile broadcasts the tile as used and logs the build" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(0, 2, chris.order) }
    game.current_action = { "type" => "oasis" }
    game.save
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
    chris.save

    post action_game_url(game), params: { build_row: 0, build_col: 1 }

    own_panel = capture_turbo_stream_broadcasts("game_player_#{chris.id}_private")
      .find { |e| e["target"] == "game_player_#{chris.id}" }
    assert_not_empty own_panel.css(".player-tile.tile-used .tile-container.oasis"),
      "expected the Oasis tile to render as used"

    log_entry = capture_turbo_stream_broadcasts("game_#{game.id}").find { |e| e["target"] == "log" }
    assert_match "built a settlement", log_entry.text
  end

  test "end_turn broadcasts turn-state, a log entry, and private end-turn-area updates" do
    game = games(:game2player)
    paula = game_players(:paula)
    game.mandatory_count = 0
    game.save

    post end_turn_game_url(game)

    public_broadcasts = capture_turbo_stream_broadcasts("game_#{game.id}")
    assert_includes public_broadcasts.map { |e| e["target"] }, "turn-state"

    log_entry = public_broadcasts.find { |e| e["target"] == "log" }
    assert_match "ended their turn", log_entry.text

    private_targets = capture_turbo_stream_broadcasts("game_player_#{paula.id}_private").map { |e| e["target"] }
    assert_includes private_targets, "end-turn-area"
  end

  test "the final end_turn that completes the game broadcasts the end-game modal" do
    game = games(:game2player)
    paula = game_players(:paula)
    game.update!(current_player: paula, mandatory_count: 0, end_trigger_count: 1)
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    post end_turn_game_url(game)

    modal = capture_turbo_stream_broadcasts("game_#{game.id}").find { |e| e["target"] == "game-area" }
    assert_not_nil modal, "expected an end-game modal broadcast"
    assert_equal "append", modal["action"]
    assert_equal "completed", game.reload.state
  end

  test "no player-spinner or active tile shows for the player who would have gone next once the game completes" do
    game = games(:game2player)
    chris = game_players(:chris)
    paula = game_players(:paula)
    chris.tiles = [ { "klass" => "MandatoryTile", "used" => false } ]
    chris.save!
    game.update!(current_player: paula, mandatory_count: 0, end_trigger_count: 1)
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    post end_turn_game_url(game)
    assert_equal "completed", game.reload.state
    assert_nil game.current_player_id

    post session_url, params: { email_address: "chris@example.com", password: "password" }
    get game_url(game)

    assert_select ".player-spinner", count: 0
    assert_select ".player-tile.tile-active", count: 0
  end

  test "POST resign ends the game, logs the resignation, and stays on the game page" do
    game = games(:game2player)
    post resign_game_url(game)
    assert_redirected_to game_path(game)
    assert_not_nil game_players(:chris).reload.resigned_at
    assert_equal "completed", game.reload.state
    assert game.moves.exists?(action: "resign")
  end

  test "POST resign does nothing when user is not a player in the game" do
    game = games(:paula_jules_game)
    post resign_game_url(game)
    assert_redirected_to game_path(game)
    assert_equal "playing", game.reload.state
    assert_nil game_players(:paula_in_paula_jules_game).reload.resigned_at
  end

  test "POST claim_victory resigns the flagged current player and completes the game" do
    game = new_timed_game(speed: "blitz")
    current = game.current_player
    opponent = game.game_players.find { |gp| gp != current }
    current.update!(clock_started_at: Time.current, time_remaining_ms: 1_000)
    post session_url, params: { email_address: opponent.player.email_address, password: "password" }

    travel 2.seconds do
      post claim_victory_game_url(game)
    end

    assert_redirected_to game_path(game)
    assert current.reload.resigned?
    assert_equal "completed", game.reload.state
    assert game.moves.exists?(action: "resign")
  end

  test "POST claim_victory does nothing when the current player is not flagged" do
    game = new_timed_game(speed: "blitz")
    current = game.current_player
    opponent = game.game_players.find { |gp| gp != current }
    current.update!(clock_started_at: Time.current, time_remaining_ms: 100_000)
    post session_url, params: { email_address: opponent.player.email_address, password: "password" }

    post claim_victory_game_url(game)

    assert_redirected_to game_path(game)
    assert_not current.reload.resigned?
    assert_equal "playing", game.reload.state
  end

  test "POST claim_victory does nothing when the requester is not an opponent" do
    game = new_timed_game(speed: "blitz")
    current = game.current_player
    current.update!(clock_started_at: Time.current, time_remaining_ms: 1_000)
    post session_url, params: { email_address: current.player.email_address, password: "password" }

    travel 2.seconds do
      post claim_victory_game_url(game)
    end

    assert_not current.reload.resigned?
    assert_equal "playing", game.reload.state
  end

  test "POST claim_victory does nothing for an untimed game" do
    game = games(:game2player)
    paula = game_players(:paula)
    post session_url, params: { email_address: paula.player.email_address, password: "password" }

    post claim_victory_game_url(game)

    assert_not game_players(:chris).reload.resigned?
    assert_equal "playing", game.reload.state
  end

  test "POST claim_victory does nothing once the game is already completed" do
    game = new_timed_game(speed: "blitz")
    current = game.current_player
    opponent = game.game_players.find { |gp| gp != current }
    current.update!(clock_started_at: Time.current, time_remaining_ms: 1_000)
    post session_url, params: { email_address: opponent.player.email_address, password: "password" }
    travel(2.seconds) { post claim_victory_game_url(game) }
    assert_equal "completed", game.reload.state

    post claim_victory_game_url(game)

    assert_response :redirect
    assert_equal "completed", game.reload.state
  end

  test "Claim victory button is visible for an opponent once the current player is flagged" do
    game = new_timed_game(speed: "blitz")
    current = game.current_player
    opponent = game.game_players.find { |gp| gp != current }
    current.update!(clock_started_at: Time.current, time_remaining_ms: 1_000)
    post session_url, params: { email_address: opponent.player.email_address, password: "password" }

    travel 2.seconds do
      get game_url(game)
    end

    assert_select "[data-controller='claim-victory']:not([hidden]) form[action=?]", claim_victory_game_path(game)
  end

  test "Claim victory button renders hidden for an opponent while the current player is not flagged" do
    game = new_timed_game(speed: "blitz")
    current = game.current_player
    opponent = game.game_players.find { |gp| gp != current }
    current.update!(clock_started_at: Time.current, time_remaining_ms: 100_000)
    post session_url, params: { email_address: opponent.player.email_address, password: "password" }

    get game_url(game)

    # Present but hidden: clock_controller reveals it live the instant the
    # clock flags, so no reload/broadcast is needed to surface the button.
    assert_select "[data-controller='claim-victory'][hidden] form[action=?]", claim_victory_game_path(game)
  end

  test "Claim victory button is absent for the flagged player themselves" do
    game = new_timed_game(speed: "blitz")
    current = game.current_player
    current.update!(clock_started_at: Time.current, time_remaining_ms: 1_000)
    post session_url, params: { email_address: current.player.email_address, password: "password" }

    travel 2.seconds do
      get game_url(game)
    end

    assert_select "form[action=?]", claim_victory_game_path(game), count: 0
  end

  test "per-player clocks render for a timed game" do
    game = new_timed_game(speed: "blitz")
    post session_url, params: { email_address: game.current_player.player.email_address, password: "password" }

    get game_url(game)

    assert_select ".player-clock", 2
  end

  test "no clocks render for an untimed game" do
    game = games(:game2player)

    get game_url(game)

    assert_select ".player-clock", 0
  end

  test "POST undo_max_moves does nothing when the requesting player is not the current player" do
    game = games(:game2player)
    chris = game_players(:chris)
    snapshot = game.capture_snapshot

    game.moves.create!(
      order: (game.moves.maximum(:order) || 0) + 1,
      game_player: chris,
      action: "open_table",
      deliberate: true,
      reversible: false,
      snapshot_before: snapshot
    )

    game.moves.create!(
      order: (game.moves.maximum(:order) || 0) + 1,
      game_player: chris,
      action: "build_settlement",
      deliberate: true,
      reversible: true,
      snapshot_before: snapshot
    )

    post session_url, params: { email_address: "paula@example.com", password: "password" }

    assert_no_difference -> { game.reload.moves.count } do
      post undo_max_moves_game_url(game)
    end
  end

  test "POST undo_max_moves undoes all reversible moves until reaching a non-reversible move" do
    game = games(:game2player)
    chris = game_players(:chris)
    snapshot = game.capture_snapshot

    # Add an irreversible move
    game.moves.create!(
      order: (game.moves.maximum(:order) || 0) + 1,
      game_player: chris,
      action: "open_table",
      deliberate: true,
      reversible: false,
      snapshot_before: snapshot
    )

    # Add several reversible moves after the irreversible one
    3.times do |i|
      game.moves.create!(
        order: (game.moves.maximum(:order) || 0) + 1,
        game_player: chris,
        action: "build_settlement",
        deliberate: true,
        reversible: true,
        snapshot_before: snapshot
      )
    end

    initial_move_count = game.moves.count
    post undo_max_moves_game_url(game)
    final_move_count = game.reload.moves.count

    assert_equal 3, initial_move_count - final_move_count, "expected 3 reversible moves to be undone"
  end

  def new_timed_game(speed:)
    game = Game.create!(state: "waiting", speed: speed)
    game.add_player(users(:chris))
    game.add_player(users(:paula))
    game.start
    game.reload
  end
end

class GamesControllerUnauthenticatedTest < ActionDispatch::IntegrationTest
  test "GET show redirects to login when not authenticated" do
    get game_url(games(:game2player))
    assert_redirected_to new_session_path
  end

  test "POST action redirects to login when not authenticated" do
    post action_game_url(games(:game2player)), params: { build_row: 0, build_col: 0 }
    assert_redirected_to new_session_path
  end
end
