require "test_helper"

class CathedralUiTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    @game = games(:game2player)
    @chris = game_players(:chris)
    @game.update!(current_action: { "type" => "mandatory" }, mandatory_count: 3)
    @chris.update!(
      hand: [ "G" ],
      supply: { "settlements" => 30, "cathedral" => 2 },
      tiles: [ { "klass" => "CathedralTile", "from" => "[3, 3]", "used" => false } ]
    )
  end

  test "the Cathedral tile opens a modal with Add, Build with the count, and Cancel" do
    get game_url(@game)

    assert_select ".player-tile-popup .meeple-popup" do
      assert_select "form[action='#{activate_cathedral_game_path(@game, mode: "add")}'] button", text: "Add 1 to Count"
      assert_select "form[action='#{activate_cathedral_game_path(@game, mode: "build")}'] button:not([disabled])", text: "Build (2 left)"
      assert_select "button", text: "Cancel"
    end
  end

  test "Build is disabled when the count is 0" do
    @chris.update!(supply: { "settlements" => 30, "cathedral" => 0 })

    get game_url(@game)

    assert_select "form[action='#{activate_cathedral_game_path(@game, mode: "build")}'] button[disabled]", text: "Build (0 left)"
  end

  test "the Cathedral count is shown beside the settlement count" do
    get game_url(@game)

    assert_select ".supply-display .cathedral-count", text: /2/
  end

  test "the Cathedral count stays visible, idle, after the tile is lost" do
    @chris.update!(tiles: [])

    get game_url(@game)

    assert_select ".supply-display .cathedral-count", text: /2/
    assert_select ".player-tile-popup", count: 0
  end

  test "no Cathedral count is shown to a player who never had the tile" do
    @chris.update!(supply: { "settlements" => 30 }, tiles: [])

    get game_url(@game)

    assert_select ".cathedral-count", count: 0
  end

  test "POST activate_cathedral add adds 1 and ends the tile's use" do
    post activate_cathedral_game_url(@game, mode: "add")

    assert_equal 3, @chris.reload.cathedral_count
    assert @chris.tiles.first["used"]
  end

  test "POST activate_cathedral build enters the build phase" do
    post activate_cathedral_game_url(@game, mode: "build")

    assert_equal "cathedral", @game.reload.current_action["type"]
    assert_equal 2, @game.current_action["remaining"]
  end

  test "POST activate_cathedral does nothing for the wrong player" do
    delete session_url
    post session_url, params: { email_address: "paula@example.com", password: "password" }

    post activate_cathedral_game_url(@game, mode: "add")

    assert_equal 2, @chris.reload.cathedral_count
  end
end
