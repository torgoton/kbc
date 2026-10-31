require "test_helper"

class BazaarUiTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    @game = games(:game2player)
    @chris = game_players(:chris)
    @game.update!(current_action: { "type" => "mandatory" }, mandatory_count: 3)
    # Farm board at index 2: the settlement at (14,0) is Canyon beside Grass.
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @game.board_contents = BoardState.new.tap { |s| s.place_settlement(14, 0, @chris.order) }
    @game.save!
    @chris.update!(
      hand: [ "G" ],
      supply: { "settlements" => 30, "cathedral" => 2 },
      tiles: [
        { "klass" => "BazaarTile", "from" => "[3, 3]", "used" => false },
        { "klass" => "FarmTile", "from" => "[3, 4]", "used" => true },
        { "klass" => "CathedralTile", "from" => "[3, 5]", "used" => false }
      ]
    )
  end

  test "the Bazaar tile opens a popup listing what it can copy, with Cancel" do
    get game_url(@game)

    assert_select ".player-tile-popup .meeple-popup" do
      assert_select "form[action='#{activate_bazaar_game_path(@game, klass: "FarmTile")}'] button", text: "Copy Farm"
      assert_select "form[action='#{activate_bazaar_game_path(@game, klass: "CathedralTile", mode: "add")}'] button", text: "Copy Cathedral: Add 1 to Count"
      assert_select "form[action='#{activate_bazaar_game_path(@game, klass: "CathedralTile", mode: "build")}'] button", text: "Copy Cathedral: Build (2 left)"
      assert_select "button", text: "Cancel"
    end
  end

  test "POST activate_bazaar copies the action: Bazaar is selected and the Farm phase begins" do
    post activate_bazaar_game_url(@game, klass: "FarmTile")

    assert_equal "farm", @game.reload.current_action["type"]
    assert_equal %w[select_action bazaar_copy], @game.moves.order(:order).pluck(:action)
  end

  test "POST activate_bazaar refuses a tile that is not offered" do
    post activate_bazaar_game_url(@game, klass: "CanoeTile")

    assert_equal "mandatory", @game.reload.current_action["type"]
    assert_empty @game.moves
  end

  test "POST activate_bazaar does nothing for the wrong player" do
    delete session_url
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    post activate_bazaar_game_url(@game, klass: "FarmTile")

    assert_equal "mandatory", @game.reload.current_action["type"]
  end
end
