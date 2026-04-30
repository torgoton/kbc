class TurnEngine
  def initialize(game)
    @game = game
  end

  def available_list(active_player, terrain)
    return nil unless @game.playing?
    available = Array.new(20) { Array.new(20, false) }

    any = false
    20.times do |row|
      20.times do |col|
        if @game.board.content_at(row, col).try(:player) == active_player
          @game.board_contents.neighbors(row, col).each do |nr, nc|
            if @game.board.content_at(nr, nc) == nil && @game.board.terrain_at(nr, nc) == terrain &&
               !@game.board_contents.warrior_blocked?(nr, nc)
              any = available[nr][nc] = true
            end
          end
        end
      end
    end
    return available if any

    20.times do |row|
      20.times do |col|
        if @game.board.terrain_at(row, col) == terrain && !@game.board_contents.warrior_blocked?(row, col)
          available[row][col] = true unless @game.board.content_at(row, col)
        end
      end
    end
    available
  end

  def available?(order, terrain, row, col)
    @list ||= available_list(order, terrain)
    @list.any? ? @list[row][col] : true
  end

  def build_settlement(row, col)
    Rails.logger.debug("Attempt to build at #{row}, #{col}")
    @game.instantiate
    game_player = @game.current_player
    Rails.logger.debug(" I have #{game_player.settlements_remaining} settlements remaining")
    return "No settlements left" unless game_player.settlements_remaining?
    card_terrain = game_player.hand

    if @game.current_action["outpost_active"]
      # Skip adjacency: just check it's empty and correct terrain
      return "Not available" unless @game.board_contents.available_for_building?(row, col) && @game.board.terrain_at(row, col) == card_terrain
      build_on_terrain(card_terrain, row, col, game_player)
      @game.mandatory_count -= 1
      @game.current_action_will_change!
      @game.current_action.delete("outpost_active")
      @game.current_action_will_change!
      builds = (@game.current_action["builds"] || []) + [ [ row, col ] ]
      @game.current_action["builds"] = builds
      check_families_goal(game_player) if builds.size == 3
    else
      return "Not available" unless available?(game_player.order, card_terrain, row, col)
      build_on_terrain(card_terrain, row, col, game_player)
      @game.mandatory_count -= 1
      @game.current_action_will_change!
      builds = (@game.current_action["builds"] || []) + [ [ row, col ] ]
      @game.current_action["builds"] = builds
      check_families_goal(game_player) if builds.size == 3
    end

    Rails.logger.debug("Building settlement at #{row}, #{col} for player #{game_player.order}")
    game_player.save
    @game.save
  end

  def activate_outpost
    @game.instantiate
    game_player = @game.current_player
    return "No outpost tile" unless game_player.find_unused_tile("OutpostTile")
    return "Not in build action" unless build_action?
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: game_player,
      deliberate: true,
      action: "activate_outpost",
      reversible: true,
      message: "#{game_player.player.handle} activated the Outpost tile"
    )
    game_player.mark_tile_used!("OutpostTile")
    @game.current_action_will_change!
    @game.current_action["outpost_active"] = true
    game_player.save
    @game.save
  end

  def remove_settlement(row, col)
    @game.instantiate
    game_player = @game.current_player

    return "Not a valid target" if @game.board_contents.city_hall_at?(row, col)
    pending_orders = @game.current_action["pending_orders"] || []
    owner_order = @game.board_contents.player_at(row, col)
    return "Not a valid target" unless owner_order && pending_orders.include?(owner_order)

    owner = @game.game_players.find { |gp| gp.order == owner_order }

    action_before = @game.current_action.deep_dup
    remaining_orders = pending_orders - [ owner_order ]
    tile_used = remaining_orders.empty?

    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: game_player,
      deliberate: true,
      action: "remove_settlement",
      from: "[#{row}, #{col}]",
      to: "player_#{owner_order}_supply",
      reversible: true,
      payload: { "owner_order" => owner_order, "action_before" => action_before, "tile_used" => tile_used },
      message: "#{game_player.player.handle} removed #{owner.player.handle}'s settlement"
    )

    @game.board_contents_will_change!
    @game.board_contents.remove(row, col)
    owner.increment_supply!
    apply_tile_forfeit(owner)

    if tile_used
      klass_name = current_action_tile_klass
      game_player.mark_tile_used!(klass_name.demodulize)
      @game.current_action = { "type" => "mandatory" }
    else
      @game.current_action_will_change!
      @game.current_action["pending_orders"] = remaining_orders
    end

    owner.save
    game_player.save
    @game.save
  end

  def execute_meeple_action(row, col)
    @game.instantiate
    game_player = @game.current_player
    tile_klass = current_action_tile_klass
    tile = game_player.find_unused_tile(tile_klass)
    return "Not available" unless tile

    tile_obj = Tiles::Tile.from_hash(tile)

    if @game.current_action["from"]
      # complete a ship or wagon move to destination
      from_coord = Coordinate.from_key(@game.current_action["from"])
      destinations = tile_obj.valid_destinations(
        from_row: from_coord.row, from_col: from_coord.col,
        board_contents: @game.board_contents, board: @game.board,
        player_order: game_player.order
      )
      return "Not available" unless destinations.include?([ row, col ])
      case tile_obj.meeple_kind
      when "ship"  then move_ship(row, col, game_player, tile_klass:)
      when "wagon" then move_wagon(row, col, game_player, tile_klass:)
      end
    elsif @game.board_contents.wagon_at?(row, col) &&
          @game.board_contents.player_at(row, col) == game_player.order
      return "Not available"  # handled by popup: remove_meeple_action or select_meeple_for_move
    elsif @game.board_contents.ship_at?(row, col) &&
          @game.board_contents.player_at(row, col) == game_player.order
      return "Not available"  # handled by popup: remove_meeple_action or select_meeple_for_move
    elsif @game.board_contents.warrior_at?(row, col) &&
          @game.board_contents.player_at(row, col) == game_player.order
      return "Not available"  # handled by popup: remove_meeple_action
    else
      destinations = tile_obj.valid_destinations(
        board_contents: @game.board_contents, board: @game.board,
        player_order: game_player.order, supply: game_player.supply_hash
      )
      return "Not available" unless destinations.include?([ row, col ])
      case tile_obj.meeple_kind
      when "ship"    then place_ship(row, col, game_player, tile_klass:)
      when "wagon"   then place_wagon(row, col, game_player, tile_klass:)
      when "warrior" then place_warrior(row, col, game_player, tile_klass:)
      end
    end

    game_player.mark_tile_used!(tile_klass)
    @game.current_action = { "type" => "mandatory" }
    game_player.save
    @game.save
  end

  def remove_meeple_action(row, col)
    @game.instantiate
    game_player = @game.current_player
    tile_klass = current_action_tile_klass
    tile = game_player.find_unused_tile(tile_klass)
    return "Not available" unless tile

    if @game.board_contents.warrior_at?(row, col) &&
       @game.board_contents.player_at(row, col) == game_player.order
      remove_warrior(row, col, game_player, tile_klass:)
    elsif @game.board_contents.ship_at?(row, col) &&
          @game.board_contents.player_at(row, col) == game_player.order
      remove_ship(row, col, game_player, tile_klass:)
    elsif @game.board_contents.wagon_at?(row, col) &&
          @game.board_contents.player_at(row, col) == game_player.order
      remove_wagon(row, col, game_player, tile_klass:)
    else
      return "Not available"
    end

    game_player.mark_tile_used!(tile_klass)
    @game.current_action = { "type" => "mandatory" }
    game_player.save
    @game.save
  end

  def select_meeple_for_move(row, col)
    @game.instantiate
    game_player = @game.current_player
    tile_klass = current_action_tile_klass
    tile = game_player.find_unused_tile(tile_klass)
    return "Not available" unless tile

    tile_obj = Tiles::Tile.from_hash(tile)
    moveable = case tile_obj.meeple_kind
    when "ship"  then @game.board_contents.ship_at?(row, col)
    when "wagon" then @game.board_contents.wagon_at?(row, col)
    else false
    end
    return "Not available" unless moveable
    return "Not available" unless @game.board_contents.player_at(row, col) == game_player.order

    destinations = tile_obj.valid_destinations(
      from_row: row, from_col: col,
      board_contents: @game.board_contents, board: @game.board,
      player_order: game_player.order
    )
    return "Not available" unless destinations.any?

    action_word = tile_obj.meeple_kind
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: game_player,
      deliberate: true,
      action: "select_#{action_word}",
      from: "[#{row}, #{col}]",
      reversible: true,
      message: "#{game_player.player.handle} selected their #{action_word} at [#{row}, #{col}]"
    )
    @game.current_action = @game.current_action.merge("from" => "[#{row}, #{col}]")
    @game.save
  end

  def place_city_hall(row, col)
    @game.instantiate
    game_player = @game.current_player
    tile = game_player.find_unused_tile("CityHallTile")
    return "No City Hall tile" unless tile
    tile_obj = Tiles::CityHallTile.new(0)
    valid = tile_obj.valid_destinations(
      board_contents: @game.board_contents, board: @game.board,
      player_order: game_player.order, supply: game_player.supply_hash
    )
    return "Not available" unless valid.include?([ row, col ])

    action_before = @game.current_action.deep_dup
    cluster = tile_obj.cluster_hexes(row, col, @game.board_contents)

    @game.move_count += 1
    @game.moves.create!(
      order: @game.move_count,
      game_player: game_player,
      deliberate: true,
      action: "place_city_hall",
      to: "[#{row}, #{col}]",
      reversible: true,
      payload: { "action_before" => action_before },
      message: "#{game_player.player.handle} placed their City Hall at [#{row}, #{col}]"
    )

    @game.board_contents_will_change!
    cluster.each { |r, c| @game.board_contents.place_city_hall_hex(r, c, game_player.order) }
    game_player.decrement_city_hall_supply!
    game_player.mark_tile_permanently_used!("CityHallTile")
    @game.current_action = { "type" => "mandatory" }
    game_player.save
    @game.save
  end

  def activate_tile_build(row, col)
    @game.instantiate
    game_player = @game.current_player
    return "No settlements left" unless game_player.settlements_remaining?
    tile_klass = current_action_tile_klass
    tile = game_player.find_unused_tile(tile_klass)
    return "Not available" unless tile
    tile_obj = Tiles::Tile.from_hash(tile)
    if @game.current_action["outpost_active"]
      return "Not available" unless @game.board_contents.empty?(row, col)
      @game.current_action_will_change!
      @game.current_action.delete("outpost_active")
    else
      destinations = tile_obj.valid_destinations(
        board_contents: @game.board_contents, board: @game.board, player_order: game_player.order, hand: game_player.hand
      )
      return "Not available" unless destinations.include?([ row, col ])
    end
    remaining_before = @game.current_action["remaining"]
    build_on_terrain(@game.board.terrain_at(row, col), row, col, game_player, tile_klass: tile_klass, remaining_before: remaining_before)
    if tile_obj.is_a?(Tiles::Nomad::DonationTile)
      remaining = @game.current_action["remaining"].to_i - 1
      if remaining > 0
        @game.current_action = @game.current_action.merge("remaining" => remaining)
      else
        game_player.mark_tile_used!(tile_klass)
        @game.current_action = { "type" => "mandatory" }
      end
    else
      game_player.mark_tile_used!(tile_klass)
      @game.current_action = { "type" => "mandatory" }
    end
    game_player.save
    @game.save
  end

  def select_action(type)
    klass_name = tile_klass_name_for_type(type)
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: @game.current_player,
      deliberate: true,
      action: "select_action",
      to: type,
      reversible: true,
      payload: { "klass" => klass_name },
      message: "#{@game.current_player.player.handle} selected the #{type} action"
    )
    action = { "type" => type, "klass" => klass_name }
    tile_klass = Tiles::Tile.for_klass(klass_name)
    action["remaining"] = 3 if tile_klass&.new(0)&.is_a?(Tiles::Nomad::DonationTile)
    if tile_klass&.new(0)&.is_a?(Tiles::QuarryTile)
      action["walls_placed"] = 0
    end
    if tile_klass&.new(0)&.is_a?(Tiles::Nomad::ResettlementTile)
      action["budget"] = 4
      action["vacated"] = []
      action["moves"] = 0
    end
    if tile_klass&.new(0)&.is_a?(Tiles::Nomad::SwordTile)
      opponents = @game.game_players
        .reject { |gp| gp == @game.current_player }
        .select { |gp| @game.board_contents.settlements_for(gp.order).any? }
        .map(&:order)
        .sort
      return "No opponents with settlements" if opponents.empty?
      action["pending_orders"] = opponents
    end
    @game.current_action = action
    @game.save
  end

  def select_settlement(row, col)
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: @game.current_player,
      deliberate: true,
      action: "select_settlement",
      from: "[#{row}, #{col}]",
      reversible: true,
      message: "#{@game.current_player.player.handle} selected a settlement at [#{row}, #{col}]"
    )
    @game.current_action = @game.current_action.merge("from" => "[#{row}, #{col}]")
    @game.save
  end

  def move_settlement(row, col)
    @game.instantiate
    from = @game.current_action["from"]
    from_coord = Coordinate.from_key(from)
    tile_klass_name = current_action_tile_klass
    tile_obj = Tiles::Tile.for_klass(tile_klass_name)&.new(0)
    action_before = @game.current_action.slice("type", "klass", "budget", "vacated", "moves", "from")
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: @game.current_player,
      deliberate: true,
      action: "move_settlement",
      from: from,
      to: Coordinate.new(row, col).to_key,
      reversible: true,
      payload: { "tile_klass" => tile_klass_name, "action_before" => action_before },
      message: "#{@game.current_player.player.handle} moved a settlement to [#{row}, #{col}]"
    )
    if tile_obj&.is_a?(Tiles::Nomad::ResettlementTile)
      step_cost = tile_obj.move_cost(
        from_row: from_coord.row, from_col: from_coord.col,
        to_row: row, to_col: col,
        board_contents: @game.board_contents, board: @game.board,
        player_order: @game.current_player.order,
        budget: @game.current_action["budget"].to_i,
        vacated: @game.current_action["vacated"] || []
      ) || 1
    end
    @game.board_contents_will_change!
    @game.board_contents.move_settlement(*from_coord, row, col)

    if tile_obj&.is_a?(Tiles::Nomad::ResettlementTile)
      budget = @game.current_action["budget"].to_i - step_cost
      vacated = (@game.current_action["vacated"] || []) + [ from ]
      moves = @game.current_action["moves"].to_i + 1
      # Rule: Resettlement picks up tiles at each step; forfeits location tiles no longer adjacent
      # (Nomad tiles are exempt from location-based forfeit per the nomad_tile? guard in apply_tile_forfeit)
      apply_tile_forfeit(@game.current_player)
      apply_tile_pickup(@game.current_player, row, col)
      if budget <= 0
        @game.current_player.mark_tile_used!(tile_klass_name.demodulize)
        @game.current_action = { "type" => "mandatory" }
      else
        @game.current_action = @game.current_action.except("from").merge(
          "budget" => budget, "vacated" => vacated, "moves" => moves
        )
      end
    else
      @game.current_action = { "type" => "mandatory" }
      @game.current_player.mark_tile_used!(tile_klass_name)
      apply_tile_forfeit(@game.current_player)
      apply_tile_pickup(@game.current_player, row, col)
    end

    @game.current_player.save
    @game.save
  end

  def end_tile_action
    @game.instantiate
    game_player = @game.current_player
    tile_klass_name = current_action_tile_klass
    moves_made = @game.current_action["moves"].to_i
    walls_placed = @game.current_action["walls_placed"].to_i
    return "Not allowed" unless moves_made >= 1 || walls_placed >= 1

    game_player.mark_tile_used!(tile_klass_name.demodulize)
    @game.current_action = { "type" => "mandatory" }
    game_player.save
    @game.save
  end

  def place_wall(row, col)
    @game.instantiate
    game_player = @game.current_player

    tile_obj = Tiles::QuarryTile.new(0)
    destinations = tile_obj.valid_destinations(
      board_contents: @game.board_contents, board: @game.board,
      player_order: game_player.order, hand: game_player.hand
    )
    return "Not available" unless destinations.include?([ row, col ])
    return "No stone walls left" if @game.stone_walls <= 0

    walls_placed = @game.current_action["walls_placed"].to_i + 1

    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: game_player,
      deliberate: true,
      action: "place_wall",
      to: "[#{row}, #{col}]",
      reversible: true,
      message: "#{game_player.player.handle} placed a stone wall at [#{row}, #{col}]"
    )

    @game.board_contents_will_change!
    @game.board_contents.place_wall(row, col)
    @game.stone_walls -= 1

    remaining = tile_obj.valid_destinations(
      board_contents: @game.board_contents, board: @game.board,
      player_order: game_player.order, hand: game_player.hand
    )
    if walls_placed >= 2 || remaining.empty?
      game_player.mark_tile_used!("QuarryTile")
      @game.current_action = { "type" => "mandatory" }
    else
      @game.current_action_will_change!
      @game.current_action["walls_placed"] = walls_placed
    end

    game_player.save
    @game.save
  end

  def tile_activatable?(tile)
    return false if tile["used"]
    return false unless Tiles::Tile.for_klass(tile["klass"])
    return false unless @game.current_action["type"] == "mandatory" &&
      (@game.mandatory_count == Game::MANDATORY_COUNT || @game.mandatory_count <= 0 || !@game.current_player.settlements_remaining?)
    @game.instantiate
    tile_obj = Tiles::Tile.from_hash(tile)
    return false if tile_obj.places_wall? && @game.stone_walls <= 0
    return false if tile_obj.builds_settlement? && !@game.current_player.settlements_remaining?
    ctx = { player_order: @game.current_player.order, board_contents: @game.board_contents, board: @game.board, hand: @game.current_player.hand, supply: @game.current_player.supply_hash }
    tile_obj.activatable?(**ctx)
  end

  def turn_endable?
    @game.playing? &&
      @game.current_action["type"] == "mandatory" &&
      (@game.mandatory_count <= 0 || !@game.current_player.settlements_remaining?)
  end

  def outpost_activatable?(tile)
    return false if tile["used"]
    return false unless build_action?
    return false if @game.current_action["outpost_active"]
    @game.current_player.settlements_remaining?
  end

  def tile_action_endable?
    @game.playing? && (
      (@game.current_action["type"] == "resettlement" && @game.current_action["moves"].to_i >= 1) ||
      (@game.current_action["type"] == "quarry" && @game.current_action["walls_placed"].to_i >= 1)
    )
  end

  def tile_used?(tile)
    tile["used"] || (tile["klass"] == "MandatoryTile" && turn_endable?)
  end

  def undo_allowed?
    last_move = @game.moves.where(deliberate: true).order(order: :desc).first
    return false unless last_move
    last_move.reversible
  end

  def turn_state
    action_type = @game.current_action["type"]
    tile_klass = Tiles::Tile.for_klass(current_action_tile_klass) if action_type != "mandatory"
    if tile_klass
      msg = tile_klass.new(0).action_message(
        player_handle: @game.current_player.player.handle,
        terrain_names: Boards::Board::TERRAIN_NAMES,
        hand: @game.current_player.hand
      )
      remaining = @game.current_action["remaining"]
      remaining ? "#{msg} (#{remaining} remaining)" : msg
    else
      has_activatable = (@game.current_player.tiles || []).any? { |t| tile_activatable?(t) }
      if @game.mandatory_count > 0 && @game.current_player.settlements_remaining?
        "#{@game.current_player.player.handle} must build " \
        "#{ActionController::Base.helpers.pluralize(@game.mandatory_count, "settlement")} on " \
        "#{Boards::Board::TERRAIN_NAMES[@game.current_player.hand]}" \
        "#{" or select a tile" if has_activatable}"
      else
        "#{@game.current_player.player.handle} must end their turn" \
        "#{" or select a tile" if has_activatable}"
      end
    end
  end

  def end_turn
    Rails.logger.debug("END TURN REQUESTED on GAME #{@game.id}")
    Rails.logger.debug(" - current player #{@game.current_player.inspect}")
    @game.instantiate
    game_player = @game.current_player
    card_discarded = game_player.hand
    @game.discard.push(game_player.hand)
    game_player.hand = next_card
    card_drawn = game_player.hand
    reshuffled = @game.discard.empty?
    @game.mandatory_count = Game::MANDATORY_COUNT
    @game.current_action = { "type" => "mandatory" }
    next_order = (@game.current_player.order + 1) % @game.game_players.count
    Rails.logger.debug(" - next in order #{next_order}")
    @game.current_player = @game.game_players.find { |p| p.order == next_order }
    Rails.logger.debug(" - next player #{@game.current_player.inspect}")
    @game.current_player.reset_tiles!
    # Forfeit expired nomad tiles
    game_player.tiles = (game_player.tiles || []).reject do |tile|
      tile["expires_on_turn"] && tile["expires_on_turn"] == @game.turn_number
    end
    # Increment turn number
    @game.turn_number += 1
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: game_player,
      deliberate: true,
      action: "end_turn",
      reversible: false,
      payload: { "card_discarded" => card_discarded, "card_drawn" => card_drawn,
                 "reshuffled" => reshuffled, "deck_after" => @game.deck.dup },
      message: "#{game_player.player.handle} ended their turn"
    )
    ActiveRecord::Base.transaction do
      game_player.save
      @game.current_player.save
      @game.save
    end
    max_order = @game.game_players.count - 1
    if @game.ending? && game_player.order == max_order
      @game.move_count += 1
      @game.moves.create(
        order: @game.move_count,
        game_player: game_player,
        deliberate: false,
        action: "end_game",
        reversible: false,
        message: "Game over!"
      )
      @game.save
      @game.complete!
    end
  end

  def buildable_cells
    return [] unless @game.playing?
    @buildable_cells ||= begin
      @game.instantiate
      player = @game.current_player
      action = @game.current_action["type"]

      if action == "mandatory"
        if player.settlements_remaining? && @game.mandatory_count > 0
          if @game.current_action["outpost_active"]
            terrain = player.hand
            (0..19).flat_map do |r|
              (0..19).filter_map { |c| [ r, c ] if @game.board_contents.empty?(r, c) && @game.board.terrain_at(r, c) == terrain }
            end
          else
            list = available_list(player.order, player.hand)
            (0..19).flat_map { |r| (0..19).filter_map { |c| [ r, c ] if list[r][c] } }
          end
        else
          []
        end
      elsif action == "sword"
        pending_orders = @game.current_action["pending_orders"] || []
        pending_orders.flat_map { |order| @game.board_contents.settlements_for(order) }
      else
        klass = current_action_tile_klass
        tile = player.find_unused_tile(klass)
        if tile
          tile_obj = Tiles::Tile.from_hash(tile)
          if tile_obj.places_meeple?
            if @game.current_action["from"]
              from = Coordinate.from_key(@game.current_action["from"])
              tile_obj.valid_destinations(
                from_row: from.row, from_col: from.col,
                board_contents: @game.board_contents, board: @game.board,
                player_order: player.order
              )
            else
              tile_obj.valid_destinations(
                board_contents: @game.board_contents, board: @game.board,
                player_order: player.order,
                supply: player.supply_hash
              )
            end
          elsif tile_obj.places_wall?
            tile_obj.valid_destinations(
              board_contents: @game.board_contents, board: @game.board,
              player_order: player.order, hand: player.hand
            )
          elsif tile_obj.moves_settlement?
            if @game.current_action["from"]
              from = Coordinate.from_key(@game.current_action["from"])
              extra_kwargs = {}
              if tile_obj.is_a?(Tiles::Nomad::ResettlementTile)
                extra_kwargs = {
                  budget: @game.current_action["budget"].to_i,
                  vacated: @game.current_action["vacated"] || []
                }
              end
              tile_obj.valid_destinations(
                from_row: from.row, from_col: from.col,
                board_contents: @game.board_contents, board: @game.board, player_order: player.order, hand: player.hand,
                **extra_kwargs
              )
            else
              extra_kwargs = {}
              if tile_obj.is_a?(Tiles::Nomad::ResettlementTile)
                extra_kwargs = {
                  budget: @game.current_action["budget"].to_i,
                  vacated: @game.current_action["vacated"] || []
                }
              end
              tile_obj.selectable_settlements(
                player_order: player.order, board_contents: @game.board_contents, board: @game.board, hand: player.hand,
                **extra_kwargs
              )
            end
          elsif tile_obj.places_city_hall?
            tile_obj.valid_destinations(
              board_contents: @game.board_contents, board: @game.board, player_order: player.order, supply: player.supply_hash
            )
          else
            tile_obj.valid_destinations(
              board_contents: @game.board_contents, board: @game.board, player_order: player.order, hand: player.hand
            )
          end
        else
          []
        end
      end
    end
  end

  def city_hall_clusters
    return {} unless @game.current_action["type"] == "cityhall"
    @game.instantiate
    player = @game.current_player
    tile_obj = Tiles::CityHallTile.new(0)
    centers = tile_obj.valid_destinations(
      board_contents: @game.board_contents, board: @game.board,
      player_order: player.order, supply: player.supply_hash
    )
    centers.to_h do |r, c|
      cluster = tile_obj.cluster_hexes(r, c, @game.board_contents)
      [ "#{r},#{c}", cluster ]
    end
  end

  def undo_last_move
    last_deliberate = @game.moves.where(deliberate: true).order(order: :desc).first
    return unless last_deliberate
    Rails.logger.debug("UNDOING back to deliberate move #{last_deliberate.inspect}")
    @game.instantiate
    backend = MoveApplicator::LiveState.new(@game)
    @game.moves.where("id >= ?", last_deliberate.id).order(id: :desc).each do |move|
      Rails.logger.debug("  undoing #{move.action} (order #{move.order})")
      @game.move_count -= 1
      MoveApplicator.dispatch(backend, move)
      move.destroy
    end
    @game.save
  end

  private

  def build_action?
    type = @game.current_action["type"]
    return true if type == "mandatory"
    klass = Tiles::Tile.for_klass(current_action_tile_klass)
    klass&.new(0)&.builds_settlement? || false
  end

  # Returns the tile klass name (without "Tiles::" prefix) for the current action.
  # Uses "klass" from current_action if present (stored by select_action),
  # otherwise falls back to the capitalize convention for existing tiles.
  def current_action_tile_klass
    @game.current_action["klass"] || "#{@game.current_action["type"].capitalize}Tile"
  end

  # Derives the tile klass name from the action type string.
  # The type is generated by the view as tile["klass"].delete_suffix("Tile").downcase,
  # so we reverse by finding the matching tile in the player's tile list.
  def tile_klass_name_for_type(type)
    tile = @game.current_player.tiles&.find { |t| t["klass"].delete_suffix("Tile").downcase == type }
    tile&.dig("klass") || "#{type.capitalize}Tile"
  end

  def build_on_terrain(terrain, row, col, game_player, tile_klass: nil, remaining_before: nil)
    payload = { "card" => terrain }
    payload["tile_klass"] = tile_klass if tile_klass
    payload["remaining_before"] = remaining_before if remaining_before
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: game_player,
      deliberate: true,
      action: "build",
      from: "supply",
      to: "[#{row}, #{col}]",
      reversible: true,
      payload: payload,
      message: "#{game_player.player.handle} built a settlement on #{Boards::Board::TERRAIN_NAMES[terrain]}"
    )
    game_player.decrement_supply!
    @game.ending = true if game_player.settlements_remaining == 0
    @game.board_contents_will_change!
    @game.board_contents.place_settlement(row, col, game_player.order)
    check_ambassadors_goal(game_player, row, col)
    check_shepherds_goal(game_player, row, col, terrain)
    apply_tile_pickup(game_player, row, col)
  end

  def apply_tile_forfeit(game_player)
    return if (game_player.tiles || []).empty?
    game_player.tiles = game_player.tiles.reject do |tile|
      # Rule: Nomad tiles expire by turn, never by location
      next false if Tiles::Tile.for_klass(tile["klass"])&.new(0)&.nomad_tile?
      loc = tile["from"]
      next false unless loc
      loc_coord = Coordinate.from_key(loc)
      should_forfeit = @game.board_contents.settlements_for(game_player.order).none? do |s_row, s_col|
        @game.board_contents.neighbors(s_row, s_col).any? { |nr, nc| Coordinate.new(nr, nc).to_key == loc }
      end
      if should_forfeit && @game.board_contents.tile_klass(*loc_coord)
        klass = @game.board_contents.tile_klass(*loc_coord)
        @game.move_count += 1
        @game.moves.create(
          order: @game.move_count,
          game_player: game_player,
          deliberate: false,
          action: "forfeit_tile",
          reversible: true,
          from: loc,
          to: tile["used"].to_s,
          payload: { "klass" => klass },
          message: (
            tile_name = klass.delete_suffix("Tile").downcase
            "#{game_player.player.handle} forfeited #{/\A[aeiou]/.match?(tile_name) ? "an" : "a"} #{tile_name} tile"
          )
        )
      end
      should_forfeit
    end
  end

  def find_tile_pickup(game_player, row, col)
    held_locations = game_player.held_tile_locations
    taken_from = game_player.taken_from || []
    @game.board_contents.neighbors(row, col).each do |adj_r, adj_c|
      klass = @game.board_contents.tile_klass(adj_r, adj_c)
      next unless klass && @game.board_contents.tile_qty(adj_r, adj_c) > 0
      tile_key = Coordinate.new(adj_r, adj_c).to_key
      next if held_locations.include?(tile_key)
      next if taken_from.include?(tile_key)
      return { key: tile_key, klass: klass }
    end
    nil
  end

  def apply_tile_pickup(game_player, row, col)
    tile = find_tile_pickup(game_player, row, col)
    return unless tile

    qty_before = @game.board_contents.tile_qty(*Coordinate.from_key(tile[:key]))
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: game_player,
      deliberate: false,
      action: "pick_up_tile",
      from: tile[:key],
      to: "player_#{game_player.order}",
      reversible: true,
      payload: { "klass" => tile[:klass], "qty_before" => qty_before },
      message: "#{game_player.player.handle} picked up #{/\A[AEIOU]/.match?(tile[:klass]) ? "an" : "a"} #{tile[:klass].delete_suffix("Tile")} tile"
    )
    @game.board_contents_will_change!
    @game.board_contents.decrement_tile(*Coordinate.from_key(tile[:key]))
    game_player.receive_tile!(tile[:klass], from: tile[:key])
    game_player.taken_from = (game_player.taken_from || []) + [ tile[:key] ]
    tile_obj = Tiles::Tile.for_klass(tile[:klass])&.new(0)
    supply_before = game_player.supply_hash.dup
    tile_obj&.on_pickup(game_player:)
    game_player.supply_hash.each do |kind, qty_after|
      granted = qty_after - supply_before[kind].to_i
      next unless granted > 0
      @game.move_count += 1
      @game.moves.create(
        order: @game.move_count,
        game_player: game_player,
        deliberate: false,
        action: "grant_meeple",
        reversible: true,
        payload: { "kind" => kind, "qty" => granted },
        message: "#{game_player.player.handle} acquires #{ActionController::Base.helpers.pluralize(granted, kind)}"
      )
    end
    if tile_obj&.nomad_tile?
      if tile_obj.is_a?(Tiles::Nomad::TreasureTile)
        # Score 3 points immediately and remove the tile
        game_player.tiles = (game_player.tiles || []).reject { |t| t["klass"] == tile[:klass] && t["from"] == tile[:key] }
        score_goal(game_player, "treasure", 3, "#{game_player.player.handle} scored 3 points from a Treasure tile")
      else
        # Set expiry on the tile
        expires = @game.turn_number + @game.game_players.count
        game_player.tiles = (game_player.tiles || []).map do |t|
          if t["klass"] == tile[:klass] && t["from"] == tile[:key]
            t.merge("expires_on_turn" => expires)
          else
            t
          end
        end
      end
    end
  end

  def check_ambassadors_goal(game_player, row, col)
    return unless Array(@game.goals).include?("ambassadors")
    adjacent_opponent = @game.board_contents.neighbors(row, col).any? do |nr, nc|
      p = @game.board_contents.player_at(nr, nc)
      p && p != game_player.order
    end
    return unless adjacent_opponent
    score_goal(game_player, "ambassadors", 1,
      "#{game_player.player.handle} scored 1 point (Ambassadors)")
  end

  def check_shepherds_goal(game_player, row, col, terrain)
    return unless Array(@game.goals).include?("shepherds")
    no_adjacent_empty = @game.board_contents.neighbors(row, col).none? do |nr, nc|
      @game.board_contents.empty?(nr, nc) && @game.board.terrain_at(nr, nc) == terrain
    end
    return unless no_adjacent_empty
    score_goal(game_player, "shepherds", 2,
      "#{game_player.player.handle} scored 2 points (Shepherds)")
  end

  def check_families_goal(game_player)
    return unless Array(@game.goals).include?("families")
    builds = @game.current_action["builds"] || []
    return unless builds.size == 3
    return unless straight_line?(builds)
    score_goal(game_player, "families", 2,
      "#{game_player.player.handle} scored 2 points (Families)")
  end

  def straight_line?(positions)
    a, b, c = positions
    [ [ a, b, c ], [ a, c, b ], [ b, a, c ] ].any? do |p1, p2, p3|
      in_same_direction?(p1, p2, p3)
    end
  end

  def in_same_direction?(p1, p2, p3)
    Tiles::PaddockTile::STRAIGHT_LINES.any? do |steps|
      dr1, dc1 = steps[p1[0] % 2]
      mid = [ p1[0] + dr1, p1[1] + dc1 ]
      next false unless mid == p2
      dr2, dc2 = steps[p2[0] % 2]
      far = [ p2[0] + dr2, p2[1] + dc2 ]
      far == p3
    end
  end

  def score_goal(game_player, goal, points, message)
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: game_player,
      deliberate: false,
      action: "score_goal",
      reversible: true,
      payload: { "goal" => goal, "score" => points },
      message: message
    )
    game_player.bonus_scores = (game_player.bonus_scores || {}).merge(
      goal => (game_player.bonus_scores&.dig(goal) || 0) + points
    )
  end

  def next_card
    card = @game.deck.shift
    shuffle_terrain_deck if @game.deck.size < 1
    @game.save
    card
  end

  def shuffle_terrain_deck
    @game.deck = @game.discard.shuffle
    @game.discard.clear
    @game.save
  end

  def place_warrior(row, col, game_player, tile_klass:)
    action_before = @game.current_action.slice("type", "klass")
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: game_player,
      deliberate: true,
      action: "place_warrior",
      to: "[#{row}, #{col}]",
      reversible: true,
      payload: { "klass" => tile_klass, "action_before" => action_before },
      message: "#{game_player.player.handle} placed a warrior at [#{row}, #{col}]"
    )
    @game.board_contents_will_change!
    @game.board_contents.place_warrior(row, col, game_player.order)
    game_player.decrement_warrior_supply!
    apply_tile_pickup(game_player, row, col)
  end

  def remove_warrior(row, col, game_player, tile_klass:)
    action_before = @game.current_action.slice("type", "klass")
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: game_player,
      deliberate: true,
      action: "remove_warrior",
      from: "[#{row}, #{col}]",
      reversible: true,
      payload: { "klass" => tile_klass, "action_before" => action_before },
      message: "#{game_player.player.handle} removed a warrior from [#{row}, #{col}]"
    )
    @game.board_contents_will_change!
    @game.board_contents.remove(row, col)
    game_player.increment_warrior_supply!
  end

  def place_ship(row, col, game_player, tile_klass:)
    action_before = @game.current_action.slice("type", "klass")
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: game_player,
      deliberate: true,
      action: "place_ship",
      to: "[#{row}, #{col}]",
      reversible: true,
      payload: { "klass" => tile_klass, "action_before" => action_before },
      message: "#{game_player.player.handle} placed their ship at [#{row}, #{col}]"
    )
    @game.board_contents_will_change!
    @game.board_contents.place_ship(row, col, game_player.order)
    game_player.decrement_ship_supply!
  end

  def remove_ship(row, col, game_player, tile_klass:)
    action_before = @game.current_action.slice("type", "klass")
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: game_player,
      deliberate: true,
      action: "remove_ship",
      from: "[#{row}, #{col}]",
      reversible: true,
      payload: { "klass" => tile_klass, "action_before" => action_before },
      message: "#{game_player.player.handle} removed their ship from [#{row}, #{col}]"
    )
    @game.board_contents_will_change!
    @game.board_contents.remove(row, col)
    game_player.increment_ship_supply!
  end

  def move_ship(row, col, game_player, tile_klass:)
    from = @game.current_action["from"]
    action_before = @game.current_action.slice("type", "klass", "from")
    from_coord = Coordinate.from_key(from)
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: game_player,
      deliberate: true,
      action: "move_ship",
      from: from,
      to: "[#{row}, #{col}]",
      reversible: true,
      payload: { "klass" => tile_klass, "action_before" => action_before },
      message: "#{game_player.player.handle} moved their ship to [#{row}, #{col}]"
    )
    @game.board_contents_will_change!
    @game.board_contents.move_settlement(from_coord.row, from_coord.col, row, col)
  end

  def place_wagon(row, col, game_player, tile_klass:)
    action_before = @game.current_action.slice("type", "klass")
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: game_player,
      deliberate: true,
      action: "place_wagon",
      to: "[#{row}, #{col}]",
      reversible: true,
      payload: { "klass" => tile_klass, "action_before" => action_before },
      message: "#{game_player.player.handle} placed their wagon at [#{row}, #{col}]"
    )
    @game.board_contents_will_change!
    @game.board_contents.place_wagon(row, col, game_player.order)
    game_player.decrement_wagon_supply!
  end

  def remove_wagon(row, col, game_player, tile_klass:)
    action_before = @game.current_action.slice("type", "klass")
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: game_player,
      deliberate: true,
      action: "remove_wagon",
      from: "[#{row}, #{col}]",
      reversible: true,
      payload: { "klass" => tile_klass, "action_before" => action_before },
      message: "#{game_player.player.handle} removed their wagon from [#{row}, #{col}]"
    )
    @game.board_contents_will_change!
    @game.board_contents.remove(row, col)
    game_player.increment_wagon_supply!
  end

  def move_wagon(row, col, game_player, tile_klass:)
    from = @game.current_action["from"]
    action_before = @game.current_action.slice("type", "klass", "from")
    from_coord = Coordinate.from_key(from)
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: game_player,
      deliberate: true,
      action: "move_wagon",
      from: from,
      to: "[#{row}, #{col}]",
      reversible: true,
      payload: { "klass" => tile_klass, "action_before" => action_before },
      message: "#{game_player.player.handle} moved their wagon to [#{row}, #{col}]"
    )
    @game.board_contents_will_change!
    @game.board_contents.move_settlement(from_coord.row, from_coord.col, row, col)
  end
end
