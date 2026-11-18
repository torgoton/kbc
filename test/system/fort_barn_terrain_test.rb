require "application_system_test_case"

# Fort draws a card of a different terrain mid-turn; the Barn afterwards must still move a
# settlement onto the *played* card's terrain, not the Fort card's.
class FortBarnTerrainSystemTest < ApplicationSystemTestCase
  setup do
    @game = games(:game2player)
    @chris = game_players(:chris)
    # Rows 0-4 of this layout: Timberland at cols 5-7 of rows 0-3, Grass at (1,8), (0,7), (0,8)...
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @game.board_contents = BoardState.new.tap { |s| s.place_settlement(1, 6, @chris.order) }
    @game.update!(
      current_action: { "type" => "mandatory" },
      mandatory_count: Game::MANDATORY_COUNT,
      deck: %w[G D F],
      discard: []
    )
    @chris.update!(
      hand: [ "T" ],
      tiles: [
        { "klass" => "FortTile", "from" => "[3, 3]", "used" => false },
        { "klass" => "BarnTile", "from" => "[9, 9]", "used" => false }
      ]
    )
  end

  # Wait for the hex to be highlighted first: broadcasts re-render the board and drop early clicks.
  def click_hex(row, col)
    assert_selector "#map-cell-#{row}-#{col}.selectable"
    page.execute_script(<<~JS)
      document.getElementById("build_row").value = #{row};
      document.getElementById("build_col").value = #{col};
      document.getElementById("action_submit").click();
    JS
  end

  def submit(selector)
    find(selector, visible: false)
    page.execute_script("document.querySelector(\"#{selector}\").requestSubmit()")
  end

  def buildable_cells
    JSON.parse(find("#current-action", visible: false)[:"data-buildable"])
  end

  # Mandatory builds on Timberland (the played card), Fort draws +fort_card+ (in neither hand card)
  # and builds on +fort_hex+, then Barn picks up (1,5): targets must all be Timberland.
  def assert_barn_targets_only_played_terrain(hand:, fort_card:, fort_hex:)
    @game.update!(deck: [ fort_card, "F", "S" ])
    @chris.update!(hand: hand)
    assert_not_includes hand, fort_card
    sign_in(email_address: "chris@example.com")
    visit game_path(@game)

    [ [ 1, 5 ], [ 1, 7 ], [ 0, 6 ] ].each_with_index do |(r, c), i|
      click_hex(r, c)
      assert_selector "body", text: "built a settlement on Timberland at [#{r}, #{c}]"
      assert_equal Game::MANDATORY_COUNT - i - 1, @game.reload.mandatory_count
    end

    submit "form[action='#{activate_fort_game_path(@game)}']"
    assert_selector "#current-action[data-type='fort']", visible: false
    click_hex(*fort_hex)
    assert_selector "#current-action[data-type='mandatory']", visible: false
    @game.reload.instantiate
    board = @game.board_contents
    assert_equal fort_card, board.terrain_at(*fort_hex)
    assert_equal @chris.order, board.player_at(*fort_hex)

    submit "form[action='#{select_action_game_path(@game)}']:has(.player-tile.tile-activatable .tile-container.barn)"
    assert_selector "#current-action[data-type='barn']", visible: false
    click_hex(1, 5)
    assert_selector "#current-action[data-from='[1, 5]']", visible: false

    targets = buildable_cells
    assert_not_empty targets
    terrains = targets.map { |r, c| board.terrain_at(r, c) }.uniq
    assert_equal [ "T" ], terrains, "Barn targets must all be Timberland, got #{terrains.inspect}"
  end

  test "Barn moves only to the played terrain after a Fort build on a different terrain" do
    assert_barn_targets_only_played_terrain(hand: [ "T" ], fort_card: "G", fort_hex: [ 1, 8 ])
  end

  # Two-card hand (unlocked until the first build): the Fort must not unlock the choice.
  # Grass is in hand and adjacent to the settlements, so a lost lock would offer it.
  # Fort draws Desert (not in hand); none is adjacent, so any Desert hex is legal.
  test "Barn keeps the played terrain lock with a two-card hand after Fort draws a third terrain" do
    assert_barn_targets_only_played_terrain(hand: [ "T", "G" ], fort_card: "D", fort_hex: [ 0, 0 ])
  end
end
