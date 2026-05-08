class TurnViewAdapter
  DEFAULT_MANDATORY = Turn::DEFAULT_MANDATORY

  def initialize(game)
    @game = game
    @legacy = TurnEngine.new(game)
  end

  def turn_state
    return @legacy.turn_state unless turn_backed?

    if turn.sub_phase
      tile = tile_for_sub_phase
      return "#{player.player.handle} must act" unless tile

      hand = tile.fort_tile? && turn.sub_phase.respond_to?(:fort_terrain) ? turn.sub_phase.fort_terrain : player.hand.first
      tile.action_message(player_handle: player.player.handle, terrain_names: Boards::Board::TERRAIN_NAMES, hand: hand)
    elsif turn.mandatory_remaining > 0 && player.settlements_remaining?
      terrain_name = Boards::Board::TERRAIN_NAMES[player.hand.first]
      "#{player.player.handle} must build " \
        "#{ActionController::Base.helpers.pluralize(turn.mandatory_remaining, 'settlement')} on " \
        "#{terrain_name}" \
        "#{' or select a tile' if any_tile_activatable?}"
    else
      "#{player.player.handle} must end their turn" \
        "#{' or select a tile' if any_tile_activatable?}"
    end
  end

  def buildable_cells
    return @legacy.buildable_cells unless turn_backed?
    return [] unless @game.playing?

    @game.instantiate
    return mandatory_buildable_cells unless turn.sub_phase

    case (phase = turn.sub_phase)
    when Turn::SubPhases::TileBuildPhase
      tile_build_cells(phase)
    when Turn::SubPhases::FortPhase
      empty_terrain_cells(phase.fort_terrain)
    when Turn::SubPhases::SettlementMovePhase
      settlement_move_cells(phase)
    when Turn::SubPhases::ResettlementPhase
      resettlement_cells(phase)
    when Turn::SubPhases::TargetedRemovalPhase
      phase.pending_orders.flat_map { |order| @game.board_contents.settlements_for(order) }
        .reject { |row, col| @game.board_contents.city_hall_at?(row, col) }
    when Turn::SubPhases::WallPlacementPhase
      wall_cells(phase)
    when Turn::SubPhases::CityHallPhase
      city_hall_centers
    when Turn::SubPhases::MeeplePlacementPhase
      meeple_cells(phase)
    else
      []
    end
  end

  def tile_activatable?(tile_hash)
    return @legacy.tile_activatable?(tile_hash) unless turn_backed?
    return false if tile_hash["used"]

    tile_class = Tiles::Tile.for_klass(tile_hash["klass"])
    return false unless tile_class
    return false if turn.sub_phase
    return false unless turn.mandatory_remaining == DEFAULT_MANDATORY || turn.mandatory_remaining <= 0 || !player.settlements_remaining?

    @game.instantiate
    tile = tile_class.new(0)
    return false if tile.places_wall? && @game.stone_walls <= 0
    return false if tile.builds_settlement? && !player.settlements_remaining?
    return opponents_with_settlements.any? if tile.sword_tile?

    tile.activatable?(
      player_order: player.order,
      board_contents: @game.board_contents,
      board: @game.board,
      hand: player.hand.first,
      supply: player.supply_hash
    )
  end

  def turn_endable?
    return @legacy.turn_endable? unless turn_backed?

    @game.playing? && !turn.sub_phase && (turn.mandatory_remaining <= 0 || !player.settlements_remaining?)
  end

  def tile_action_endable?
    return @legacy.tile_action_endable? unless turn_backed?
    return false unless @game.playing?

    case turn.sub_phase
    when Turn::SubPhases::ResettlementPhase
      turn.sub_phase.moves.to_i >= 1
    when Turn::SubPhases::WallPlacementPhase
      turn.sub_phase.walls_placed.to_i >= 1
    else
      false
    end
  end

  def undo_allowed?
    return @legacy.undo_allowed? unless turn_click_backed?

    click = TurnClick.most_recent_for(@game)
    click&.reversible? || false
  end

  def city_hall_clusters
    return @legacy.city_hall_clusters unless turn_backed?
    return {} unless turn.sub_phase.is_a?(Turn::SubPhases::CityHallPhase)

    city_hall_centers.to_h do |row, col|
      [ "#{row},#{col}", city_hall_tile.cluster_hexes(row, col, @game.board_contents) ]
    end
  end

  def tile_used?(tile_hash)
    tile_hash["used"] || (tile_hash["klass"] == "MandatoryTile" && turn_endable?)
  end

  def mandatory_remaining
    return @game.mandatory_count unless turn_backed?

    turn.mandatory_remaining
  end

  def outpost_activatable?(tile_hash)
    return @legacy.outpost_activatable?(tile_hash) unless turn_backed?
    return false if tile_hash["used"]
    return false if turn.outpost_active
    return false if turn.sub_phase && !turn.sub_phase.is_a?(Turn::SubPhases::TileBuildPhase)

    player.settlements_remaining?
  end

  def current_action_type
    return @game.current_action&.dig("type") unless turn_backed?
    return "mandatory" unless turn.sub_phase

    active_tile_klass&.delete_suffix("Tile")&.downcase
  end

  def current_action_from
    return @game.current_action&.dig("from") unless turn_backed?
    return nil unless turn.sub_phase.respond_to?(:source)

    turn.sub_phase.source&.to_key
  end

  def chosen_terrain
    return @game.current_action&.dig("chosen_terrain") unless turn_backed?

    case turn.sub_phase
    when Turn::SubPhases::WallPlacementPhase
      turn.sub_phase.chosen_terrain
    when Turn::SubPhases::FortPhase
      turn.sub_phase.fort_terrain
    end
  end

  def outpost_active?
    return @game.current_action&.dig("outpost_active") unless turn_backed?

    turn.outpost_active
  end

  def active_tile?(tile_hash)
    current_action_type == tile_hash["klass"].delete_suffix("Tile").downcase
  end

  def tile_progress(tile_hash)
    return legacy_tile_progress(tile_hash) unless turn_backed?
    return nil unless active_tile?(tile_hash)

    case turn.sub_phase
    when Turn::SubPhases::ResettlementPhase
      "#{turn.sub_phase.budget} steps left"
    end
  end

  def meeple_tile_active?
    %w[BarracksTile LighthouseTile WagonTile].include?(active_tile_klass)
  end

  private

  def turn_backed?
    @game.current_action.is_a?(Hash) && @game.current_action["turn"].is_a?(Hash)
  end

  def turn_click_backed?
    TurnClick.where(game_id: @game.id).exists?
  end

  def turn
    @turn ||= Turn.from_game(@game)
  end

  def player
    @game.current_player
  end

  def any_tile_activatable?
    (player.tiles || []).any? { |tile| tile_activatable?(tile) }
  end

  def mandatory_buildable_cells
    return [] unless player.settlements_remaining? && turn.mandatory_remaining > 0

    if turn.outpost_active
      empty_terrain_cells(player.hand.first)
    else
      mandatory_cells_for(player.hand.first)
    end
  end

  def mandatory_cells_for(terrain)
    list = TurnEngine.new(@game).available_list(player.order, terrain)
    (0..19).flat_map { |row| (0..19).filter_map { |col| [ row, col ] if list[row][col] } }
  end

  def tile_build_cells(phase)
    if phase.restricted_terrain
      empty_terrain_cells(phase.restricted_terrain)
    else
      tile = Tiles::Tile.for_klass(phase.tile_klass)&.new(0)
      return [] unless tile

      tile.valid_destinations(board_contents: @game.board_contents, board: @game.board, player_order: player.order, hand: player.hand.first)
    end
  end

  def settlement_move_cells(phase)
    tile = Tiles::Tile.for_klass(phase.tile_klass)&.new(0)
    return [] unless tile

    if phase.source
      tile.valid_destinations(
        from_row: phase.source.row,
        from_col: phase.source.col,
        board_contents: @game.board_contents,
        board: @game.board,
        player_order: player.order,
        hand: player.hand.first
      )
    else
      tile.selectable_settlements(player_order: player.order, board_contents: @game.board_contents, board: @game.board, hand: player.hand.first)
    end
  end

  def resettlement_cells(phase)
    tile = Tiles::Nomad::ResettlementTile.new(0)
    if phase.source
      tile.valid_destinations(
        from_row: phase.source.row,
        from_col: phase.source.col,
        board_contents: @game.board_contents,
        board: @game.board,
        player_order: player.order,
        budget: phase.budget,
        vacated: phase.vacated
      )
    else
      tile.selectable_settlements(
        player_order: player.order,
        board_contents: @game.board_contents,
        board: @game.board,
        budget: phase.budget,
        vacated: phase.vacated
      )
    end
  end

  def wall_cells(phase)
    terrains = phase.chosen_terrain ? [ phase.chosen_terrain ] : Array(player.hand)
    terrains.flat_map do |terrain|
      Tiles::QuarryTile.new(0).valid_destinations(
        board_contents: @game.board_contents,
        board: @game.board,
        player_order: player.order,
        hand: terrain
      )
    end.uniq
  end

  def city_hall_centers
    city_hall_tile.valid_destinations(
      board_contents: @game.board_contents,
      board: @game.board,
      player_order: player.order,
      supply: player.supply_hash
    )
  end

  def meeple_cells(phase)
    tile = Tiles::Tile.for_klass(phase.tile_klass)&.new(0)
    return [] unless tile

    if phase.source
      tile.valid_destinations(
        from_row: phase.source.row,
        from_col: phase.source.col,
        board_contents: @game.board_contents,
        board: @game.board,
        player_order: player.order,
        supply: player.supply_hash
      )
    else
      tile.valid_destinations(
        board_contents: @game.board_contents,
        board: @game.board,
        player_order: player.order,
        supply: player.supply_hash
      )
    end
  end

  def empty_terrain_cells(terrain)
    return [] unless terrain

    (0..19).flat_map do |row|
      (0..19).filter_map do |col|
        [ row, col ] if @game.board_contents.empty?(row, col) && @game.board.terrain_at(row, col) == terrain
      end
    end
  end

  def city_hall_tile
    Tiles::CityHallTile.new(0)
  end

  def tile_for_sub_phase
    klass = active_tile_klass
    Tiles::Tile.for_klass(klass)&.new(0) if klass
  end

  def active_tile_klass
    case (phase = turn.sub_phase)
    when Turn::SubPhases::TileBuildPhase, Turn::SubPhases::SettlementMovePhase, Turn::SubPhases::MeeplePlacementPhase
      phase.tile_klass
    when Turn::SubPhases::ResettlementPhase
      Turn::SubPhases::ResettlementPhase::TILE_KLASS
    when Turn::SubPhases::TargetedRemovalPhase
      Turn::SubPhases::TargetedRemovalPhase::TILE_KLASS
    when Turn::SubPhases::WallPlacementPhase
      Turn::SubPhases::WallPlacementPhase::TILE_KLASS
    when Turn::SubPhases::CityHallPhase
      Turn::SubPhases::CityHallPhase::TILE_KLASS
    when Turn::SubPhases::FortPhase
      "FortTile"
    end
  end

  def opponents_with_settlements
    @game.game_players
      .reject { |game_player| game_player.order == player.order }
      .select { |game_player| @game.board_contents.settlements_for(game_player.order).any? }
  end

  def legacy_tile_progress(tile_hash)
    return nil unless active_tile?(tile_hash)

    if @game.current_action["remaining"]
      "#{@game.current_action['remaining']} left"
    elsif @game.current_action["budget"]
      "#{@game.current_action['budget']} steps left"
    end
  end
end
