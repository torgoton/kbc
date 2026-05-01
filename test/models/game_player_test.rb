# == Schema Information
#
# Table name: game_players
#
#  id           :bigint           not null, primary key
#  bonus_scores :jsonb            not null
#  hand         :json
#  order        :integer
#  supply       :json
#  taken_from   :json
#  tiles        :json
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  game_id      :integer          not null
#  user_id      :integer          not null
#
# Indexes
#
#  index_game_players_on_game_id  (game_id)
#  index_game_players_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class GamePlayerTest < ActiveSupport::TestCase
  setup do
    @gp = game_players(:chris)  # supply: { "settlements" => 40 }, hand: ["T"]
  end

  # --- Hand ---

  test "hand is an array" do
    assert_instance_of Array, @gp.hand
  end

  test "hand stores and retrieves as array" do
    @gp.hand = [ "G", "F" ]
    @gp.save!
    @gp.reload
    assert_equal [ "G", "F" ], @gp.hand
  end

  # --- Supply ---

  test "settlements_remaining returns settlement count" do
    assert_equal 40, @gp.settlements_remaining
  end

  test "settlements_remaining? is true when supply > 0 and false when empty" do
    assert @gp.settlements_remaining?
    @gp.supply = { "settlements" => 0 }
    assert_not @gp.settlements_remaining?
  end

  test "decrement_supply! reduces settlements by 1 in place" do
    @gp.decrement_supply!
    assert_equal 39, @gp.settlements_remaining
  end

  test "increment_supply! increases settlements by 1 in place" do
    @gp.supply = { "settlements" => 39 }
    @gp.increment_supply!
    assert_equal 40, @gp.settlements_remaining
  end

  # --- Tiles ---

  test "held_tile_locations returns a set of from-keys for held tiles" do
    @gp.tiles = [
      { "klass" => "FarmTile", "from" => "[11, 17]", "used" => false },
      { "klass" => "OasisTile", "from" => "[12, 7]",  "used" => true }
    ]
    assert_equal Set.new([ "[11, 17]", "[12, 7]" ]), @gp.held_tile_locations
  end

  test "held_tile_locations returns empty set when tiles is nil" do
    @gp.tiles = nil
    assert_equal Set.new, @gp.held_tile_locations
  end

  test "mark_tile_used! marks the first unused tile of the given class used" do
    @gp.tiles = [
      { "klass" => "FarmTile", "from" => "[11, 17]", "used" => false },
      { "klass" => "FarmTile", "from" => "[15, 12]", "used" => false }
    ]
    @gp.mark_tile_used!("FarmTile")
    assert @gp.tiles[0]["used"]
    assert_not @gp.tiles[1]["used"]
  end

  test "mark_tile_used! does nothing when no unused tile of that class exists" do
    @gp.tiles = [ { "klass" => "FarmTile", "from" => "[11, 17]", "used" => true } ]
    @gp.mark_tile_used!("FarmTile")
    assert @gp.tiles[0]["used"]  # unchanged
  end

  test "reset_tiles! sets all tile used flags to false" do
    @gp.tiles = [
      { "klass" => "FarmTile",   "from" => "[11, 17]", "used" => true },
      { "klass" => "OasisTile",  "from" => "[12, 7]",  "used" => true }
    ]
    @gp.reset_tiles!
    assert @gp.tiles.all? { |t| t["used"] == false }
  end

  test "receive_tile! appends a new tile marked used" do
    @gp.tiles = []
    @gp.receive_tile!("FarmTile", from: "[11, 17]")
    assert_equal [ { "klass" => "FarmTile", "from" => "[11, 17]", "used" => true } ], @gp.tiles
  end

  test "receive_tile! works when tiles is nil" do
    @gp.tiles = nil
    @gp.receive_tile!("OasisTile", from: "[12, 7]")
    assert_equal 1, @gp.tiles.size
  end

  test "remove_tile_from! removes the tile with the matching from key" do
    @gp.tiles = [
      { "klass" => "FarmTile",  "from" => "[11, 17]", "used" => true },
      { "klass" => "OasisTile", "from" => "[12, 7]",  "used" => true }
    ]
    @gp.remove_tile_from!("[11, 17]")
    assert_equal 1, @gp.tiles.size
    assert_equal "[12, 7]", @gp.tiles.first["from"]
  end

  test "restore_tile! appends a tile with the given used state" do
    @gp.tiles = []
    @gp.restore_tile!("PaddockTile", from: "[6, 11]", used: false)
    assert_equal [ { "klass" => "PaddockTile", "from" => "[6, 11]", "used" => false } ], @gp.tiles
  end

  test "find_unused_tile returns the first unused tile hash of the given class" do
    @gp.tiles = [
      { "klass" => "FarmTile", "from" => "[11, 17]", "used" => true },
      { "klass" => "FarmTile", "from" => "[15, 12]", "used" => false }
    ]
    tile = @gp.find_unused_tile("FarmTile")
    assert_equal "[15, 12]", tile["from"]
  end

  test "find_unused_tile returns nil when no unused tile of that class exists" do
    @gp.tiles = [ { "klass" => "FarmTile", "from" => "[11, 17]", "used" => true } ]
    assert_nil @gp.find_unused_tile("FarmTile")
  end

  test "mark_tile_unused! marks the first used tile of the given class unused" do
    @gp.tiles = [
      { "klass" => "FarmTile", "from" => "[11, 17]", "used" => true },
      { "klass" => "FarmTile", "from" => "[15, 12]", "used" => true }
    ]
    @gp.mark_tile_unused!("FarmTile")
    assert_not @gp.tiles[0]["used"]
    assert @gp.tiles[1]["used"]
  end

  test "warriors_remaining returns 0 by default" do
    assert_equal 0, @gp.warriors_remaining
  end

  test "add_warriors! increases warrior count" do
    @gp.add_warriors!(2)
    assert_equal 2, @gp.warriors_remaining
    assert @gp.warriors_remaining?
  end

  test "decrement_warrior_supply! reduces count by 1" do
    @gp.add_warriors!(2)
    @gp.decrement_warrior_supply!
    assert_equal 1, @gp.warriors_remaining
  end

  test "increment_warrior_supply! increases count by 1" do
    @gp.add_warriors!(1)
    @gp.decrement_warrior_supply!
    @gp.increment_warrior_supply!
    assert_equal 1, @gp.warriors_remaining
  end

  test "warriors_remaining? is false when supply is 0" do
    assert_not @gp.warriors_remaining?
  end

  test "ships_remaining returns 0 by default" do
    assert_equal 0, @gp.ships_remaining
  end

  test "add_ships! increases ship count" do
    @gp.add_ships!(1)
    assert_equal 1, @gp.ships_remaining
    assert @gp.ships_remaining?
  end

  test "decrement_ship_supply! reduces count by 1" do
    @gp.add_ships!(1)
    @gp.decrement_ship_supply!
    assert_equal 0, @gp.ships_remaining
  end

  test "increment_ship_supply! increases count by 1" do
    @gp.add_ships!(1)
    @gp.decrement_ship_supply!
    @gp.increment_ship_supply!
    assert_equal 1, @gp.ships_remaining
  end

  test "ships_remaining? is false when supply is 0" do
    assert_not @gp.ships_remaining?
  end

  # --- City Hall supply ---

  test "city_halls_remaining returns 0 by default" do
    assert_equal 0, @gp.city_halls_remaining
  end

  test "add_city_halls! increases count" do
    @gp.add_city_halls!(1)
    assert_equal 1, @gp.city_halls_remaining
    assert @gp.city_halls_remaining?
  end

  test "decrement_city_hall_supply! reduces count by 1" do
    @gp.add_city_halls!(1)
    @gp.decrement_city_hall_supply!
    assert_equal 0, @gp.city_halls_remaining
  end

  test "increment_city_hall_supply! increases count by 1" do
    @gp.add_city_halls!(1)
    @gp.decrement_city_hall_supply!
    @gp.increment_city_hall_supply!
    assert_equal 1, @gp.city_halls_remaining
  end

  test "city_halls_remaining? is false when supply is 0" do
    assert_not @gp.city_halls_remaining?
  end

  test "supply_hash includes city_hall key" do
    @gp.add_city_halls!(1)
    assert_equal 1, @gp.supply_hash["city_hall"]
  end

  # --- Permanent tile methods ---

  test "mark_tile_permanently_used! sets used and permanent on the tile" do
    @gp.tiles = [ { "klass" => "CityHallTile", "from" => "[5, 5]", "used" => false } ]
    @gp.mark_tile_permanently_used!("CityHallTile")
    assert @gp.tiles[0]["used"]
    assert @gp.tiles[0]["permanent"]
  end

  test "mark_tile_unpermanent! removes permanent flag and sets used to false" do
    @gp.tiles = [ { "klass" => "CityHallTile", "from" => "[5, 5]", "used" => true, "permanent" => true } ]
    @gp.mark_tile_unpermanent!("CityHallTile")
    assert_not @gp.tiles[0]["used"]
    assert_nil @gp.tiles[0]["permanent"]
  end

  test "reset_tiles! skips permanent tiles" do
    @gp.tiles = [
      { "klass" => "FarmTile",     "from" => "[11, 17]", "used" => true },
      { "klass" => "CityHallTile", "from" => "[5, 5]",   "used" => true, "permanent" => true }
    ]
    @gp.reset_tiles!
    assert_not @gp.tiles[0]["used"]
    assert @gp.tiles[1]["used"]
    assert @gp.tiles[1]["permanent"]
  end
end
