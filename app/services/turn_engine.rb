class TurnEngine
  # Exposed so a Sub-phase's #click can reach the game to orchestrate its own
  # action (State pattern: phase = State, engine = Context).
  attr_reader :game

  def initialize(game)
    @game = game
  end

  def click(coordinate)
    @game.turn_phase.click(coordinate, self)
  end

  # A 20x20 boolean grid of the cells legal for a mandatory-style build of
  # `terrain` (used for 2-card terrain disambiguation and view highlighting).
  # A grid view of BoardState#buildable_cells_for — the adjacent-if-possible
  # rule lives there, not here.
  def available_list(active_player, terrain)
    return nil unless @game.playing?
    grid = Array.new(20) { Array.new(20, false) }
    @game.board_contents.buildable_cells_for(active_player, terrain).each { |row, col| grid[row][col] = true }
    grid
  end

  def activate_outpost
    capture_undo_snapshot
    @game.instantiate
    game_player = @game.current_player
    return "No outpost tile" unless game_player.find_unused_tile("OutpostTile")
    return "Not in build action" unless build_action?
    record_move(
      action: "activate_outpost",
      deliberate: true,
      reversible: true,
      game_player: game_player,
      message: "#{game_player.player.handle} activated the Outpost tile"
    )
    game_player.mark_tile_used!("OutpostTile")
    @game.turn_phase = @game.turn_phase.with_outpost_active
    game_player.save
    @game.save
  end

  def activate_fort_tile
    capture_undo_snapshot
    @game.instantiate
    game_player = @game.current_player
    return "Not available" unless @game.turn_phase.mandatory_build?
    return "Not available" unless game_player.find_unused_tile("FortTile")
    return "No settlements left" unless game_player.settlements_remaining?

    record_move(
      action: "activate_fort",
      deliberate: true,
      reversible: false,
      game_player: game_player,
      message: "#{game_player.player.handle} activated the Fort tile"
    )

    drawn_card = @game.deck.shift
    if @game.deck.empty?
      @game.deck = @game.discard.shuffle
      @game.discard.clear
    end
    @game.discard.push(drawn_card)
    record_move(
      action: "draw_fort_card",
      deliberate: false,
      reversible: false,
      game_player: game_player,
      payload: { "card" => drawn_card },
      message: "#{game_player.player.handle} drew a #{Boards::Board::TERRAIN_NAMES[drawn_card]} card"
    )

    @game.turn_phase = TurnPhase::FortPhase.new(fort_terrain: drawn_card)
    @game.save
  end

  def select_action(type)
    capture_undo_snapshot
    klass_name = tile_klass_name_for_type(type)
    payload = { "klass" => klass_name }
    tile_klass = Tiles::Tile.for_klass(klass_name)
    tile_obj = tile_klass&.new(0)
    selected_phase =
      if tile_obj&.builds_settlement? || tile_obj&.places_wall?
        TurnPhase::TileBuildPhase.new(
          action_type: type,
          klass_name: klass_name,
          chosen_terrain: @game.turn_phase.chosen_terrain,
          remaining: (tile_obj.build_quota if tile_obj.repeats_build?),
          walls_placed: (0 if tile_obj.places_wall?)
        )
      elsif tile_obj&.moves_settlement? && !tile_obj.resettles?
        TurnPhase::SettlementMovePhase.new(
          action_type: type,
          klass_name: klass_name,
          chosen_terrain: @game.turn_phase.chosen_terrain
        )
      elsif tile_obj&.resettles?
        TurnPhase::ResettlementPhase.new(
          budget: 4,
          moves: 0
        )
      elsif tile_obj&.places_meeple? && %w[ship wagon].include?(tile_obj.meeple_kind)
        TurnPhase::MeepleMovementPhase.new(
          action_type: type,
          klass_name: klass_name,
          budget: 3,
          moves: 0
        )
      elsif tile_obj&.places_meeple? && tile_obj.meeple_kind == "warrior"
        TurnPhase::MeepleActionPhase.new(
          action_type: type,
          klass_name: klass_name
        )
      elsif tile_obj&.places_city_hall?
        TurnPhase::CityHallPhase.new(
          action_type: type,
          klass_name: klass_name
        )
      elsif tile_obj&.sword_tile?
        opponents = @game.game_players
          .reject { |gp| gp == @game.current_player }
          .select { |gp| @game.board_contents.settlements_for(gp.order).any? }
          .map(&:order)
          .sort
        return "No opponents with settlements" if opponents.empty?
        payload["pending_orders"] = opponents
        TurnPhase::TargetedRemovalPhase.new(
          action_type: type,
          klass_name: klass_name,
          pending_orders: opponents
        )
      else
        raise ArgumentError, "no TurnPhase for action type #{type.inspect}"
      end
    record_move(
      action: "select_action",
      deliberate: true,
      reversible: true,
      to: type,
      payload: payload,
      message: "#{@game.current_player.player.handle} selected the #{type} action"
    )
    phase_result = @game.turn_phase.transition(
      TurnPhase::Events::TileActionSelected.new,
      TurnPhase::Facts::TileActionSelection.new(selected_phase: selected_phase)
    )
    @game.turn_phase = phase_result.next_phase
    @game.save
  end

  def end_tile_action
    @game.instantiate
    game_player = @game.current_player
    tile_klass_name = current_action_tile_klass
    current_phase = @game.turn_phase
    moves_made = current_phase.moves.to_i
    walls_placed = current_phase.walls_placed.to_i
    return "Not allowed" unless moves_made >= 1 || walls_placed >= 1

    game_player.mark_tile_used!(tile_klass_name)
    reset_to_mandatory
    game_player.save
    @game.save
  end

  def tile_activatable?(tile)
    return false if tile["used"]
    return false unless Tiles::Tile.for_klass(tile["klass"])
    return false unless @game.turn_phase.mandatory_build? &&
      (@game.mandatory_count == Game::MANDATORY_COUNT || @game.mandatory_count <= 0 || !@game.current_player.settlements_remaining?)
    @game.instantiate
    tile_obj = Tiles::Tile.from_hash(tile)
    return false if tile_obj.places_wall? && @game.stone_walls <= 0
    return false if tile_obj.builds_settlement? && !@game.current_player.settlements_remaining?
    ctx = { player_order: @game.current_player.order, board_contents: @game.board_contents, hand: @game.current_player.hand.first, supply: @game.current_player.supply_hash }
    tile_obj.activatable?(**ctx)
  end

  def turn_endable?
    @game.playing? &&
      @game.turn_phase.mandatory_build? &&
      (@game.mandatory_count <= 0 || !@game.current_player.settlements_remaining?)
  end

  def outpost_activatable?(tile)
    return false if tile["used"]
    return false unless build_action?
    return false if @game.turn_phase.outpost_active?
    @game.current_player.settlements_remaining?
  end

  def tile_action_endable?
    @game.playing? && @game.turn_phase.tile_action_endable?
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
    return "Game over" unless @game.current_player_id
    current_phase = @game.turn_phase
    action_type = current_phase.type
    tile_klass = Tiles::Tile.for_klass(current_action_tile_klass) if action_type != "mandatory"
    if tile_klass
      tile_for_msg = tile_klass.new(0)
      hand_for_msg = if tile_for_msg.fort_tile?
        current_phase.fort_terrain
      else
        @game.current_player.hand.first
      end
      msg = tile_for_msg.action_message(
        player_handle: @game.current_player.player.handle,
        terrain_names: Boards::Board::TERRAIN_NAMES,
        hand: hand_for_msg
      )
      remaining = current_phase.remaining
      remaining ? "#{msg} (#{remaining} remaining)" : msg
    else
      has_activatable = (@game.current_player&.tiles || []).any? { |t| tile_activatable?(t) }
      if @game.mandatory_count > 0 && @game.current_player.settlements_remaining?
        terrain_name = if (ct = effective_terrain(@game.current_player))
          Boards::Board::TERRAIN_NAMES[ct]
        else
          @game.current_player.hand.map { |t| Boards::Board::TERRAIN_NAMES[t] }.join(" or ")
        end
        "#{@game.current_player.player.handle} must build " \
        "#{ActionController::Base.helpers.pluralize(@game.mandatory_count, "settlement")} on " \
        "#{terrain_name}" \
        "#{" or select a tile" if has_activatable}"
      else
        "#{@game.current_player.player.handle} must end their turn" \
        "#{" or select a tile" if has_activatable}"
      end
    end
  end

  def end_turn
    capture_undo_snapshot
    Rails.logger.debug("END TURN REQUESTED on GAME #{@game.id}")
    Rails.logger.debug(" - current player #{@game.current_player.inspect}")
    @game.instantiate
    game_player = @game.current_player
    apply_clock!(game_player) if @game.timed?
    card_discarded = game_player.hand
    @game.discard.push(*game_player.hand)
    new_cards = [ @game.next_card ]
    new_cards << @game.next_card if has_crossroads_tile?(game_player)
    game_player.hand = new_cards
    card_drawn = game_player.hand
    reshuffled = @game.discard.empty?
    @game.mandatory_count = Game::MANDATORY_COUNT
    @game.current_action = { "type" => "mandatory" }
    @game.turn_started_at = Time.current if @game.timed?
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
    record_move(
      action: "end_turn",
      deliberate: true,
      reversible: false,
      game_player: game_player,
      payload: { "card_discarded" => card_discarded, "card_drawn" => card_drawn,
                 "reshuffled" => reshuffled },
      message: "#{game_player.player.handle} ended their turn"
    )
    ActiveRecord::Base.transaction do
      game_player.save
      @game.current_player.save
      @game.save
    end
    max_order = @game.game_players.count - 1
    if @game.ending? && game_player.order == max_order
      record_move(
        action: "end_game",
        deliberate: false,
        reversible: false,
        game_player: game_player,
        message: "Game over!"
      )
      @game.save
      @game.complete!
    end
  end

  # The cells the current player may legally target right now, owned by the
  # active sub-phase (State pattern). Recomputed each call (no memo): a derived
  # view of mutable game state that the guards read mid-action, so caching
  # across a mutation would be unsafe.
  def buildable_cells
    return [] unless @game.playing?
    @game.instantiate
    @game.turn_phase.legal_targets(
      board_contents: @game.board_contents, player: @game.current_player, game: @game
    )
  end

  # Canonical set of hexes the current player may legally click right now, for
  # O(1) membership. This is the single source of truth that both the view
  # (via buildable_cells) and every action guard share, so they cannot drift.
  # It does not include popup-trigger affordances (clicking your own ship/wagon
  # to open the move/remove popup) — those are routed by select_meeple /
  # remove_meeple, not build/move targets.
  def legal_targets
    buildable_cells.to_set
  end

  def city_hall_clusters
    return {} unless @game.turn_phase.city_hall?
    @game.instantiate
    player = @game.current_player
    tile_obj = Tiles::Location::CityHallTile.new(0)
    centers = tile_obj.valid_destinations(
      board_contents: @game.board_contents,
      player_order: player.order, supply: player.supply_hash
    )
    centers.to_h do |r, c|
      cluster = tile_obj.cluster_hexes(r, c, @game.board_contents)
      [ "#{r},#{c}", cluster ]
    end
  end

  def undo_last_move
    last = @game.moves.where(deliberate: true).order(:id).last
    return unless last&.reversible?
    @game.restore_snapshot!(last.snapshot_before)
    @game.moves.where("id >= ?", last.id).destroy_all
  end

  def undo_max
    undo_last_move while undo_allowed?
  end

  private

  # Snapshot of pre-action game state, attached to the deliberate Move an action
  # records so undo can restore it (ADR-0002). Captured at the start of each
  # public action, so it reflects the state immediately before the action even
  # if the engine was constructed earlier. Resetting game_players avoids
  # leaving a stale association cache (current_player and game_players are
  # distinct instances; downstream paths re-read the collection).
  def capture_undo_snapshot
    @snapshot_before = @game.capture_snapshot
    @game.game_players.reset
  end

  # Fischer-with-cap clock accounting for the mover at end_turn: deduct time
  # elapsed since their clock started running, credit the speed's increment,
  # and cap at the bank (a negative result is allowed — the player keeps
  # playing until an opponent claims victory). No deduction at all if the
  # mover hasn't made a deliberate move yet this game (clock_started_at nil);
  # the window otherwise starts at whichever is later, the turn's start or
  # the mover's clock_started_at (it can fall mid-turn on their first move).
  def apply_clock!(game_player)
    bank_ms = Game::SPEEDS.fetch(@game.speed)[:bank_ms]
    increment_ms = Game::SPEEDS.fetch(@game.speed)[:increment_ms]
    elapsed_ms =
      if game_player.clock_started_at.nil?
        0
      else
        window_start = [ @game.turn_started_at, game_player.clock_started_at ].compact.max
        ((Time.current - window_start) * 1000).to_i
      end
    remaining = game_player.time_remaining_ms.to_i - elapsed_ms + increment_ms
    game_player.time_remaining_ms = [ remaining, bank_ms ].min
  end

  # Single seam for recording moves. Increments move_count, defaults the
  # game_player to the current player, and attaches the request's pre-click
  # snapshot to deliberate moves so undo can restore it (ADR-0002). Also the
  # single place a timed player's clock_started_at gets stamped, on their
  # first deliberate move of the game: free thinking time before that.
  def record_move(action:, deliberate:, reversible:, message: nil, game_player: nil, from: nil, to: nil, payload: nil)
    mover = game_player || @game.current_player
    if deliberate && @game.timed? && mover&.clock_started_at.nil?
      mover.update!(clock_started_at: Time.current)
    end
    @game.move_count += 1
    @game.moves.create!(
      order: @game.move_count,
      game_player: mover,
      action: action,
      deliberate: deliberate,
      reversible: reversible,
      message: message,
      from: from,
      to: to,
      payload: payload,
      snapshot_before: (deliberate ? @snapshot_before : nil)
    )
  end

  def build_action?
    return true if @game.turn_phase.mandatory_build?
    klass = Tiles::Tile.for_klass(current_action_tile_klass)
    klass&.new(0)&.builds_settlement? || false
  end


  # Returns the tile klass name (without "Tiles::" prefix) for the current action.
  def current_action_tile_klass
    @game.turn_phase.tile_klass_name
  end

  # Derives the tile klass name from the action type string.
  # The type is generated by the view as tile["klass"].delete_suffix("Tile").downcase,
  # so we reverse by finding the matching tile in the player's tile list.
  def tile_klass_name_for_type(type)
    tile = @game.current_player.tiles&.find { |t| t["klass"].delete_suffix("Tile").downcase == type }
    tile&.dig("klass") || "#{type.capitalize}Tile"
  end

  def build_on_terrain(terrain, row, col, game_player, tile_klass: nil)
    payload = { "card" => terrain }
    payload["tile_klass"] = tile_klass if tile_klass
    game_player.decrement_supply!
    if game_player.settlements_remaining == 0
      @game.end_trigger_count += 1
      payload["triggered_ending"] = true
    end
    record_move(
      action: "build",
      deliberate: true,
      reversible: true,
      game_player: game_player,
      from: "supply",
      to: "[#{row}, #{col}]",
      payload: payload,
      message: "#{game_player.player.handle} built a settlement on #{Boards::Board::TERRAIN_NAMES[terrain]} at [#{row}, #{col}]"
    )
    @game.board_contents_will_change!
    @game.board_contents.place_settlement(row, col, game_player.order)
    check_ambassadors_goal(game_player, row, col)
    check_shepherds_goal(game_player, row, col, terrain)
    apply_tile_pickup(game_player, row, col)
  end

  def apply_tile_forfeit(game_player)
    return if (game_player.tiles || []).empty?
    active_tile_klass = @game.turn_phase.type == "mandatory" ? nil : current_action_tile_klass
    changes = prefer_used_forfeit!(game_player, active_tile_klass)
    record_used_redistribution(game_player, changes) if changes.any?
    game_player.tiles = game_player.tiles.reject do |tile|
      next false unless forfeit_eligible?(tile, active_tile_klass)
      loc = tile["from"]
      should_forfeit = !source_adjacent?(game_player, loc)
      klass = @game.board_contents.tile_klass(*Coordinate.from_key(loc)) || tile["klass"]
      if should_forfeit
        record_move(
          action: "forfeit_tile",
          deliberate: false,
          reversible: true,
          game_player: game_player,
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

  # A tile is subject to location forfeit unless it is the currently-active
  # tile, a Nomad tile (which expires by turn, never by location), or has no
  # source location.
  def forfeit_eligible?(tile, active_tile_klass)
    return false if tile["klass"] == active_tile_klass
    return false if Tiles::Tile.for_klass(tile["klass"])&.new(0)&.nomad_tile?
    !tile["from"].nil?
  end

  def source_adjacent?(game_player, loc)
    return false unless loc
    @game.board_contents.settlements_for(game_player.order).any? do |s_row, s_col|
      @game.board_contents.neighbors(s_row, s_col).any? { |nr, nc| Coordinate.new(nr, nc).to_key == loc }
    end
  end

  # Prefer-used forfeit: copies of the same klass are interchangeable, so when
  # some sources are still adjacent and some are not, reassign the `used` flags
  # within the klass group to the still-adjacent copies first — i.e. the
  # surviving copies become the unused ones, and the used copies are the ones
  # that go on to be forfeited. Returns the list of flag changes so the
  # redistribution can be replayed and undone.
  def prefer_used_forfeit!(game_player, active_tile_klass)
    changes = []
    eligible = (game_player.tiles || []).select { |t| forfeit_eligible?(t, active_tile_klass) }
    eligible.group_by { |t| t["klass"] }.each_value do |group|
      adjacent, forfeiting = group.partition { |t| source_adjacent?(game_player, t["from"]) }
      # Only a mixed group forces a forfeit choice; otherwise leave flags as-is.
      next if adjacent.empty? || forfeiting.empty?
      unused_first = group.map { |t| t["used"] }.sort_by { |used| used ? 1 : 0 }
      (adjacent + forfeiting).each_with_index do |tile, i|
        before, after = tile["used"], unused_first[i]
        next if before == after
        tile["used"] = after
        changes << { "from" => tile["from"], "before" => before, "after" => after }
      end
    end
    changes
  end

  # Records the prefer-used flag reassignment as a reversible move so that both
  # replay (forward) and undo (reverse) reproduce it. Ordered before the
  # forfeit_tile moves so undo restores forfeited tiles first, then corrects
  # every affected flag back to its pre-forfeit value. No log message: this is
  # internal bookkeeping, not a player-visible action.
  def record_used_redistribution(game_player, changes)
    record_move(
      action: "redistribute_tile_used",
      deliberate: false,
      reversible: true,
      game_player: game_player,
      payload: { "changes" => changes }
    )
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
    record_move(
      action: "pick_up_tile",
      deliberate: false,
      reversible: true,
      game_player: game_player,
      from: tile[:key],
      to: "player_#{game_player.order}",
      payload: { "klass" => tile[:klass], "qty_before" => qty_before },
      message: "#{game_player.player.handle} picked up #{/\A[AEIOU]/.match?(tile[:klass]) ? "an" : "a"} #{tile[:klass].delete_suffix("Tile")} tile at #{tile[:key]}"
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
      record_move(
        action: "grant_meeple",
        deliberate: false,
        reversible: true,
        game_player: game_player,
        payload: { "kind" => kind, "qty" => granted },
        message: "#{game_player.player.handle} acquires #{ActionController::Base.helpers.pluralize(granted, kind)}"
      )
    end
    if tile_obj&.nomad_tile?
      if (scoring = tile_obj.pickup_score)
        goal, points = scoring
        # Score immediately and remove the tile
        game_player.tiles = (game_player.tiles || []).reject { |t| t["klass"] == tile[:klass] && t["from"] == tile[:key] }
        score_goal(game_player, goal, points, "#{game_player.player.handle} scored #{points} points from a #{tile[:klass].delete_suffix("Tile")} tile")
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
      @game.board_contents.empty?(nr, nc) && @game.board_contents.terrain_at(nr, nc) == terrain
    end
    return unless no_adjacent_empty
    score_goal(game_player, "shepherds", 2,
      "#{game_player.player.handle} scored 2 points (Shepherds)")
  end

  def check_families_goal(game_player)
    return unless Array(@game.goals).include?("families")
    builds = @game.turn_phase.builds
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
    Tiles::Location::PaddockTile::STRAIGHT_LINES.any? do |steps|
      dr1, dc1 = steps[p1[0] % 2]
      mid = [ p1[0] + dr1, p1[1] + dc1 ]
      next false unless mid == p2
      dr2, dc2 = steps[p2[0] % 2]
      far = [ p2[0] + dr2, p2[1] + dc2 ]
      far == p3
    end
  end

  def score_goal(game_player, goal, points, message)
    record_move(
      action: "score_goal",
      deliberate: false,
      reversible: true,
      game_player: game_player,
      payload: { "goal" => goal, "score" => points },
      message: message
    )
    game_player.bonus_scores = (game_player.bonus_scores || {}).merge(
      goal => (game_player.bonus_scores&.dig(goal) || 0) + points
    )
  end

  def lock_terrain!(terrain, before)
    phase = @game.turn_phase
    return if phase.chosen_terrain
    @game.turn_phase = phase.with_chosen_terrain(terrain)
  end

  def reset_to_mandatory
    current_phase = @game.turn_phase
    ct = current_phase.chosen_terrain
    @game.turn_phase = TurnPhase::MandatoryBuildPhase.new(chosen_terrain: ct)
  end

  def has_crossroads_tile?(game_player)
    (game_player.tiles || []).any? { |t| t["klass"] == "CrossroadsTile" }
  end

  def effective_terrain(player)
    current_phase = @game.turn_phase
    current_phase.chosen_terrain || (player.hand.size == 1 ? player.hand.first : nil)
  end

  def log_piece_movement_steps(action:, game_player:, from_row:, from_col:, path:, payload:, message_piece:)
    current = Coordinate.new(from_row, from_col)
    path.each do |to_row, to_col|
      destination = Coordinate.new(to_row, to_col)

      record_move(
        action: action,
        deliberate: true,
        reversible: true,
        game_player: game_player,
        from: current.to_key,
        to: destination.to_key,
        payload: payload,
        message: "#{game_player.player.handle} moved their #{message_piece} to #{destination.to_key}"
      )
      @game.board_contents_will_change!
      @game.board_contents.move_settlement(current.row, current.col, destination.row, destination.col)
      apply_tile_forfeit(game_player)
      apply_tile_pickup(game_player, destination.row, destination.col)
      current = destination
    end
  end

  # The shared mutation primitives a Sub-phase's #click calls to carry out its
  # action (State pattern: the phase orchestrates, the engine owns these shared
  # steps). Defined among the privates above; re-exposed here as the phase-
  # facing interface. Also called by the engine's own turn-level gestures
  # (select_action, end_turn, activate_fort_tile, ...) that no single phase owns.
  public :capture_undo_snapshot, :record_move, :reset_to_mandatory, :apply_tile_forfeit,
         :lock_terrain!, :build_on_terrain, :apply_tile_pickup, :log_piece_movement_steps,
         :check_families_goal, :check_ambassadors_goal, :check_shepherds_goal
end
