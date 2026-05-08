require "test_helper"

class TurnTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate

    @player = @game.current_player
    @player.update!(tiles: [ { "klass" => "FarmTile", "from" => "[3, 4]", "used" => false } ])
    @game.reload
  end

  def turn = Turn.from_game(@game)

  test "from_game with no sub_phase yields a turn with no sub_phase" do
    assert_nil turn.sub_phase
    assert_equal @player.order, turn.player_order
  end

  test "select_action(FarmTile) emits SubPhasePushed with TileBuildPhase state" do
    consequences = turn.handle(:select_action, game: @game, tile: "FarmTile")

    assert_equal 1, consequences.size
    pushed = consequences.first
    assert_kind_of Turn::Consequences::SubPhasePushed, pushed
    assert_equal Turn::SubPhases::TileBuildPhase::TYPE, pushed.phase_type
    assert_equal "G", pushed.state["restricted_terrain"]
    assert_equal "FarmTile", pushed.state["tile_klass"]
    assert_equal "[3, 4]", pushed.state["tile_source"]
  end

  test "select_action(FarmTile) with no Farm tile returns Error" do
    @player.update!(tiles: [])
    @game.reload
    consequences = turn.handle(:select_action, game: @game, tile: "FarmTile")
    assert_kind_of Turn::Consequences::Error, consequences.first
  end

  test "select_action(FarmTile) when Farm already used returns Error" do
    @player.update!(tiles: [ { "klass" => "FarmTile", "from" => "[3, 4]", "used" => true } ])
    @game.reload
    consequences = turn.handle(:select_action, game: @game, tile: "FarmTile")
    assert_kind_of Turn::Consequences::Error, consequences.first
  end

  test "select_action when sub_phase already active returns Error" do
    @game.current_action = {
      "turn" => {
        "sub_phase" => {
          "type" => Turn::SubPhases::TileBuildPhase::TYPE,
          "state" => { "restricted_terrain" => "G", "tile_klass" => "FarmTile", "tile_source" => "[3, 4]" }
        }
      }
    }
    consequences = turn.handle(:select_action, game: @game, tile: "FarmTile")
    assert_kind_of Turn::Consequences::Error, consequences.first
  end

  test "select_action works for any builds_settlement? tile with fixed build_terrain" do
    [
      [ "OasisTile", "D" ],
      [ "GardenTile", "F" ],
      [ "MonasteryTile", "C" ],
      [ "ForestersLodgeTile", "T" ]
    ].each do |klass, terrain|
      @player.update!(tiles: [ { "klass" => klass, "from" => "[2, 2]", "used" => false } ])
      @game.reload
      cs = turn.handle(:select_action, game: @game, tile: klass)
      pushed = cs.find { |c| c.is_a?(Turn::Consequences::SubPhasePushed) }
      refute_nil pushed, "expected SubPhasePushed for #{klass}"
      assert_equal terrain, pushed.state["restricted_terrain"], "wrong terrain for #{klass}"
      assert_equal klass, pushed.state["tile_klass"]
    end
  end

  test "select_action routes Village/Tower/Tavern to TileBuildPhase with restricted_terrain: nil" do
    %w[VillageTile TowerTile TavernTile].each do |klass|
      @player.update!(tiles: [ { "klass" => klass, "from" => "[2, 2]", "used" => false } ])
      @game.reload
      cs = turn.handle(:select_action, game: @game, tile: klass)
      pushed = cs.find { |c| c.is_a?(Turn::Consequences::SubPhasePushed) }
      refute_nil pushed, "expected SubPhasePushed for #{klass}"
      assert_nil pushed.state["restricted_terrain"], "#{klass} should not have a fixed terrain"
      assert_equal klass, pushed.state["tile_klass"]
    end
  end

  test "select_action errors for unknown tile klass" do
    consequences = turn.handle(:select_action, game: @game, tile: "NonsenseTile")
    assert_kind_of Turn::Consequences::Error, consequences.first
  end

  test "select_action(BarracksTile) emits SubPhasePushed with MeeplePlacementPhase state and kind: warrior" do
    @player.update!(tiles: [ { "klass" => "BarracksTile", "from" => "[2, 3]", "used" => false } ])
    @game.reload
    @game.instantiate
    cs = turn.handle(:select_action, game: @game, tile: "BarracksTile")
    pushed = cs.find { |c| c.is_a?(Turn::Consequences::SubPhasePushed) }
    refute_nil pushed
    assert_equal Turn::SubPhases::MeeplePlacementPhase::TYPE, pushed.phase_type
    assert_equal "BarracksTile", pushed.state["tile_klass"]
    assert_equal "warrior", pushed.state["kind"]
  end

  test "select_action(LighthouseTile) routes through MeeplePlacementPhase with kind: ship" do
    @player.update!(tiles: [ { "klass" => "LighthouseTile", "from" => "[2, 3]", "used" => false } ])
    @game.reload
    @game.instantiate
    cs = turn.handle(:select_action, game: @game, tile: "LighthouseTile")
    pushed = cs.find { |c| c.is_a?(Turn::Consequences::SubPhasePushed) }
    refute_nil pushed
    assert_equal "ship", pushed.state["kind"]
  end

  test "place_meeple is dispatched to active MeeplePlacementPhase" do
    @player.update!(supply: { "settlements" => 40, "warriors" => 2 })
    @game.current_action = {
      "turn" => {
        "sub_phase" => {
          "type" => "meeple_placement",
          "state" => { "tile_klass" => "BarracksTile", "kind" => "warrior" }
        }
      }
    }
    @game.save!
    @game.reload
    @game.instantiate

    target = first_buildable_hex
    cs = turn.handle(:place_meeple, game: @game, row: target[0], col: target[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected place_meeple to succeed: #{cs.inspect}")
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::MeeplePlaced) })
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::SubPhasePopped) })
  end

  test "select_action(PaddockTile) emits SubPhasePushed with SettlementMovePhase state" do
    @player.update!(tiles: [ { "klass" => "PaddockTile", "from" => "[2, 3]", "used" => false } ])
    @game.reload
    @game.instantiate
    cs = turn.handle(:select_action, game: @game, tile: "PaddockTile")
    pushed = cs.find { |c| c.is_a?(Turn::Consequences::SubPhasePushed) }
    refute_nil pushed
    assert_equal Turn::SubPhases::SettlementMovePhase::TYPE, pushed.phase_type
    assert_equal "PaddockTile", pushed.state["tile_klass"]
    assert_nil pushed.state["source"]
  end

  test "select_settlement is dispatched to active SettlementMovePhase" do
    @game.board_contents.place_settlement(5, 5, @player.order)
    @game.current_action = {
      "turn" => {
        "sub_phase" => {
          "type" => "settlement_move",
          "state" => { "tile_klass" => "PaddockTile", "source" => nil }
        }
      }
    }
    @game.save!
    @game.reload
    @game.instantiate

    cs = turn.handle(:select_settlement, game: @game, row: 5, col: 5)
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::SubPhaseStateUpdated) })
  end

  test "move_settlement without active SettlementMovePhase returns Error" do
    cs = turn.handle(:move_settlement, game: @game, row: 5, col: 5)
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "select_action errors for a tile that does not build_settlement" do
    # OutpostTile has its own activate path; passing it through select_action should error.
    @player.update!(tiles: [ { "klass" => "OutpostTile", "from" => "[2, 2]", "used" => false } ])
    @game.reload
    consequences = turn.handle(:select_action, game: @game, tile: "OutpostTile")
    assert_kind_of Turn::Consequences::Error, consequences.first
  end

  test "build delegates to active sub_phase and appends SubPhasePopped on completion" do
    @game.current_action = {
      "turn" => {
        "sub_phase" => {
          "type" => Turn::SubPhases::TileBuildPhase::TYPE,
          "state" => { "restricted_terrain" => "G", "tile_klass" => "FarmTile", "tile_source" => "[3, 4]" }
        }
      }
    }
    row, col = first_empty_grass
    consequences = turn.handle(:build, game: @game, row:, col:)

    assert(consequences.any? { |c| c.is_a?(Turn::Consequences::SettlementPlaced) })
    assert(consequences.any? { |c| c.is_a?(Turn::Consequences::TileConsumed) })
    assert_kind_of Turn::Consequences::SubPhasePopped, consequences.last
    assert_equal Turn::SubPhases::TileBuildPhase::TYPE, consequences.last.prior_state["type"]
    assert_equal "G", consequences.last.prior_state.dig("state", "restricted_terrain")
  end

  test "build that empties player supply appends EndTriggered" do
    @player.update!(supply: { "settlements" => 1 })
    hand_terrain = @player.hand.first
    target = first_empty_terrain(hand_terrain)
    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])
    triggered = cs.find { |c| c.is_a?(Turn::Consequences::EndTriggered) }
    refute_nil triggered
    assert_equal @player.order, triggered.player
  end

  test "build that does not empty supply does NOT append EndTriggered" do
    @player.update!(supply: { "settlements" => 5 })
    hand_terrain = @player.hand.first
    target = first_empty_terrain(hand_terrain)
    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::EndTriggered) })
  end

  test "end_turn at the last player's turn appends GameCompleted when ending?" do
    @game.update!(end_trigger_count: 1)  # ending? is true
    last_order = @game.game_players.count - 1
    @game.current_player = @game.game_players.find { |gp| gp.order == last_order }
    @game.save!
    @game.reload
    @game.instantiate

    cs = Turn.from_game(@game).handle(:end_turn, game: @game)
    completed = cs.find { |c| c.is_a?(Turn::Consequences::GameCompleted) }
    refute_nil completed, "expected GameCompleted at last player's end_turn when ending?"
  end

  test "end_turn does NOT append GameCompleted when not ending?" do
    last_order = @game.game_players.count - 1
    @game.current_player = @game.game_players.find { |gp| gp.order == last_order }
    @game.save!
    @game.reload
    @game.instantiate

    cs = Turn.from_game(@game).handle(:end_turn, game: @game)
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::GameCompleted) })
  end

  test "end_turn does NOT append GameCompleted when ending? but not last player" do
    @game.update!(end_trigger_count: 1)
    @game.current_player = @game.game_players.find { |gp| gp.order == 0 }
    @game.save!
    @game.reload
    @game.instantiate

    cs = Turn.from_game(@game).handle(:end_turn, game: @game)
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::GameCompleted) })
  end

  test "end_turn emits HandRefreshed + CurrentPlayerAdvanced + TurnReset + IrreversibleBoundary" do
    @game.update!(deck: [ "G", "F", "T" ], discard: [ "C" ])
    @player.update!(hand: [ "T" ])
    @game.reload
    @game.instantiate

    cs = turn.handle(:end_turn, game: @game)

    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) })
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::IrreversibleBoundary) })

    refresh = cs.find { |c| c.is_a?(Turn::Consequences::HandRefreshed) }
    refute_nil refresh
    assert_equal [ "T" ], refresh.hand_before
    assert_equal [ "G" ], refresh.hand_after
    assert_equal [ "C", "T" ], refresh.discard_after

    advance = cs.find { |c| c.is_a?(Turn::Consequences::CurrentPlayerAdvanced) }
    refute_nil advance
    assert_equal @player.order, advance.prior_order
    assert_equal((@player.order + 1) % 2, advance.next_order)

    reset = cs.find { |c| c.is_a?(Turn::Consequences::TurnReset) }
    refute_nil reset
  end

  test "end_turn emits NomadTilesExpired for tiles whose expires_on_turn matches the ending turn" do
    @game.update!(turn_number: 4)
    @player.update!(tiles: [
      { "klass" => "FarmTile", "from" => "[3, 4]", "used" => true },
      { "klass" => "DonationGrassTile", "from" => "[5, 6]", "used" => true, "expires_on_turn" => 4 }
    ])
    @game.reload
    @game.instantiate

    cs = turn.handle(:end_turn, game: @game)
    expired = cs.find { |c| c.is_a?(Turn::Consequences::NomadTilesExpired) }
    refute_nil expired
    assert_equal @player.order, expired.player
    assert_equal 1, expired.expired_tiles.size
    assert_equal "DonationGrassTile", expired.expired_tiles.first["klass"]
  end

  test "end_turn does NOT emit NomadTilesExpired when no tiles have matching expires_on_turn" do
    @game.update!(turn_number: 4)
    @player.update!(tiles: [
      { "klass" => "FarmTile", "from" => "[3, 4]", "used" => true },
      { "klass" => "DonationGrassTile", "from" => "[5, 6]", "used" => true, "expires_on_turn" => 7 }
    ])
    @game.reload
    @game.instantiate

    cs = turn.handle(:end_turn, game: @game)
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::NomadTilesExpired) })
  end

  test "end_turn emits TilesReset for the next player" do
    next_player = @game.game_players.find { |g| g.order != @player.order }
    next_player.update!(tiles: [
      { "klass" => "FarmTile", "from" => "[3, 4]", "used" => true },
      { "klass" => "OracleTile", "from" => "[5, 6]", "used" => true, "permanent" => true }
    ])
    @game.reload
    @game.instantiate

    cs = turn.handle(:end_turn, game: @game)
    reset = cs.find { |c| c.is_a?(Turn::Consequences::TilesReset) }
    refute_nil reset
    assert_equal next_player.order, reset.player
    assert_equal 2, reset.prior_tiles.size
  end

  test "end_turn draws 2 cards when player holds a CrossroadsTile" do
    @game.update!(deck: [ "G", "F", "T" ], discard: [ "C" ])
    @player.update!(hand: [ "T" ], tiles: [ { "klass" => "CrossroadsTile", "from" => "[5, 5]", "used" => false } ])
    @game.reload
    @game.instantiate

    cs = turn.handle(:end_turn, game: @game)
    refresh = cs.find { |c| c.is_a?(Turn::Consequences::HandRefreshed) }
    assert_equal [ "G", "F" ], refresh.hand_after
    assert_equal [ "T" ], refresh.deck_after
    assert_equal [ "C", "T" ], refresh.discard_after
  end

  test "end_turn reshuffles when deck has only the drawn card" do
    @game.update!(deck: [ "G" ], discard: [ "F", "T" ])
    @player.update!(hand: [ "C" ])
    @game.reload
    @game.instantiate

    cs = turn.handle(:end_turn, game: @game)
    refresh = cs.find { |c| c.is_a?(Turn::Consequences::HandRefreshed) }
    # After draw, deck would be empty; reshuffle from discard.
    assert_equal [ "G" ], refresh.hand_after
    assert_equal [ "F", "T", "C" ].sort, refresh.deck_after.sort + refresh.discard_after
    # The drawn-card stays in discard for next reshuffle? Check existing pattern.
    assert refresh.discard_after.empty?, "discard should be empty after reshuffle"
  end

  test "activate_fort emits TileConsumed + CardDrawn + SubPhasePushed(FortPhase) + IrreversibleBoundary" do
    @player.update!(tiles: [ { "klass" => "FortTile", "from" => "[3, 4]", "used" => false } ])
    @game.update!(deck: [ "G", "F", "T" ], discard: [ "C" ])
    @game.reload
    @game.instantiate

    cs = turn.handle(:activate_fort, game: @game)

    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) })
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::TileConsumed) && c.klass == "FortTile" })
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::IrreversibleBoundary) })

    drawn = cs.find { |c| c.is_a?(Turn::Consequences::CardDrawn) }
    refute_nil drawn
    assert_equal "G", drawn.card  # top of deck
    assert_equal [ "F", "T" ], drawn.deck_after
    assert_equal [ "C", "G" ], drawn.discard_after

    pushed = cs.find { |c| c.is_a?(Turn::Consequences::SubPhasePushed) }
    refute_nil pushed
    assert_equal Turn::SubPhases::FortPhase::TYPE, pushed.phase_type
    assert_equal "G", pushed.state["fort_terrain"]
    assert_equal 2, pushed.state["builds_remaining"]
  end

  test "activate_fort returns Error when no unused FortTile" do
    @player.update!(tiles: [])
    @game.reload
    @game.instantiate
    cs = turn.handle(:activate_fort, game: @game)
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "activate_fort reshuffles when deck has only the drawn card" do
    @player.update!(tiles: [ { "klass" => "FortTile", "from" => "[3, 4]", "used" => false } ])
    @game.update!(deck: [ "G" ], discard: [ "F", "T" ])
    @game.reload
    @game.instantiate

    cs = turn.handle(:activate_fort, game: @game)
    drawn = cs.find { |c| c.is_a?(Turn::Consequences::CardDrawn) }
    assert_equal "G", drawn.card
    assert_equal [ "F", "T" ].sort, drawn.deck_after.sort
    assert_equal [ "G" ], drawn.discard_after
  end

  test "activate_outpost emits OutpostActivated + TileConsumed when player owns an unused OutpostTile" do
    @player.update!(tiles: [ { "klass" => "OutpostTile", "from" => "[3, 4]", "used" => false } ])
    @game.reload
    @game.instantiate

    cs = turn.handle(:activate_outpost, game: @game)
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::OutpostActivated) })
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::TileConsumed) && c.klass == "OutpostTile" })
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) })
  end

  test "activate_outpost returns Error when player has no unused OutpostTile" do
    @player.update!(tiles: [])
    @game.reload
    @game.instantiate
    cs = turn.handle(:activate_outpost, game: @game)
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "build with outpost_active skips adjacency and emits OutpostDeactivated" do
    hand_terrain = @player.hand.first
    seed = first_empty_terrain(hand_terrain)
    @game.board_contents.place_settlement(seed[0], seed[1], 0)  # gives player adjacency, normally restricting builds
    @game.current_action = { "turn" => { "outpost_active" => true } }
    @game.save!
    @game.reload
    @game.instantiate

    far = first_empty_terrain_not_adjacent_to(seed, hand_terrain)
    cs = turn.handle(:build, game: @game, row: far[0], col: far[1])

    assert(cs.any? { |c| c.is_a?(Turn::Consequences::SettlementPlaced) })
    deactivate = cs.find { |c| c.is_a?(Turn::Consequences::OutpostDeactivated) }
    refute_nil deactivate, "expected OutpostDeactivated"
    assert_equal true, deactivate.prior_active
  end

  test "build without outpost_active does NOT emit OutpostDeactivated" do
    hand_terrain = @player.hand.first
    target = first_empty_terrain(hand_terrain)
    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::OutpostDeactivated) })
  end

  test "from_game defaults mandatory_remaining to 3 when current_action is empty" do
    @game.current_action = {}
    assert_equal 3, Turn.from_game(@game).mandatory_remaining
  end

  test "from_game reads mandatory_remaining from current_action.turn" do
    @game.current_action = { "turn" => { "mandatory_remaining" => 1 } }
    assert_equal 1, Turn.from_game(@game).mandatory_remaining
  end

  test "build with no sub_phase emits SettlementPlaced + MandatoryRemainingDecremented" do
    row, col = first_empty_terrain(@player.hand.first)
    cs = turn.handle(:build, game: @game, row: row, col: col)
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::SettlementPlaced) })
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::MandatoryRemainingDecremented) })
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) })
  end

  test "build errors when mandatory_remaining is 0" do
    @game.current_action = { "turn" => { "mandatory_remaining" => 0 } }
    row, col = first_empty_terrain(@player.hand.first)
    cs = turn.handle(:build, game: @game, row: row, col: col)
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "build errors when terrain does not match player hand" do
    hand_terrain = @player.hand.first
    row, col = first_empty_terrain_other_than(hand_terrain)
    cs = turn.handle(:build, game: @game, row: row, col: col)
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "build appends a TilePickedUp for each adjacent location hex with qty > 0" do
    hand_terrain = @player.hand.first
    target = first_empty_terrain(hand_terrain)
    nbr = @game.board_contents.neighbors(target[0], target[1]).first
    @game.board_contents.place_tile(nbr[0], nbr[1], "OracleTile", 2)
    @game.save!
    @game.reload
    @game.instantiate

    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])

    pickups = cs.select { |c| c.is_a?(Turn::Consequences::TilePickedUp) }
    assert_equal 1, pickups.size
    assert_equal "OracleTile", pickups.first.klass
    assert_equal Coordinate.new(nbr[0], nbr[1]), pickups.first.from
  end

  test "families: third build NOT in a straight line does not score" do
    @game.update!(goals: [ "families" ])
    # Random scattered prior builds.
    @game.current_action = {
      "turn" => { "mandatory_remaining" => 1, "builds" => [ "[2, 2]", "[10, 10]" ] }
    }
    @game.save!
    @game.reload
    @game.instantiate

    target = first_empty_terrain(@player.hand.first)
    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::GoalScored) && c.goal == "families" })
  end

  test "build appends BuildRecorded carrying the placement coord" do
    hand_terrain = @player.hand.first
    target = first_empty_terrain(hand_terrain)
    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])

    rec = cs.find { |c| c.is_a?(Turn::Consequences::BuildRecorded) }
    refute_nil rec
    assert_equal "[#{target[0]}, #{target[1]}]", rec.at
  end

  test "build appends GoalScored(ambassadors, 1) when adjacent to opponent and goal active" do
    @game.update!(goals: [ "ambassadors" ])
    hand_terrain = @player.hand.first
    target = first_empty_terrain(hand_terrain)
    nbr = @game.board_contents.neighbors(target[0], target[1]).first
    @game.board_contents.place_settlement(nbr[0], nbr[1], 1) # opponent
    @game.save!
    @game.reload
    @game.instantiate

    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])
    score = cs.find { |c| c.is_a?(Turn::Consequences::GoalScored) && c.goal == "ambassadors" }
    refute_nil score
    assert_equal 1, score.points
  end

  test "build does NOT score ambassadors when goal is inactive" do
    @game.update!(goals: [])
    hand_terrain = @player.hand.first
    target = first_empty_terrain(hand_terrain)
    nbr = @game.board_contents.neighbors(target[0], target[1]).first
    @game.board_contents.place_settlement(nbr[0], nbr[1], 1)
    @game.save!
    @game.reload
    @game.instantiate

    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::GoalScored) && c.goal == "ambassadors" })
  end

  test "build appends GoalScored(shepherds, 2) when no adjacent same-terrain empty and goal active" do
    @game.update!(goals: [ "shepherds" ])
    hand_terrain = @player.hand.first
    target = first_empty_terrain(hand_terrain)
    # Force shepherds_match?: occupy every neighbor so none are empty matching-terrain.
    @game.board_contents.neighbors(target[0], target[1]).each do |nr, nc|
      @game.board_contents.place_settlement(nr, nc, 1)
    end
    @game.save!
    @game.reload
    @game.instantiate

    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])
    score = cs.find { |c| c.is_a?(Turn::Consequences::GoalScored) && c.goal == "shepherds" }
    refute_nil score
    assert_equal 2, score.points
  end

  test "build appends MeepleGranted when picking up a meeple-granting tile" do
    hand_terrain = @player.hand.first
    target = first_empty_terrain(hand_terrain)
    nbr = @game.board_contents.neighbors(target[0], target[1]).first
    @game.board_contents.place_tile(nbr[0], nbr[1], "BarracksTile", 1)
    @game.save!
    @game.reload
    @game.instantiate

    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])

    grants = cs.select { |c| c.is_a?(Turn::Consequences::MeepleGranted) }
    assert_equal 1, grants.size
    assert_equal "warrior", grants.first.kind
    assert_equal 2, grants.first.qty
    assert_equal @player.order, grants.first.player
  end

  test "build appends GoalScored + TileDiscarded for a Treasure pickup" do
    hand_terrain = @player.hand.first
    target = first_empty_terrain(hand_terrain)
    nbr = @game.board_contents.neighbors(target[0], target[1]).first
    @game.board_contents.place_tile(nbr[0], nbr[1], "TreasureTile", 1)
    @game.save!
    @game.reload
    @game.instantiate

    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])

    score = cs.find { |c| c.is_a?(Turn::Consequences::GoalScored) }
    discard = cs.find { |c| c.is_a?(Turn::Consequences::TileDiscarded) }
    refute_nil score, "expected GoalScored for treasure"
    refute_nil discard, "expected TileDiscarded for treasure"
    assert_equal "treasure", score.goal
    assert_equal 3, score.points
    assert_equal "TreasureTile", discard.klass
  end

  test "build does not append MeepleGranted for non-granting tiles" do
    hand_terrain = @player.hand.first
    target = first_empty_terrain(hand_terrain)
    nbr = @game.board_contents.neighbors(target[0], target[1]).first
    @game.board_contents.place_tile(nbr[0], nbr[1], "OracleTile", 1)
    @game.save!
    @game.reload
    @game.instantiate

    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::MeepleGranted) })
  end

  test "build does not append TilePickedUp for tiles in player's taken_from" do
    hand_terrain = @player.hand.first
    target = first_empty_terrain(hand_terrain)
    nbr = @game.board_contents.neighbors(target[0], target[1]).first
    @game.board_contents.place_tile(nbr[0], nbr[1], "OracleTile", 2)
    @game.save!
    @player.update!(taken_from: [ "[#{nbr[0]}, #{nbr[1]}]" ])
    @game.reload
    @game.instantiate

    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::TilePickedUp) })
  end

  test "build errors when target is not adjacency-valid" do
    hand_terrain = @player.hand.first
    seed = first_empty_terrain(hand_terrain)
    @game.board_contents.place_settlement(seed[0], seed[1], 0)
    @game.save!
    @game.reload
    @game.instantiate

    far = first_empty_terrain_not_adjacent_to(seed, hand_terrain)
    cs = turn.handle(:build, game: @game, row: far[0], col: far[1])
    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "build that errors does not append SubPhasePopped" do
    @game.current_action = {
      "turn" => {
        "sub_phase" => {
          "type" => Turn::SubPhases::TileBuildPhase::TYPE,
          "state" => { "restricted_terrain" => "G", "tile_klass" => "FarmTile", "tile_source" => "[3, 4]" }
        }
      }
    }
    far_r, far_c = first_empty_terrain_other_than("G")
    consequences = turn.handle(:build, game: @game, row: far_r, col: far_c)
    assert_kind_of Turn::Consequences::Error, consequences.first
    refute(consequences.any? { |c| c.is_a?(Turn::Consequences::SubPhasePopped) })
  end

  test "unsupported action returns Error" do
    consequences = turn.handle(:nonsense, game: @game)
    assert_kind_of Turn::Consequences::Error, consequences.first
  end

  private

  def first_empty_grass
    first_empty_terrain("G")
  end

  def first_empty_terrain(terrain)
    20.times do |row|
      20.times do |col|
        next unless @game.board.terrain_at(row, col) == terrain
        return [ row, col ] if @game.board_contents.empty?(row, col)
      end
    end
    raise "no empty #{terrain} hex"
  end

  def first_buildable_hex
    20.times do |r|
      20.times do |c|
        next unless [ "C", "D", "F", "G", "T" ].include?(@game.board.terrain_at(r, c))
        return [ r, c ] if @game.board_contents.empty?(r, c)
      end
    end
    raise "no buildable hex"
  end

  def first_empty_terrain_other_than(terrain)
    20.times do |row|
      20.times do |col|
        t = @game.board.terrain_at(row, col)
        next if t.nil? || t == terrain
        return [ row, col ] if @game.board_contents.empty?(row, col)
      end
    end
    raise "no empty non-#{terrain} hex"
  end

  def first_isolated_terrain_hex(terrain)
    20.times do |row|
      20.times do |col|
        next unless @game.board.terrain_at(row, col) == terrain
        next unless @game.board_contents.empty?(row, col)
        if @game.board_contents.neighbors(row, col).none? { |nr, nc|
             @game.board.terrain_at(nr, nc) == terrain && @game.board_contents.empty?(nr, nc)
           }
          return [ row, col ]
        end
      end
    end
    nil
  end

  def first_empty_terrain_not_adjacent_to(seed, terrain)
    seed_r, seed_c = seed
    neighbor_set = @game.board_contents.neighbors(seed_r, seed_c).to_set
    20.times do |r|
      20.times do |c|
        next unless @game.board.terrain_at(r, c) == terrain
        next unless @game.board_contents.empty?(r, c)
        next if [ r, c ] == seed
        next if neighbor_set.include?([ r, c ])
        return [ r, c ]
      end
    end
    raise "no far #{terrain} hex"
  end
end
