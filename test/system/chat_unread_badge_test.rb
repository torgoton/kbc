require "application_system_test_case"

class ChatUnreadBadgeTest < ApplicationSystemTestCase
  setup do
    @game = games(:game2player)
    @chris = game_players(:chris)
  end

  test "unread badge counts chat messages but ignores other game broadcasts" do
    sign_in(email_address: "chris@example.com")
    assert_selector "h1", text: "KBC Dashboard"

    visit game_path(@game)
    # Reset any chat panel state (minimized/split) left over in this browser
    # profile by a previous test, so this test starts from a known state.
    page.execute_script("window.localStorage.clear()")
    visit game_path(@game)

    assert_no_selector "#chat.minimized"
    page.execute_script('document.querySelector(".chat-minimize-btn").click()')
    assert_selector "#chat.minimized"

    @game.move_count += 1
    @game.moves.create!(
      order: @game.move_count,
      game_player: @chris,
      action: "select_action",
      message: "Chris did something",
      deliberate: true,
      reversible: false
    )
    @game.broadcast_game_update
    assert_text "Chris did something"
    assert_selector ".chat-badge.hidden", visible: :all

    ChatMessage.create!(game: @game, game_player: @chris, body: "hello there")
    assert_selector ".chat-badge", text: "1"
  end
end
