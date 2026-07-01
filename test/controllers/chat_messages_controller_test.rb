require "test_helper"

class ChatMessagesControllerTest < ActionDispatch::IntegrationTest
  test "a player in the game can post a chat message" do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    game = games(:game2player)

    assert_difference -> { game.chat_messages.count }, 1 do
      post game_chat_messages_url(game), params: { body: "hello" }
    end

    assert_response :no_content
    assert_equal "hello", game.chat_messages.last.body
  end

  test "a user who is not a player in the game cannot post a chat message" do
    post session_url, params: { email_address: "jules@example.com", password: "password" }
    game = games(:game2player)

    assert_no_difference -> { game.chat_messages.count } do
      post game_chat_messages_url(game), params: { body: "hello" }
    end

    assert_response :forbidden
  end

  test "a resigned player cannot post a chat message" do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    game = games(:game2player)
    game_players(:chris).update!(resigned_at: Time.current)

    assert_no_difference -> { game.chat_messages.count } do
      post game_chat_messages_url(game), params: { body: "hello" }
    end

    assert_response :forbidden
  end

  test "a player cannot post once chat has closed after game completion" do
    post session_url, params: { email_address: "chris@example.com", password: "password" }
    game = games(:completed_game)
    game.update!(completed_at: 11.minutes.ago)

    assert_no_difference -> { game.chat_messages.count } do
      post game_chat_messages_url(game), params: { body: "hello" }
    end

    assert_response :forbidden
  end
end
