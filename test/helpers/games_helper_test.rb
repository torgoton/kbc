require "test_helper"

class GamesHelperTest < ActionView::TestCase
  test "sound_preload_keys includes all fixed keys" do
    game = Struct.new(:boards).new([])

    keys = sound_preload_keys(game)

    %w[build move select_settlement tile_pickup tile_forfeit
       my_turn game_end undo end_turn].each do |k|
      assert_includes keys, k, "expected fixed key #{k.inspect} in preload list"
    end
  end

  test "sound_preload_keys includes tile keys derived from game boards" do
    game = Struct.new(:boards).new([["Tavern", 0], ["Paddock", 1], ["Oasis", 2], ["Farm", 3]])

    keys = sound_preload_keys(game)

    assert_includes keys, "tavern"
    assert_includes keys, "paddock"
    assert_includes keys, "oasis"
    assert_includes keys, "farm"
    assert_not_includes keys, "harbor"
  end

  test "sound_preload_keys contains no duplicates" do
    game = Struct.new(:boards).new([["Tavern", 0], ["Paddock", 1]])

    keys = sound_preload_keys(game)

    assert_equal keys, keys.uniq
  end

  test "current_action_moves_settlement? returns true for namespaced Nomad tile" do
    game = Struct.new(:current_action).new({ "type" => "resettlement", "klass" => "ResettlementTile" })

    assert current_action_moves_settlement?(game)
  end

  test "current_action_moves_settlement? returns false for mandatory action" do
    game = Struct.new(:current_action).new({ "type" => "mandatory" })

    assert_not current_action_moves_settlement?(game)
  end

  test "current_action_moves_settlement? returns true for sword action" do
    game = Struct.new(:current_action).new({ "type" => "sword", "klass" => "SwordTile" })

    assert current_action_moves_settlement?(game)
  end

  test "sound_asset_paths does not raise when sound files are absent" do
    assert_nothing_raised { sound_asset_paths(%w[build move undo]) }
  end
end
