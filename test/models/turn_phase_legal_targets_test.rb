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
