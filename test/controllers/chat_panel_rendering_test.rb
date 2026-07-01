require "test_helper"

class ChatPanelRenderingTest < ActionDispatch::IntegrationTest
  test "an active player sees the chat composer" do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    game = games(:game2player)

    get game_url(game)

    assert_select "form[action='#{game_chat_messages_path(game)}']"
  end

  test "a resigned player sees a closed note instead of the composer" do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    game = games(:game2player)
    game_players(:chris).update!(resigned_at: Time.current)

    get game_url(game)

    assert_select "form[action='#{game_chat_messages_path(game)}']", count: 0
    assert_select ".chat-closed-note"
  end

  test "a player sees a closed note once chat has closed after game completion" do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    game = games(:completed_game)
    game.update!(completed_at: 11.minutes.ago)

    get game_url(game)

    assert_select "form[action='#{game_chat_messages_path(game)}']", count: 0
    assert_select ".chat-closed-note"
  end

  test "existing chat messages render with the sender's handle and player color class" do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    game = games(:game2player)
    game.chat_messages.create!(game_player: game_players(:chris), body: "hi there")

    get game_url(game)

    assert_select ".chat-message.a", text: /hi there/
    assert_select ".chat-message .handle", text: users(:chris).handle
  end

  test "the game-end system message renders without a handle" do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    game = games(:game2player)
    game.chat_messages.create!(game_player: nil, body: "Game ended.")

    get game_url(game)

    assert_select ".chat-message.system", text: /Game ended\./
    assert_select ".chat-message.system .handle", count: 0
  end
end
