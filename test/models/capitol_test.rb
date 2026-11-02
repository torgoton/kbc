require "test_helper"

class CapitolTest < ActiveSupport::TestCase
  def capitol_game(board_ids: nil)
    loop do
      game = Game.new(state: "waiting", options: { "queenies" => [ "emperors_choice" ], "decree_chance" => 100 })
      game.add_player(users(:chris))
      game.add_player(users(:jules))
      game.save!
      game.start
      next game.destroy unless game.capitol?
      return game if board_ids.nil? || board_ids.call(game.boards.map(&:first))
      game.destroy
    end
  end

  test "each of boards 2, 7 and 21 in play gets a Capitol on one of its Castles" do
    game = capitol_game(board_ids: ->(ids) { (ids & Game::CAPITOL_BOARD_IDS).any? })
    board = game.instantiate
    wanted = game.boards.map(&:first) & Game::CAPITOL_BOARD_IDS
    assert_equal wanted.size, game.capitol_hexes.size
    assert_equal game.capitol_hexes.to_set, board.silver_hexes_of("Capitol").to_set
    assert_includes game.goals, "capitol"
  end

  test "with none of those boards, one random Castle becomes the Capitol" do
    game = capitol_game(board_ids: ->(ids) { (ids & Game::CAPITOL_BOARD_IDS).empty? })
    assert_equal 1, game.capitol_hexes.size
    assert_includes game.goals, "capitol"
  end

  test "placing the Capitol is logged" do
    game = capitol_game
    move = game.moves.find_by!(action: "place_capitols")
    assert_equal "Capitol placed: #{game.capitol_hexes.map { |r, c| "[#{r},#{c}]" }.join(", ")}", move.message
  end
end
