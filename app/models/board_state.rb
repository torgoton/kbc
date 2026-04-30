class BoardState
  def initialize
    @cells = {}
  end

  def initialize_copy(original)
    @cells = original.instance_variable_get(:@cells).transform_values(&:dup)
  end

  def place_settlement(row, col, player)
    @cells[[ row, col ]] = { "klass" => "Settlement", "player" => player }
  end

  def place_city_hall_hex(row, col, player)
    @cells[[ row, col ]] = { "klass" => "Settlement", "player" => player, "city_hall" => true }
  end

  def city_hall_at?(row, col)
    cell = @cells[[ row, col ]]
    cell&.dig("city_hall") == true
  end

  def place_warrior(row, col, player)
    @cells[[ row, col ]] = { "klass" => "Settlement", "player" => player, "meeple" => "warrior" }
  end

  def meeple_at(row, col)
    cell = @cells[[ row, col ]]
    cell["meeple"] if cell && cell["klass"] == "Settlement"
  end

  def warriors_for(player)
    @cells.filter_map do |(row, col), cell|
      [ row, col ] if cell["klass"] == "Settlement" && cell["player"] == player && cell["meeple"] == "warrior"
    end
  end

  def place_ship(row, col, player)
    @cells[[ row, col ]] = { "klass" => "Settlement", "player" => player, "meeple" => "ship" }
  end

  def ships_for(player)
    @cells.filter_map do |(row, col), cell|
      [ row, col ] if cell["klass"] == "Settlement" && cell["player"] == player && cell["meeple"] == "ship"
    end
  end

  def ship_at?(row, col)
    cell = @cells[[ row, col ]]
    cell && cell["klass"] == "Settlement" && cell["meeple"] == "ship"
  end

  def place_wagon(row, col, player)
    @cells[[ row, col ]] = { "klass" => "Settlement", "player" => player, "meeple" => "wagon" }
  end

  def wagons_for(player)
    @cells.filter_map do |(row, col), cell|
      [ row, col ] if cell["klass"] == "Settlement" && cell["player"] == player && cell["meeple"] == "wagon"
    end
  end

  def wagon_at?(row, col)
    cell = @cells[[ row, col ]]
    cell && cell["klass"] == "Settlement" && cell["meeple"] == "wagon"
  end

  def warrior_blocked?(row, col)
    neighbors(row, col).any? { |nr, nc| warrior_at?(nr, nc) }
  end

  def available_for_building?(row, col)
    empty?(row, col) && !warrior_blocked?(row, col)
  end

  def move_settlement(from_row, from_col, to_row, to_col)
    cell = @cells.delete([ from_row, from_col ])
    @cells[[ to_row, to_col ]] = cell
  end

  def place_tile(row, col, klass, qty)
    @cells[[ row, col ]] = { "klass" => klass, "qty" => qty }
  end

  def remove(row, col)
    @cells.delete([ row, col ])
  end

  def place_wall(row, col)
    @cells[[ row, col ]] = { "klass" => "Wall" }
  end

  def empty?(row, col)
    !@cells.key?([ row, col ])
  end

  def player_at(row, col)
    cell = @cells[[ row, col ]]
    cell["player"] if cell && cell["klass"] == "Settlement"
  end

  def decrement_tile(row, col)
    raise ArgumentError, "tile qty already 0" if @cells[[ row, col ]]["qty"] <= 0
    @cells[[ row, col ]]["qty"] -= 1
  end

  def increment_tile(row, col)
    @cells[[ row, col ]]["qty"] += 1
  end

  ADJACENCIES = [
    [ [ 0, -1 ], [ 0, 1 ], [ -1, -1 ], [ -1, 0 ], [ 1, -1 ], [ 1, 0 ] ],
    [ [ 0, -1 ], [ 0, 1 ], [ -1,  0 ], [ -1, 1 ], [ 1,  0 ], [ 1, 1 ] ]
  ]

  # AR serialize coder protocol: dump returns a Ruby value (Array); load receives
  # the already-deserialized Ruby value from the JSON column (nil or Array).
  def self.dump(state)
    return [] unless state.is_a?(BoardState)
    state.instance_variable_get(:@cells).map do |(row, col), cell|
      { "r" => row, "c" => col }.merge(cell)
    end
  end

  def self.load(data)
    state = new
    Array(data).each do |entry|
      next unless entry.is_a?(Hash) && entry["r"] && entry["c"]
      row, col = entry["r"], entry["c"]
      state.instance_variable_get(:@cells)[[ row, col ]] = entry.except("r", "c")
    end
    state
  end

  def neighbors(row, col)
    ADJACENCIES[row % 2].filter_map do |dr, dc|
      nr, nc = row + dr, col + dc
      [ nr, nc ] if (0..19).cover?(nr) && (0..19).cover?(nc)
    end
  end

  def neighbors_where(row, col, &block)
    neighbors(row, col).select { |nr, nc| block.call(nr, nc) }
  end

  def locations_with_remaining_tiles
    @cells.filter_map { |(row, col), cell| [ row, col ] if cell["klass"] != "Settlement" && cell["qty"].to_i > 0 }
  end

  def warrior_at?(row, col)
    cell = @cells[[ row, col ]]
    cell && cell["klass"] == "Settlement" && cell["meeple"] == "warrior"
  end

  def settlements_for(player)
    @cells.filter_map { |(row, col), cell| [ row, col ] if cell["klass"] == "Settlement" && cell["player"] == player }
  end

  def tile_qty(row, col)
    cell = @cells[[ row, col ]]
    (cell && cell["klass"] != "Settlement") ? cell["qty"].to_i : 0
  end

  def tile_klass(row, col)
    cell = @cells[[ row, col ]]
    cell["klass"] if cell && cell["klass"] != "Settlement"
  end
end
