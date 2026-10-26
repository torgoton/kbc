require "application_system_test_case"

class MarshlandsSystemTest < ApplicationSystemTestCase
  setup do
    @game = games(:game2player)
    @chris = game_players(:chris)
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ] # board 1 row 0: (0,4) is Water
    @game.board_contents = BoardState.new.tap { |s| s.place_settlement(0, 5, @chris.order) }
    @game.update!(current_action: { "type" => "mandatory" }, mandatory_count: Game::MANDATORY_COUNT)
  end

  def submit_click(row, col)
    page.execute_script(<<~JS)
      document.getElementById("build_row").value = #{row};
      document.getElementById("build_col").value = #{col};
      document.getElementById("action_submit").click();
    JS
  end

  test "a dual Swamp card renders split" do
    @chris.update!(hand: [ "GB" ], tiles: [])
    sign_in(email_address: "chris@example.com")
    visit game_path(@game)

    assert_selector ".player-card.card-dual .card-half.card-G"
    assert_selector ".player-card.card-dual .card-half.card-B"
  end

  test "Canoe Bonus tile is selectable and builds on Water" do
    @chris.update!(hand: [ "G" ], tiles: [ { "klass" => "CanoeBonusTile", "used" => false, "from" => nil } ])
    sign_in(email_address: "chris@example.com")
    visit game_path(@game)

    # submit the form directly: a native click is intermittently "not interactable" in the short test window
    find(".player-tile.category-bonus.tile-activatable").find(:xpath, "ancestor::form")
    page.execute_script("document.querySelector('.player-tile.category-bonus.tile-activatable').closest('form').requestSubmit()")
    assert_selector "#current-action[data-type='canoebonus']", visible: false
    submit_click(0, 4)

    assert_selector ".player-tile.tile-used .tile-container.canoebonus"
    assert_equal @chris.order, @game.reload.board_contents.player_at(0, 4)
  end

  test "emptying a location offers the Canoe holder Confirm gate, then hands to the holder" do
    paula = game_players(:paula)
    paula.update!(tiles: [ { "klass" => "CanoeTile", "used" => false, "from" => "[9, 9]" } ])
    @game.board_contents = BoardState.new.tap do |s|
      s.place_settlement(0, 5, @chris.order)
      s.place_tile(0, 7, "RefugeTile", 1)
    end
    @game.save!
    @chris.update!(hand: [ "T" ], tiles: [])
    sign_in(email_address: "chris@example.com")
    visit game_path(@game)

    submit_click(0, 6) # Timberland next to the Refuge; the build takes its last tile
    assert_selector "form[action='#{confirm_canoe_game_path(@game)}']"
    page.execute_script("document.querySelector(\"form[action='#{confirm_canoe_game_path(@game)}']\").requestSubmit()")

    assert_no_selector "form[action='#{confirm_canoe_game_path(@game)}']"
    assert_equal "canoe", @game.reload.turn_phase.type
    assert_equal paula, @game.current_player
  end
end
