require "test_helper"

# Unit tests for each phase's legal_targets — the composite "legal targets for
# the active sub-phase" query (ADR-0001), owned by the phase (State pattern)
# rather than a conditional in TurnEngine. Scenario/tile tests cover the
# end-to-end parity; these pin each phase's rule in isolation.
class TurnPhaseLegalTargetsTest < ActiveSupport::TestCase
  test "base TurnPhase has no legal targets" do
    assert_equal [], TurnPhase.new.legal_targets(board_contents: BoardState.new, player: nil)
  end

  test "TargetedRemovalPhase targets the pending opponents' settlements, excluding city hall hexes" do
    board = BoardState.new
    board.place_settlement(5, 5, 1)
    board.place_settlement(6, 6, 1)
    board.place_settlement(8, 8, 2) # a non-targeted player's settlement
    board.place_city_hall_hex(5, 7, 1)
    phase = TurnPhase::TargetedRemovalPhase.new(
      action_type: "sword", klass_name: "SwordTile", pending_orders: [ 1 ]
    )

    targets = phase.legal_targets(board_contents: board, player: nil)

    assert_includes targets, [ 5, 5 ]
    assert_includes targets, [ 6, 6 ]
    assert_not_includes targets, [ 8, 8 ], "only pending opponents are targetable"
    assert_not_includes targets, [ 5, 7 ], "city hall hexes are not removable"
  end

  test "CityHallPhase delegates to the tile's valid destinations" do
    game, player = playing_game(hand: [ "G" ])
    player.add_city_halls!(1)
    player.save!
    board = with_terrain(game.board_contents, game.instantiate)
    board.place_settlement(1, 3, player.order)
    phase = TurnPhase::CityHallPhase.new(action_type: "cityhall", klass_name: "CityHallTile")

    expected = Tiles::Location::CityHallTile.new(0).valid_destinations(
      board_contents: board, player_order: player.order, supply: player.supply_hash
    )
    assert_equal expected, phase.legal_targets(board_contents: board, player: player)
    assert expected.any?, "fixed board should offer a city hall cluster next to the settlement"
  end

  test "FortPhase targets empty hexes of the drawn fort terrain" do
    game, player = playing_game(hand: [ "G" ])
    board = with_terrain(game.board_contents, game.instantiate)
    phase = TurnPhase::FortPhase.new(fort_terrain: "D")

    targets = phase.legal_targets(board_contents: board, player: player)

    assert targets.any?
    targets.each { |r, c| assert_equal "D", board.terrain_at(r, c) }
  end

  test "SettlementMovePhase without a source lists the movable settlements; with one, its destinations" do
    game, player = playing_game(hand: [ "G" ])
    board = with_terrain(game.board_contents, game.instantiate)
    board.place_settlement(5, 6, player.order)
    tile = Tiles::Location::PaddockTile.new(0)

    unsourced = TurnPhase::SettlementMovePhase.new(action_type: "paddock", klass_name: "PaddockTile")
    assert_equal tile.selectable_settlements(player_order: player.order, board_contents: board, hand: "G", budget: 0),
      unsourced.legal_targets(board_contents: board, player: player)
    assert_includes unsourced.legal_targets(board_contents: board, player: player), [ 5, 6 ]

    sourced = TurnPhase::SettlementMovePhase.new(action_type: "paddock", klass_name: "PaddockTile", from: "[5, 6]")
    assert_equal tile.valid_destinations(from_row: 5, from_col: 6, board_contents: board, player_order: player.order, hand: "G", budget: 0),
      sourced.legal_targets(board_contents: board, player: player)
  end

  test "ResettlementPhase gates its destinations by the remaining step budget" do
    game, player = playing_game(hand: [ "G" ])
    board = with_terrain(game.board_contents, game.instantiate)
    board.place_settlement(5, 6, player.order)
    tile = Tiles::Nomad::ResettlementTile.new(0)

    phase = TurnPhase::ResettlementPhase.new(budget: 4, moves: 0, from: "[5, 6]")
    assert_equal tile.valid_destinations(from_row: 5, from_col: 6, board_contents: board, player_order: player.order, hand: "G", budget: 4),
      phase.legal_targets(board_contents: board, player: player)
  end

  test "MeepleActionPhase delegates to the tile's valid destinations (barracks placement)" do
    game, player = playing_game(hand: [ "G" ])
    player.add_warriors!(2)
    player.save!
    board = with_terrain(game.board_contents, game.instantiate)
    board.place_settlement(1, 1, player.order)
    tile = Tiles::Tile.for_klass("BarracksTile").new(0)
    phase = TurnPhase::MeepleActionPhase.new(action_type: "barracks", klass_name: "BarracksTile")

    expected = tile.valid_destinations(board_contents: board, player_order: player.order, supply: player.supply_hash)
    assert_equal expected, phase.legal_targets(board_contents: board, player: player)
    assert expected.any?
  end

  test "MeepleMovementPhase offers placement before a source and nothing once the budget is spent" do
    game, player = playing_game(hand: [ "G" ])
    player.add_wagons!(1)
    player.save!
    board = with_terrain(game.board_contents, game.instantiate)
    tile = Tiles::Tile.for_klass("WagonTile").new(0)

    unsourced = TurnPhase::MeepleMovementPhase.new(action_type: "wagon", klass_name: "WagonTile")
    assert_equal tile.valid_destinations(board_contents: board, player_order: player.order, supply: player.supply_hash),
      unsourced.legal_targets(board_contents: board, player: player)

    spent = TurnPhase::MeepleMovementPhase.new(action_type: "wagon", klass_name: "WagonTile", from: "[3, 3]", budget: 0, moves: 3)
    assert_empty spent.legal_targets(board_contents: board, player: player)
  end

  test "TileBuildPhase (quarry) has no wall targets when stone walls are exhausted" do
    game, player = playing_game(hand: [ "G" ])
    game.update!(stone_walls: 0)
    board = with_terrain(game.board_contents, game.instantiate)
    board.place_settlement(5, 6, player.order)
    phase = TurnPhase::TileBuildPhase.new(action_type: "quarry", klass_name: "QuarryTile")

    assert_empty phase.legal_targets(board_contents: board, player: player, game: game)
  end

  test "TileBuildPhase (build tile) targets the tile's terrain" do
    game, player = playing_game(hand: [ "G" ])
    board = with_terrain(game.board_contents, game.instantiate)
    tile = Tiles::Tile.for_klass("OasisTile").new(0) # builds on Desert
    phase = TurnPhase::TileBuildPhase.new(action_type: "oasis", klass_name: "OasisTile")

    targets = phase.legal_targets(board_contents: board, player: player, game: game)
    assert_equal tile.valid_destinations(board_contents: board, player_order: player.order, hand: "G"), targets
    assert targets.any?
  end

  test "TileBuildPhase with outpost active spans the whole build terrain, adjacency waived" do
    game, player = playing_game(hand: [ "D" ])
    board = with_terrain(game.board_contents, game.instantiate)
    phase = TurnPhase::TileBuildPhase.new(action_type: "oasis", klass_name: "OasisTile", outpost_active: true)

    targets = phase.legal_targets(board_contents: board, player: player, game: game)

    assert_equal board.available_cells_of([ "D" ]).to_set, targets.to_set
    assert targets.any?
  end

  test "MandatoryBuildPhase uses the adjacent-else-anywhere rule, and none once mandatory is done" do
    game, player = playing_game(hand: [ "G" ])
    board = with_terrain(game.board_contents, game.instantiate)
    phase = TurnPhase::MandatoryBuildPhase.new

    assert_equal board.buildable_cells_for(player.order, "G"),
      phase.legal_targets(board_contents: board, player: player, game: game)

    game.update!(mandatory_count: 0)
    assert_empty phase.legal_targets(board_contents: board, player: player, game: game)
  end

  test "MandatoryBuildPhase with a two-card hand spans both terrains" do
    game, player = playing_game(hand: %w[G D])
    board = with_terrain(game.board_contents, game.instantiate)
    phase = TurnPhase::MandatoryBuildPhase.new

    targets = phase.legal_targets(board_contents: board, player: player, game: game)
    terrains = targets.map { |cell| board.terrain_at(*cell) }.uniq

    assert_includes terrains, "G"
    assert_includes terrains, "D"
  end

  private

  # A minimal playing game on the scenario's fixed board, with a clean board.
  def playing_game(hand:)
    game = Game.create!(
      state: "playing", boards: [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ],
      board_contents: BoardState.new, deck: %w[T G C D F], discard: [],
      mandatory_count: Game::MANDATORY_COUNT, move_count: 0,
      current_action: { "type" => "mandatory" }
    )
    user = User.create!(handle: "lt#{game.id}", email_address: "lt#{game.id}@example.com", password: "password", approved: true)
    player = GamePlayer.create!(game: game, player: user, order: 0, hand: hand,
      supply: { "settlements" => Game::SETTLEMENTS_PER_PLAYER }, tiles: [])
    game.update!(current_player: player)
    [ game, player ]
  end
end
