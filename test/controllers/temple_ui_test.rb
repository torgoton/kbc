require "test_helper"

class TempleUiTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    @game = games(:game2player)
    @chris = game_players(:chris)
    @chris.update!(hand: [ "G" ], supply: { "settlements" => 10, "temple_due" => %w[settlement wagon] })
    @game.update!(mandatory_count: 2)
  end

  test "different owed pieces are offered as a choice" do
    get game_url(@game)

    %w[settlement wagon].each do |piece|
      assert_select "form[action='#{choose_temple_piece_game_path(@game, piece:)}'] button", text: piece.capitalize
    end
  end

  test "POST choose_temple_piece selects the piece to build next" do
    post choose_temple_piece_game_url(@game, piece: "wagon")

    assert_equal "wagon", @chris.reload.supply["temple_pick"]
  end

  test "no choice is offered for a single owed piece" do
    @chris.update!(supply: { "settlements" => 10, "temple_due" => %w[wagon] })
    @game.update!(mandatory_count: 1)

    get game_url(@game)

    assert_select "form[action='#{choose_temple_piece_game_path(@game, piece: "wagon")}']", count: 0
  end
end
