require "test_helper"

class NativeSoilTest < ActiveSupport::TestCase
  def started_game(extra = {})
    options = { "queenies" => [ "emperors_choice" ], "decree_chance" => 100 }.merge(extra)
    game = Game.new(state: "waiting", options:)
    game.add_player(users(:chris))
    game.add_player(users(:jules))
    game.save!
    game
  end

  # Draw until Native Soil comes up (the pool has more than one decree).
  def native_soil_game(extra = {})
    loop do
      game = started_game(extra)
      game.start
      return game if game.native_soil?
    end
  end

  test "Native Soil takes every card of one terrain out of the deck before anyone is dealt" do
    game = native_soil_game
    terrain = game.native_soil
    assert_includes %w[C D F G T], terrain
    # 25 - 5 removed - 2 dealt
    assert_equal 18, game.deck.size + game.discard.size
    assert (game.deck + game.discard + game.game_players.flat_map(&:hand)).none? { |c| c.include?(terrain) }
  end

  test "with Marshlands the dual card goes too: 6 cards" do
    game = native_soil_game("expansions" => %w[marshlands])
    scouts_cards = game.removed_terrain ? 6 : 0 # the Marshlands Scouts goal may also have drawn
    assert_equal 30 - 6 - scouts_cards - 2, game.deck.size + game.discard.size
  end

  test "Scouts removes a different terrain from the remaining deck" do
    game = nil
    loop do
      game = started_game
      game.update!(goals: [ "scouts" ])
      game.send(:initialize_terrain_deck)
      game.send(:select_decree)
      break if game.native_soil?
    end
    game.send(:remove_scouts_terrain)
    assert_not_equal game.native_soil, game.removed_terrain
    assert_equal 15, game.deck.size
  end

  test "every player's hand terrains include Native Soil, but the card is never in their hand" do
    game = native_soil_game
    game.game_players.each do |gp|
      assert_includes gp.hand_terrains, game.native_soil
      assert_not_includes Array(gp.hand), game.native_soil
    end
  end

  test "no decree, no Native Soil" do
    game = started_game("decree_chance" => 0)
    game.start
    assert_nil game.native_soil
  end
end
