class BoardState
  # Each entry is [even_row_step, odd_row_step] for one of the 6 straight-line directions.
  STRAIGHT_LINES = [
    [ [ 0, -1 ], [ 0, -1 ] ],   # W
    [ [ 0,  1 ], [ 0,  1 ] ],   # E
    [ [ -1, -1 ], [ -1, 0 ] ],  # NW
    [ [ -1,  0 ], [ -1, 1 ] ],  # NE
    [ [ 1, -1 ],  [ 1, 0 ] ],   # SW
    [ [ 1,  0 ],  [ 1, 1 ] ]    # SE
  ].freeze

  # Terrain is static board config (from game.boards), not occupancy, so it is
  # never serialized. A terrain source (anything answering terrain_at(row, col)
  # — the Boards::Board in production, a stub in tests) is attached at
  # game.instantiate so BoardState can answer both occupancy and terrain.
  attr_writer :terrain_source

  MAIN = (0..19)
  MAIN_CELLS = MAIN.flat_map { |r| MAIN.map { |c| [ r, c ] } }.freeze
  # The Island decree's board lives below the main map; see Boards::Island.
  ISLAND_ROWS = (Boards::Island::ROW..Boards::Island::ROW + 6)
  ISLAND_COLS = (Boards::Island::COL..Boards::Island::COL + 8)

  def initialize
    @cells = {}
  end

  def initialize_copy(original)
    @cells = original.instance_variable_get(:@cells).transform_values(&:dup)
    @terrain_source = original.instance_variable_get(:@terrain_source)
  end

  # Every hex that can be played on: the main map plus the Island, when the game has one.
  def cells
    island = @terrain_source.respond_to?(:island_cells) ? @terrain_source.island_cells : []
    MAIN_CELLS + island
  end

  def occupied = @cells.keys

  # The main map and the Island are separate boards: from a hex, `from` is a row in the board
  # being walked, and a step that crosses to the other board is out of bounds.
  def in_bounds?(row, col, from: row)
    return false unless (row >= Boards::Island::ROW) == (from >= Boards::Island::ROW)
    row >= Boards::Island::ROW ? ISLAND_ROWS.cover?(row) && ISLAND_COLS.cover?(col) : MAIN.cover?(row) && MAIN.cover?(col)
  end

  def terrain_at(row, col)
    raise "no terrain source attached (call game.instantiate first)" unless @terrain_source
    @terrain_source.terrain_at(row, col)
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

  # Scouts (Scout Cabin) are their own cell kind: they occupy a hex and count as the owner's
  # pieces for adjacency, but are not settlements, so scoring and tile pickup never see them.
  def place_scout(row, col, player)
    @cells[[ row, col ]] = { "klass" => "Scout", "player" => player }
  end

  def scouts_for(player)
    @cells.filter_map { |(row, col), cell| [ row, col ] if cell["klass"] == "Scout" && cell["player"] == player }
  end

  def scout_owner(row, col)
    cell = @cells[[ row, col ]]
    cell["player"] if cell && cell["klass"] == "Scout"
  end

  def remove_scouts(player)
    scouts_for(player).each { |row, col| remove(row, col) }
  end

  # What "adjacent to your settlements" is measured from: settlements and scouts.
  def adjacency_sources_for(player)
    settlements_for(player) + scouts_for(player)
  end

  def restore_piece(meeple, row, col, player)
    case meeple
    when "warrior" then place_warrior(row, col, player)
    when "ship"    then place_ship(row, col, player)
    when "wagon"   then place_wagon(row, col, player)
    else                place_settlement(row, col, player)
    end
  end

  def warrior_blocked?(row, col)
    neighbors(row, col).any? { |nr, nc| warrior_at?(nr, nc) }
  end

  def available_for_building?(row, col)
    empty?(row, col) && !warrior_blocked?(row, col)
  end

  # The "adjacent if possible, else anywhere" build rule (ADR-0001): buildable
  # cells of `terrain` adjacent to one of player_order's pieces; or, when the
  # player has no such adjacency, every buildable cell of that terrain. Pass
  # `excluding` to drop a source cell (a settlement mid-relocation). Shared by
  # mandatory builds (MandatoryBuildPhase) and the location build tiles
  # (Tiles::Tile#valid_destinations) so the rule lives in exactly one place.
  def buildable_cells_for(player_order, terrain, excluding: nil)
    sources = adjacency_sources_for(player_order)
    sources = sources.reject { |cell| cell == excluding } if excluding
    adjacent = sources.flat_map do |row, col|
      neighbors_where(row, col) { |nr, nc| available_for_building?(nr, nc) && terrain_at(nr, nc) == terrain }
    end.uniq
    return adjacent unless adjacent.empty?

    available_cells_of([ terrain ])
  end

  # buildable_cells_for with a choice of terrains (a two-card hand, a Canoe): the rule is
  # applied to each terrain separately, so adjacency on one terrain never hides another.
  def buildable_cells_for_any(player_order, terrains)
    terrains.flat_map { |terrain| buildable_cells_for(player_order, terrain) }.uniq
  end

  # Every buildable cell (empty, not warrior-blocked) whose terrain is in
  # `terrains`, row-major. The "anywhere on this terrain" set used by the
  # Outpost power (ADR-0001's "all buildable terrain cells" primitive).
  def available_cells_of(terrains)
    cells.select { |row, col| available_for_building?(row, col) && terrains.include?(terrain_at(row, col)) }
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
      [ nr, nc ] if in_bounds?(nr, nc, from: row)
    end
  end

  # Each connected body of water on the main map, as a set of cells.
  def water_bodies
    seen = Set.new
    MAIN_CELLS.filter_map do |cell|
      next if seen.include?(cell) || terrain_at(*cell) != "W"
      water_body(*cell).tap { |body| seen.merge(body) }
    end
  end

  def water_body(row, col)
    body = Set[[ row, col ]]
    queue = [ [ row, col ] ]
    until queue.empty?
      neighbors_where(*queue.shift) { |nr, nc| terrain_at(nr, nc) == "W" }.each { |n| queue << n if body.add?(n) }
    end
    body
  end

  # The cell of `cells` nearest their centroid, on the hex grid's real (offset-row) geometry.
  def self.center_of(cells)
    point = ->(r, c) { [ c + 0.5 * (r % 2), r * Math.sqrt(3) / 2 ] }
    points = cells.map { |r, c| point.(r, c) }
    cx = points.sum(&:first) / points.size
    cy = points.sum(&:last) / points.size
    cells.min_by { |r, c| x, y = point.(r, c); (x - cx)**2 + (y - cy)**2 }
  end

  # Hex distance between two [row, col] cells (odd rows are shifted right).
  def self.distance(a, b)
    cube = ->((r, c)) { [ c - (r - (r & 1)) / 2, r ] }
    (ax, az), (bx, bz) = cube.(a), cube.(b)
    [ (ax - bx).abs, (az - bz).abs, ((ax + az) - (bx + bz)).abs ].max
  end

  def cave_hexes
    @terrain_source.respond_to?(:cave_hexes) ? Array(@terrain_source.cave_hexes) : []
  end

  # Every hex next to any Cave (Caves decree).
  def cave_shore
    cave_hexes.flat_map { |r, c| neighbors(r, c) }.uniq - cave_hexes
  end

  def ferry_hex
    @terrain_source.ferry_hex if @terrain_source.respond_to?(:ferry_hex)
  end

  # Every hex next to the ferry's body of water (Ferry decree); empty without a ferry.
  def ferry_shore
    return [] unless ferry_hex
    body = water_body(*ferry_hex)
    body.flat_map { |r, c| neighbors(r, c) }.uniq.reject { |cell| body.include?(cell) }
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
