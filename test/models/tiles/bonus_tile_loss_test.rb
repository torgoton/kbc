require "test_helper"

class Tiles::BonusTileLossTest < ActiveSupport::TestCase
  PAIRS = { "FountainTile" => "FountainBonusTile", "TempleTile" => "TempleBonusTile",
            "CanoeTile" => "CanoeBonusTile", "RefugeTile" => "RefugeBonusTile" }.freeze

  def setup
    @game = games(:game2player)
    @game.boards = [ [ 2, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @chris = game_players(:chris)
    @game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 2, @chris.order) }
    @game.save!
  end

  def forfeit_with(parent, bonus, froms)
    tiles = froms.map { |f| { "klass" => parent, "from" => f, "used" => false } }
    @chris.update!(tiles: tiles + [ { "klass" => bonus, "from" => nil, "used" => false } ])
    @game.instantiate
    TurnEngine.new(@game).apply_tile_forfeit(@chris)
    @chris.tiles.map { |t| t["klass"] }
  end

  PAIRS.each do |parent, bonus|
    test "#{bonus} is lost when one of two #{parent} copies is forfeited" do
      assert_equal [ parent ], forfeit_with(parent, bonus, [ "[5, 3]", "[9, 9]" ])
    end

    test "#{bonus} is lost when both #{parent} copies are forfeited" do
      assert_empty forfeit_with(parent, bonus, [ "[9, 8]", "[9, 9]" ])
    end

    test "#{bonus} is kept while both #{parent} copies are held" do
      assert_equal [ parent, parent, bonus ], forfeit_with(parent, bonus, [ "[5, 3]", "[5, 1]" ])
    end
  end
end
