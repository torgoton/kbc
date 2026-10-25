require "test_helper"

class DualCardsTest < ActiveSupport::TestCase
  def game_with_hand(*hand)
    game = games(:game2player)
    game.boards = [ [ 17, 0 ], [ 1, 0 ], [ 0, 0 ], [ 4, 0 ] ] # board 17: (3,6)=B, (5,5)=G
    game.mandatory_count = 3
    game.save!
    game_players(:chris).update!(hand: hand)
    game
  end

  def click(game, row, col)
    TurnEngine.new(game).click(Coordinate.new(row, col))
    game.reload
  end

  test "a dual card offers both of its terrains" do
    game = game_with_hand("GB")
    assert_equal %w[G B], game_players(:chris).hand_terrains
    targets = game.turn_phase.legal_targets(board_contents: game.tap(&:instantiate).board_contents, player: game.current_player, game: game)
    assert_includes targets, [ 3, 6 ]
    assert_includes targets, [ 5, 5 ]
  end

  test "choosing Swamp makes the mandatory action 2 settlements" do
    game = click(game_with_hand("GB"), 3, 6)

    assert_equal "B", game.turn_phase.chosen_terrain
    assert_equal 1, game.mandatory_count
  end

  test "choosing the other terrain keeps 3 settlements" do
    game = click(game_with_hand("GB"), 5, 5)

    assert_equal "G", game.turn_phase.chosen_terrain
    assert_equal 2, game.mandatory_count
  end

  test "locking Swamp before the mandatory action leaves it untouched, so other tiles stay usable" do
    game = game_with_hand("GB")
    game_players(:chris).update!(tiles: [ { "klass" => "FarmTile", "from" => "[0, 0]", "used" => false } ])
    game.reload
    engine = TurnEngine.new(game)
    engine.lock_terrain!("B", nil) # as Oracle/Barn/Quarry would

    assert_equal 2, game.mandatory_count
    assert game.mandatory_untouched?(game.current_player)
    assert engine.tile_activatable?(game.current_player.tiles.first)
  end

  test "a played-terrain tile is selectable when only the Swamp half has targets" do
    # Board 17: (3,5) Flowers touches Swamp at (3,6) but no Grass.
    game = game_with_hand("GB")
    game.update!(stone_walls: 25, board_contents: BoardState.new.tap { |s| s.place_settlement(3, 5, game_players(:chris).order) })
    game_players(:chris).update!(tiles: [ { "klass" => "QuarryTile", "used" => false, "from" => "[9, 9]" } ])
    game.reload

    assert TurnEngine.new(game).tile_activatable?(game.current_player.tiles.first)
  end

  test "marshlands adds 5 dual cards to the terrain deck" do
    game = Game.new(options: { "expansions" => %w[marshlands] })
    game.send(:initialize_terrain_deck)

    cards = game.deck + game.discard
    assert_equal 30, cards.size
    assert_equal Game::MARSHLANDS_CARDS.sort, cards.select { |c| c.size == 2 }.sort
  end

  test "without marshlands the deck has no dual cards" do
    game = Game.new(options: {})
    game.send(:initialize_terrain_deck)

    assert_equal 25, (game.deck + game.discard).size
  end

  test "Scouts also removes dual cards offering the removed terrain" do
    game = Game.new(options: { "expansions" => %w[marshlands] }, goals: [ "scouts" ])
    game.send(:initialize_terrain_deck)

    cards = game.deck + game.discard
    assert_equal 24, cards.size
    assert cards.none? { |c| c.include?(game.removed_terrain) }
  end

  test "dual card name" do
    assert_equal "Grass / Swamp", Boards::Board.card_name("GB")
    assert_equal "Grass", Boards::Board.card_name("G")
  end

  test "card partial renders a dual card as two halves, shunned when the other terrain is chosen" do
    html = ApplicationController.render(partial: "games/card", locals: { card: "GB", shunned: true })
    assert_includes html, "card-dual"
    assert_includes html, "card-shunned"
    assert_includes html, "card-G"
    assert_includes html, "card-B"
    assert_includes html, 'title="Grass / Swamp"'
  end
end
