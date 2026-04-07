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
            if @game.board.content_at(nr, nc) == nil && @game.board.terrain_at(nr, nc) == terrain
              any = available[nr][nc] = true
            end
          end
        end
      end
    end
    return available if any

    20.times do |row|
      20.times do |col|
        if @game.board.terrain_at(row, col) == terrain
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
    return "Not avilalable" unless available?(game_player.order, card_terrain, row, col)
    build_on_terrain(card_terrain, row, col, game_player)
    @game.mandatory_count -= 1
    Rails.logger.debug("Building settlement at #{row}, #{col} for player #{game_player.order}")
    game_player.save
    @game.save
  end

  def activate_tile_build(row, col)
    @game.instantiate
    game_player = @game.current_player
    return "No settlements left" unless game_player.settlements_remaining?
    tile_klass = "#{@game.current_action["type"].capitalize}Tile"
    tile = game_player.find_unused_tile(tile_klass)
    return "Not available" unless tile
    tile_obj = Tiles::Tile.from_hash(tile)
    destinations = tile_obj.valid_destinations(
      board_contents: @game.board_contents, board: @game.board, player_order: game_player.order, hand: game_player.hand
    )
    return "Not available" unless destinations.include?([ row, col ])
    game_player.mark_tile_used!(tile_klass)
    build_on_terrain(@game.board.terrain_at(row, col), row, col, game_player, tile_klass: tile_klass)
    @game.current_action = { "type" => "mandatory" }
    game_player.save
    @game.save
  end

  def select_action(type)
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: @game.current_player,
      deliberate: true,
      action: "select_action",
      to: type,
      reversible: true,
      message: "#{@game.current_player.player.handle} selected the #{type} action"
    )
    @game.current_action = { "type" => type }
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
    tile_klass = "#{@game.current_action["type"].capitalize}Tile"
    @game.move_count += 1
    @game.moves.create(
      order: @game.move_count,
      game_player: @game.current_player,
      deliberate: true,
      action: "move_settlement",
      from: from,
      to: Coordinate.new(row, col).to_key,
      reversible: true,
      payload: { "tile_klass" => tile_klass },
      message: "#{@game.current_player.player.handle} moved a settlement to [#{row}, #{col}]"
    )
    @game.board_contents_will_change!
    @game.board_contents.move_settlement(*from_coord, row, col)
    @game.current_action = { "type" => "mandatory" }
    @game.current_player.mark_tile_used!(tile_klass)
    apply_tile_forfeit(@game.current_player)
    apply_tile_pickup(@game.current_player, row, col)
    @game.current_player.save
    @game.save
  end

  def tile_activatable?(tile)
    return false if tile["used"]
    return false unless "Tiles::#{tile["klass"]}".safe_constantize
    return false unless @game.current_action["type"] == "mandatory" &&
      (@game.mandatory_count == Game::MANDATORY_COUNT || @game.mandatory_count <= 0 || !@game.current_player.settlements_remaining?)
    @game.instantiate
    tile_obj = Tiles::Tile.from_hash(tile)
    return false if tile_obj.builds_settlement? && !@game.current_player.settlements_remaining?
    ctx = { player_order: @game.current_player.order, board_contents: @game.board_contents, board: @game.board, hand: @game.current_player.hand }
    tile_obj.activatable?(**ctx)
  end

  def turn_endable?
    @game.current_action["type"] == "mandatory" &&
      (@game.mandatory_count <= 0 || !@game.current_player.settlements_remaining?)
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
    tile_klass = "Tiles::#{action_type.capitalize}Tile".safe_constantize if action_type != "mandatory"
    if tile_klass
      tile_klass.new(0).action_message(
        player_handle: @game.current_player.player.handle,
        terrain_names: Boards::Board::TERRAIN_NAMES,
        hand: @game.current_player.hand
      )
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
    @buildable_cells ||= begin
      @game.instantiate
      player = @game.current_player
      action = @game.current_action["type"]

      if action == "mandatory"
        if player.settlements_remaining? && @game.mandatory_count > 0
          list = available_list(player.order, player.hand)
          (0..19).flat_map { |r| (0..19).filter_map { |c| [ r, c ] if list[r][c] } }
        else
          []
        end
      else
        klass = "#{action.capitalize}Tile"
        tile = player.find_unused_tile(klass)
        if tile
          tile_obj = Tiles::Tile.from_hash(tile)
          if tile_obj.moves_settlement?
            if @game.current_action["from"]
              from = Coordinate.from_key(@game.current_action["from"])
              tile_obj.valid_destinations(
                from_row: from.row, from_col: from.col,
                board_contents: @game.board_contents, board: @game.board, player_order: player.order, hand: player.hand
              )
            else
              tile_obj.selectable_settlements(
                player_order: player.order, board_contents: @game.board_contents, board: @game.board, hand: player.hand
              )
            end
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

  def build_on_terrain(terrain, row, col, game_player, tile_klass: nil)
    payload = { "card" => terrain }
    payload["tile_klass"] = tile_klass if tile_klass
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
    apply_tile_pickup(game_player, row, col)
  end

  def apply_tile_forfeit(game_player)
    return if (game_player.tiles || []).empty?
    game_player.tiles = game_player.tiles.reject do |tile|
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
    @game.board_contents.neighbors(row, col).each do |adj_r, adj_c|
      klass = @game.board_contents.tile_klass(adj_r, adj_c)
      next unless klass && @game.board_contents.tile_qty(adj_r, adj_c) > 0
      tile_key = Coordinate.new(adj_r, adj_c).to_key
      next if held_locations.include?(tile_key)
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
end
