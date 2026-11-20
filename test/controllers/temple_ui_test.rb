require "test_helper"

class TempleUiTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    @game = games(:game2player)
    @chris = game_players(:chris)
    @chris.update!(hand: [ "G" ], supply: { "settlements" => 10, "temple_due" => %w[settlement wagon] })
    @game.update!(mandatory_count: 2)
  end

  def choice_form(piece) = "form[action='#{choose_temple_piece_game_path(@game, piece:)}']"

  test "different owed pieces show as clickable icons in the player area" do
    get game_url(@game)

    %w[settlement wagon].each do |piece|
      assert_select ".supply-display #{choice_form(piece)} button.temple-piece svg"
    end
    assert_select choice_form("wagon"), count: 1 # only the icon, no separate button elsewhere
  end

  test "the piece to be built next is highlighted" do
    get game_url(@game)
    assert_select "#{choice_form("settlement")} button.selected"
    assert_select "#{choice_form("wagon")} button.selected", count: 0

    @chris.update!(supply: @chris.supply.merge("temple_pick" => "wagon"))
    get game_url(@game)
    assert_select "#{choice_form("wagon")} button.selected"
    assert_select "#{choice_form("settlement")} button.selected", count: 0
  end

  test "POST choose_temple_piece selects the piece to build next" do
    post choose_temple_piece_game_url(@game, piece: "wagon")

    assert_equal "wagon", @chris.reload.supply["temple_pick"]
  end

  test "identical owed pieces show one icon and offer no choice" do
    @chris.update!(supply: { "settlements" => 10, "temple_due" => %w[ship ship] })

    get game_url(@game)

    assert_select ".supply-display .temple-piece", count: 1
    assert_select ".supply-display form[action='#{choose_temple_piece_game_path(@game, piece: "ship")}']", count: 0
  end

  test "a single owed piece is shown but not clickable" do
    @chris.update!(supply: { "settlements" => 10, "temple_due" => %w[wagon] })
    @game.update!(mandatory_count: 1)

    get game_url(@game)

    assert_select ".supply-display .temple-piece", count: 1
    assert_select "form[action='#{choose_temple_piece_game_path(@game, piece: "wagon")}']", count: 0
  end

  test "pieces set aside this turn show as icons, once per type" do
    @chris.update!(supply: { "settlements" => 10, "set_aside" => %w[settlement settlement wagon] })
    @game.update!(mandatory_count: 3)

    get game_url(@game)

    assert_select ".supply-display .set-aside .temple-piece", count: 2
  end
end
