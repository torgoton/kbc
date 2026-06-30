require "test_helper"
require "turbo/broadcastable/test_helper"

class ChatMessageTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper
  test "rejects a blank body" do
    game = games(:game2player)
    gp = game_players(:chris)
    message = ChatMessage.new(game: game, game_player: gp, body: "")

    assert_not message.valid?
    assert_includes message.errors[:body], "can't be blank"
  end

  test "rejects a body longer than 500 characters" do
    game = games(:game2player)
    gp = game_players(:chris)
    message = ChatMessage.new(game: game, game_player: gp, body: "a" * 501)

    assert_not message.valid?
    assert_includes message.errors[:body], "is too long (maximum is 500 characters)"
  end

  test "accepts a body at exactly the 500 character limit" do
    game = games(:game2player)
    gp = game_players(:chris)
    message = ChatMessage.new(game: game, game_player: gp, body: "a" * 500)

    assert message.valid?
  end

  test "creating a message broadcasts it to the game's chat-messages target" do
    game = games(:game2player)
    gp = game_players(:chris)

    broadcasts = capture_turbo_stream_broadcasts("game_#{game.id}") do
      ChatMessage.create!(game: game, game_player: gp, body: "hello")
    end

    assert broadcasts.any? { |b| b.to_s.include?(%(target="chat-messages")) && b.to_s.include?("hello") },
      "expected a chat-messages append broadcast containing the message body, got: #{broadcasts.inspect}"
  end

  test "creating a player message also broadcasts a chat play_sound" do
    game = games(:game2player)
    gp = game_players(:chris)

    broadcasts = capture_turbo_stream_broadcasts("game_#{game.id}") do
      ChatMessage.create!(game: game, game_player: gp, body: "hello")
    end

    assert broadcasts.any? { |b| b.to_s.include?(%(action="play_sound")) && b.to_s.include?(%(key="chat")) },
      "expected a play_sound[key=chat] broadcast, got: #{broadcasts.inspect}"
  end

  test "a system message (no game_player) does not broadcast a sound" do
    game = games(:game2player)

    broadcasts = capture_turbo_stream_broadcasts("game_#{game.id}") do
      ChatMessage.create!(game: game, game_player: nil, body: "Game ended.")
    end

    assert broadcasts.none? { |b| b.to_s.include?(%(action="play_sound")) },
      "system messages should not trigger the chat sound"
  end
end
