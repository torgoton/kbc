module MoveApplicator
  def self.dispatch(backend, move)
    player_order = move.game_player.order
    case move.action
    when "select_action"
      backend.apply_select_action(player_order: player_order, type: move.to, klass: move.payload&.dig("klass"), pending_orders: move.payload&.dig("pending_orders"))
    when "select_settlement"
      backend.apply_select_settlement(player_order: player_order, from: move.from)
    when "move_settlement"
      ct_before = move.payload&.key?("chosen_terrain_before") ? move.payload["chosen_terrain_before"] : :not_provided
      backend.apply_move_settlement(player_order: player_order, from: move.from, to: move.to, tile_klass: move.payload&.dig("tile_klass"), action_before: move.payload&.dig("action_before"), phase_after: move.payload&.dig("phase_after"), chosen_terrain_before: ct_before)
    when "activate_fort"
      backend.apply_activate_fort(player_order: player_order)
    when "draw_fort_card"
      backend.apply_draw_fort_card(
        player_order: player_order,
        drawn_card: move.payload["card"],
        deck_after: move.payload["deck_after"],
        discard_after: move.payload["discard_after"]
      )
    when "build"
      fort_terrain = move.payload&.dig("tile_klass") == "FortTile" ? move.payload&.dig("card") : nil
      ct_before = move.payload&.key?("chosen_terrain_before") ? move.payload["chosen_terrain_before"] : :not_provided
      backend.apply_build(player_order: player_order, to: move.to, tile_klass: move.payload&.dig("tile_klass"), remaining_before: move.payload&.dig("remaining_before"), fort_terrain: fort_terrain, build_terrain: move.payload&.dig("card"), chosen_terrain_before: ct_before)
    when "pick_up_tile"
      backend.apply_pick_up_tile(player_order: player_order, from: move.from, klass: move.payload["klass"])
    when "grant_meeple"
      backend.apply_grant_meeple(player_order: player_order, kind: move.payload["kind"], qty: move.payload["qty"])
    when "forfeit_tile"
      backend.apply_forfeit_tile(
        player_order: player_order,
        from: move.from,
        klass: move.payload["klass"],
        used: move.to == "true"
      )
    when "end_turn"
      backend.apply_end_turn(
        player_order: player_order,
        card_discarded: move.payload["card_discarded"],
        card_drawn: move.payload["card_drawn"],
        reshuffled: move.payload["reshuffled"],
        deck_after: move.payload["deck_after"]
      )
    when "score_goal"
      backend.apply_score_goal(player_order: player_order, goal: move.payload["goal"], score: move.payload["score"])
    when "remove_settlement"
      backend.apply_remove_settlement(
        player_order: player_order,
        from: move.from,
        owner_order: move.payload["owner_order"],
        action_before: move.payload["action_before"],
        tile_used: move.payload["tile_used"],
        meeple: move.payload["meeple"]
      )
    when "place_wall"
      ct_before = move.payload&.key?("chosen_terrain_before") ? move.payload["chosen_terrain_before"] : :not_provided
      backend.apply_place_wall(player_order: player_order, to: move.to, chosen_terrain_before: ct_before)
    when "activate_outpost"
      backend.apply_activate_outpost(player_order: player_order)
    when "place_warrior"
      backend.apply_place_warrior(player_order: player_order, to: move.to, action_before: move.payload&.dig("action_before"))
    when "remove_warrior"
      backend.apply_remove_warrior(player_order: player_order, from: move.from, action_before: move.payload&.dig("action_before"))
    when "place_ship"
      backend.apply_place_ship(player_order: player_order, to: move.to, action_before: move.payload&.dig("action_before"))
    when "remove_ship"
      backend.apply_remove_ship(player_order: player_order, from: move.from, action_before: move.payload&.dig("action_before"))
    when "move_ship"
      backend.apply_move_ship(player_order: player_order, from: move.from, to: move.to, action_before: move.payload&.dig("action_before"), phase_after: move.payload&.dig("phase_after"))
    when "select_ship"
      backend.apply_select_ship(player_order: player_order, from: move.from)
    when "place_wagon"
      backend.apply_place_wagon(player_order: player_order, to: move.to, action_before: move.payload&.dig("action_before"))
    when "remove_wagon"
      backend.apply_remove_wagon(player_order: player_order, from: move.from, action_before: move.payload&.dig("action_before"))
    when "move_wagon"
      backend.apply_move_wagon(player_order: player_order, from: move.from, to: move.to, action_before: move.payload&.dig("action_before"), phase_after: move.payload&.dig("phase_after"))
    when "select_wagon"
      backend.apply_select_wagon(player_order: player_order, from: move.from)
    when "place_city_hall"
      backend.apply_place_city_hall(player_order: player_order, to: move.to, action_before: move.payload&.dig("action_before"))
    end
  end
end

class MoveApplicator::HashState
  attr_reader :board, :players, :deck, :discard, :mandatory_count, :current_action, :current_player_order

  def initialize(snapshot)
    @board = BoardState.load(snapshot["board_contents"])
    @players = snapshot["players"].to_h { |p| [ p["order"], p.except("order").deep_dup ] }
    @deck = snapshot["deck"].dup
    @discard = snapshot["discard"].dup
    @goals = snapshot["goals"]&.dup
    @boards = snapshot["boards"]
    @mandatory_count = snapshot["mandatory_count"]
    @current_action = snapshot["current_action"].deep_dup
    @current_player_order = snapshot["current_player_order"]
    @stone_walls = snapshot["stone_walls"]
    @turn_number = snapshot["turn_number"]
  end

  def apply_select_action(player_order:, type:, klass: nil, pending_orders: nil)
    tile_class = Tiles::Tile.for_klass(klass)
    tile = tile_class&.new(0)
    selected_phase =
      if tile&.builds_settlement? || tile&.places_wall?
        TurnPhase::TileBuildPhase.new(
          action_type: type,
          klass_name: klass,
          remaining: (3 if tile.is_a?(Tiles::Nomad::DonationTile)),
          walls_placed: (0 if tile.is_a?(Tiles::QuarryTile))
        )
      elsif tile&.places_meeple? && %w[ship wagon].include?(tile.meeple_kind)
        TurnPhase::MeepleMovementPhase.new(
          action_type: type,
          klass_name: klass
        )
      elsif tile&.places_meeple? && tile.meeple_kind == "warrior"
        TurnPhase::MeepleActionPhase.new(
          action_type: type,
          klass_name: klass
        )
      elsif tile&.sword_tile?
        TurnPhase::TargetedRemovalPhase.new(
          action_type: type,
          klass_name: klass,
          pending_orders: Array(pending_orders)
        )
      elsif tile&.moves_settlement? && !tile.is_a?(Tiles::Nomad::ResettlementTile)
        TurnPhase::SettlementMovePhase.new(
          action_type: type,
          klass_name: klass
        )
      elsif tile&.is_a?(Tiles::Nomad::ResettlementTile)
        TurnPhase::ResettlementPhase.new(
          budget: 4,
          vacated: [],
          moves: 0
        )
      else
        TurnPhase::LegacyPhase.new({ "type" => type, "klass" => klass }.compact)
      end
    @current_action = TurnPhase.deserialize(@current_action).transition(
      TurnPhase::Events::TileActionSelected.new,
      TurnPhase::Facts::TileActionSelection.new(selected_phase: selected_phase)
    ).next_phase.serialize
  end

  def apply_select_settlement(player_order:, from:)
    current_phase = TurnPhase.deserialize(@current_action)
    if current_phase.is_a?(TurnPhase::SettlementMovePhase) || current_phase.is_a?(TurnPhase::ResettlementPhase)
      @current_action = current_phase.transition(
        TurnPhase::Events::SourceSelected.new(coordinate_key: from),
        nil
      ).next_phase.serialize
    else
      @current_action = TurnPhase::LegacyPhase.new(@current_action.merge("from" => from)).serialize
    end
  end

  def apply_build(player_order:, to:, tile_klass:, remaining_before: nil, fort_terrain: nil, build_terrain: nil, chosen_terrain_before: :not_provided)
    coord = Coordinate.from_key(to)
    @board.place_settlement(coord.row, coord.col, player_order)
    @players[player_order]["supply"]["settlements"] -= 1
    if fort_terrain
      mark_tile_used(@players[player_order], tile_klass)
      @current_action = { "type" => "mandatory" }
    elsif tile_klass
      mark_tile_used(@players[player_order], tile_klass)
      remaining_after = remaining_before ? remaining_before - 1 : nil
      if remaining_after && remaining_after > 0
        current_phase = TurnPhase.deserialize(@current_action)
        @current_action = TurnPhase::TileBuildPhase.new(
          action_type: tile_klass.delete_suffix("Tile").downcase,
          klass_name: tile_klass,
          chosen_terrain: current_phase.respond_to?(:chosen_terrain) ? current_phase.chosen_terrain : nil,
          remaining: remaining_after
        ).serialize
      else
        @current_action = { "type" => "mandatory" }
      end
    else
      @mandatory_count -= 1
      @current_action = TurnPhase.deserialize(@current_action).transition(
        TurnPhase::Events::BuildChosen.new(coordinate: [ coord.row, coord.col ]),
        TurnPhase::Facts::BuildChoice.new(
          locked_terrain: build_terrain
        )
      ).next_phase.serialize
    end
  end

  def apply_pick_up_tile(player_order:, from:, klass:)
    coord = Coordinate.from_key(from)
    @board.decrement_tile(coord.row, coord.col)
    player = @players[player_order]
    player["tiles"] = (player["tiles"] || []) + [ { "klass" => klass, "from" => from, "used" => true } ]
    player["taken_from"] = (player["taken_from"] || []) + [ from ]
  end

  def apply_grant_meeple(player_order:, kind:, qty:)
    key = kind.pluralize
    @players[player_order]["supply"][key] = (@players[player_order]["supply"][key] || 0) + qty
  end

  def apply_forfeit_tile(player_order:, from:, klass:, used:)
    player = @players[player_order]
    player["tiles"] = (player["tiles"] || []).reject { |t| t["from"] == from }
  end

  def apply_end_turn(player_order:, card_discarded:, card_drawn:, reshuffled:, deck_after:)
    # Forfeit expired nomad tiles for current player (before incrementing, matching turn_engine ordering)
    player = @players[player_order]
    player["tiles"] = (player["tiles"] || []).reject { |t| t["expires_on_turn"] && t["expires_on_turn"] == (@turn_number || 0) }
    @turn_number = (@turn_number || 0) + 1
    next_order = (player_order + 1) % @players.size
    @discard.push(*Array(card_discarded))
    @players[player_order]["hand"] = card_drawn
    if reshuffled
      @deck = deck_after.dup
      @discard = []
    else
      @deck.shift
    end
    @mandatory_count = Game::MANDATORY_COUNT
    @current_action = { "type" => "mandatory" }
    @current_player_order = next_order
    next_player = @players[next_order]
    next_player["tiles"] = (next_player["tiles"] || []).map { |t| t["permanent"] ? t : t.merge("used" => false) }
  end

  def apply_score_goal(player_order:, goal:, score:)
    player = @players[player_order]
    player["bonus_scores"] ||= {}
    player["bonus_scores"][goal] = (player["bonus_scores"][goal] || 0) - score
  end

  def apply_remove_settlement(player_order:, from:, owner_order:, action_before: nil, tile_used: nil, meeple: nil)
    coord = Coordinate.from_key(from)
    @board.remove(coord.row, coord.col)
    key = meeple ? meeple.pluralize : "settlements"
    @players[owner_order]["supply"][key] += 1
  end

  def apply_place_wall(player_order:, to:, chosen_terrain_before: :not_provided)
    coord = Coordinate.from_key(to)
    @board.place_wall(coord.row, coord.col)
    @stone_walls = (@stone_walls || 0) - 1
  end

  def apply_activate_outpost(player_order:)
    mark_tile_used(@players[player_order], "OutpostTile")
    current_phase = TurnPhase.deserialize(@current_action)
    @current_action =
      if current_phase.is_a?(TurnPhase::MandatoryBuildPhase)
        TurnPhase::MandatoryBuildPhase.new(
          chosen_terrain: current_phase.chosen_terrain,
          builds: current_phase.builds,
          outpost_active: true
        ).serialize
      else
        TurnPhase::LegacyPhase.new(@current_action.merge("outpost_active" => true)).serialize
      end
  end

  def apply_activate_fort(player_order:)
    # No state change — tile is marked used on build, current_action updated by draw_fort_card
  end

  def apply_draw_fort_card(player_order:, drawn_card:, deck_after:, discard_after:)
    @deck = deck_after.dup
    @discard = discard_after.dup
    @current_action = TurnPhase::FortPhase.new(fort_terrain: drawn_card).serialize
  end

  def apply_move_settlement(player_order:, from:, to:, tile_klass:, action_before: nil, phase_after: nil, chosen_terrain_before: :not_provided)
    from_coord = Coordinate.from_key(from)
    to_coord = Coordinate.from_key(to)
    @board.move_settlement(from_coord.row, from_coord.col, to_coord.row, to_coord.col)
    if phase_after
      @current_action = phase_after.deep_dup
    else
      @current_action = TurnPhase.deserialize(@current_action).transition(
        TurnPhase::Events::DestinationChosen.new,
        TurnPhase::Facts::DestinationChoice.new(next_phase: TurnPhase::MandatoryBuildPhase.new)
      ).next_phase.serialize
    end
    mark_tile_used(@players[player_order], tile_klass) if TurnPhase.deserialize(@current_action).is_a?(TurnPhase::MandatoryBuildPhase)
  end

  private

  def mark_tile_used(player, klass)
    idx = player["tiles"]&.index { |t| t["klass"] == klass && t["used"] == false }
    return unless idx
    updated = player["tiles"].dup
    updated[idx] = updated[idx].merge("used" => true)
    player["tiles"] = updated
  end

  def mark_tile_permanently_used(player, klass)
    idx = player["tiles"]&.index { |t| t["klass"] == klass && t["used"] == false }
    return unless idx
    updated = player["tiles"].dup
    updated[idx] = updated[idx].merge("used" => true, "permanent" => true)
    player["tiles"] = updated
  end

  public

  def apply_place_warrior(player_order:, to:, action_before: nil)
    coord = Coordinate.from_key(to)
    @board.place_warrior(coord.row, coord.col, player_order)
    @players[player_order]["supply"]["warriors"] = (@players[player_order]["supply"]["warriors"] || 0) - 1
    mark_tile_used(@players[player_order], "BarracksTile")
    @current_action = { "type" => "mandatory" }
  end

  def apply_remove_warrior(player_order:, from:, action_before: nil)
    coord = Coordinate.from_key(from)
    @board.remove(coord.row, coord.col)
    @players[player_order]["supply"]["warriors"] = (@players[player_order]["supply"]["warriors"] || 0) + 1
    mark_tile_used(@players[player_order], "BarracksTile")
    @current_action = { "type" => "mandatory" }
  end

  def apply_place_ship(player_order:, to:, action_before: nil)
    coord = Coordinate.from_key(to)
    @board.place_ship(coord.row, coord.col, player_order)
    @players[player_order]["supply"]["ships"] = (@players[player_order]["supply"]["ships"] || 0) - 1
    mark_tile_used(@players[player_order], "LighthouseTile")
    @current_action = { "type" => "mandatory" }
  end

  def apply_remove_ship(player_order:, from:, action_before: nil)
    coord = Coordinate.from_key(from)
    @board.remove(coord.row, coord.col)
    @players[player_order]["supply"]["ships"] = (@players[player_order]["supply"]["ships"] || 0) + 1
    mark_tile_used(@players[player_order], "LighthouseTile")
    @current_action = { "type" => "mandatory" }
  end

  def apply_move_ship(player_order:, from:, to:, action_before: nil, phase_after: nil)
    from_coord = Coordinate.from_key(from)
    to_coord = Coordinate.from_key(to)
    @board.move_settlement(from_coord.row, from_coord.col, to_coord.row, to_coord.col)
    mark_tile_used(@players[player_order], "LighthouseTile")
    @current_action = phase_after ? phase_after.deep_dup : { "type" => "mandatory" }
  end

  def apply_select_ship(player_order:, from:)
    current_phase = TurnPhase.deserialize(@current_action)
    if current_phase.is_a?(TurnPhase::MeepleMovementPhase)
      @current_action = current_phase.transition(
        TurnPhase::Events::SourceSelected.new(coordinate_key: from),
        nil
      ).next_phase.serialize
    else
      @current_action = TurnPhase::LegacyPhase.new(@current_action.merge("from" => from)).serialize
    end
  end

  def apply_place_wagon(player_order:, to:, action_before: nil)
    coord = Coordinate.from_key(to)
    @board.place_wagon(coord.row, coord.col, player_order)
    @players[player_order]["supply"]["wagons"] = (@players[player_order]["supply"]["wagons"] || 0) - 1
    mark_tile_used(@players[player_order], "WagonTile")
    @current_action = { "type" => "mandatory" }
  end

  def apply_remove_wagon(player_order:, from:, action_before: nil)
    coord = Coordinate.from_key(from)
    @board.remove(coord.row, coord.col)
    @players[player_order]["supply"]["wagons"] = (@players[player_order]["supply"]["wagons"] || 0) + 1
    mark_tile_used(@players[player_order], "WagonTile")
    @current_action = { "type" => "mandatory" }
  end

  def apply_move_wagon(player_order:, from:, to:, action_before: nil, phase_after: nil)
    from_coord = Coordinate.from_key(from)
    to_coord = Coordinate.from_key(to)
    @board.move_settlement(from_coord.row, from_coord.col, to_coord.row, to_coord.col)
    mark_tile_used(@players[player_order], "WagonTile")
    @current_action = phase_after ? phase_after.deep_dup : { "type" => "mandatory" }
  end

  def apply_select_wagon(player_order:, from:)
    current_phase = TurnPhase.deserialize(@current_action)
    if current_phase.is_a?(TurnPhase::MeepleMovementPhase)
      @current_action = current_phase.transition(
        TurnPhase::Events::SourceSelected.new(coordinate_key: from),
        nil
      ).next_phase.serialize
    else
      @current_action = TurnPhase::LegacyPhase.new(@current_action.merge("from" => from)).serialize
    end
  end

  def apply_place_city_hall(player_order:, to:, action_before: nil)
    center = Coordinate.from_key(to)
    cluster = [ [ center.row, center.col ] ] + @board.neighbors(center.row, center.col)
    cluster.each { |r, c| @board.place_city_hall_hex(r, c, player_order) }
    @players[player_order]["supply"]["city_halls"] = (@players[player_order]["supply"]["city_halls"] || 0) - 1
    mark_tile_permanently_used(@players[player_order], "CityHallTile")
    @current_action = { "type" => "mandatory" }
  end

  public

  def result
    {
      "board_contents" => BoardState.dump(@board),
      "boards" => @boards,
      "deck" => @deck,
      "discard" => @discard,
      "goals" => @goals,
      "mandatory_count" => @mandatory_count,
      "current_action" => @current_action,
      "current_player_order" => @current_player_order,
      "stone_walls" => @stone_walls,
      "turn_number" => @turn_number,
      "players" => @players.map { |order, data| { "order" => order }.merge(data) }
    }
  end
end

class MoveApplicator::LiveState
  def initialize(game)
    @game = game
  end

  def apply_build(player_order:, to:, tile_klass:, remaining_before: nil, fort_terrain: nil, build_terrain: nil, chosen_terrain_before: :not_provided)
    coord = Coordinate.from_key(to)
    @game.board_contents_will_change!
    @game.board_contents.remove(coord.row, coord.col)
    gp = player_for(player_order)
    gp.increment_supply!
    @game.ending = false
    if fort_terrain
      gp.mark_tile_unused!(tile_klass)
      @game.current_action = { "type" => "fort", "klass" => "FortTile", "fort_terrain" => fort_terrain }
    elsif tile_klass
      gp.mark_tile_unused!(tile_klass)
      current_phase = @game.turn_phase
      tile_action_type = tile_klass.delete_suffix("Tile").downcase
      @game.turn_phase = TurnPhase::TileBuildPhase.new(
        action_type: tile_action_type,
        klass_name: tile_klass,
        chosen_terrain: current_phase.respond_to?(:chosen_terrain) ? current_phase.chosen_terrain : nil,
        remaining: remaining_before,
        walls_placed: current_phase.respond_to?(:walls_placed) ? current_phase.walls_placed : nil
      )
    else
      @game.mandatory_count += 1
      current_phase = @game.turn_phase
      @game.turn_phase = TurnPhase::MandatoryBuildPhase.new(
        chosen_terrain: (chosen_terrain_before == :not_provided ? nil : chosen_terrain_before),
        builds: current_phase.is_a?(TurnPhase::MandatoryBuildPhase) ? current_phase.builds[0..-2] : []
      )
    end
    restore_chosen_terrain(chosen_terrain_before)
    gp.save
  end

  def apply_pick_up_tile(player_order:, from:, klass:)
    coord = Coordinate.from_key(from)
    @game.board_contents_will_change!
    @game.board_contents.increment_tile(coord.row, coord.col)
    gp = player_for(player_order)
    gp.remove_tile_from!(from)
    gp.taken_from = (gp.taken_from || []) - [ from ]
    gp.save
  end

  def apply_grant_meeple(player_order:, kind:, qty:)
    gp = player_for(player_order)
    case kind
    when "warrior"   then gp.add_warriors!(-qty)
    when "ship"      then gp.add_ships!(-qty)
    when "wagon"     then gp.add_wagons!(-qty)
    when "city_hall" then gp.add_city_halls!(-qty)
    end
    gp.save
  end

  def apply_forfeit_tile(player_order:, from:, klass:, used:)
    gp = player_for(player_order)
    gp.restore_tile!(klass, from: from, used: used)
    gp.save
  end

  def apply_select_action(player_order:, type:, klass: nil, pending_orders: nil)
    @game.current_action = { "type" => "mandatory" }
    if klass
      gp = player_for(player_order)
      gp.mark_tile_unused!(klass.demodulize)
      gp.save
    end
  end

  def apply_select_settlement(player_order:, from:)
    current_phase = @game.turn_phase
    if current_phase.is_a?(TurnPhase::SettlementMovePhase)
      @game.turn_phase = TurnPhase::SettlementMovePhase.new(
        action_type: current_phase.type,
        klass_name: current_phase.klass_name
      )
    elsif current_phase.is_a?(TurnPhase::ResettlementPhase)
      @game.turn_phase = TurnPhase::ResettlementPhase.new(
        budget: current_phase.budget,
        vacated: current_phase.vacated,
        moves: current_phase.moves
      )
    else
      current_action = @game.current_action.dup
      current_action.delete("from")
      @game.turn_phase = TurnPhase::LegacyPhase.new(current_action)
    end
  end

  def apply_move_settlement(player_order:, from:, to:, tile_klass:, action_before: nil, phase_after: nil, chosen_terrain_before: :not_provided)
    @game.board_contents_will_change!
    @game.board_contents.move_settlement(*Coordinate.from_key(to), *Coordinate.from_key(from))
    @game.turn_phase = if action_before
      TurnPhase.deserialize(action_before)
    else
      TurnPhase::SettlementMovePhase.new(
        action_type: tile_klass.delete_suffix("Tile").downcase,
        klass_name: tile_klass,
        from: from
      )
    end
    restore_chosen_terrain(chosen_terrain_before)
    gp = player_for(player_order)
    gp.mark_tile_unused!(tile_klass)
    gp.save
  end

  def apply_score_goal(player_order:, goal:, score:)
    gp = player_for(player_order)
    gp.bonus_scores = (gp.bonus_scores || {}).merge(
      goal => (gp.bonus_scores&.dig(goal) || 0) - score
    )
    gp.save
  end

  def apply_remove_settlement(player_order:, from:, owner_order:, action_before: nil, tile_used: nil, meeple: nil)
    coord = Coordinate.from_key(from)
    @game.board_contents_will_change!
    @game.board_contents.restore_piece(meeple, coord.row, coord.col, owner_order)
    owner = player_for(owner_order)
    owner.remove_piece_from_supply!(meeple)
    owner.save
    if action_before
      @game.turn_phase = TurnPhase.deserialize(action_before)
    end
    if tile_used
      gp = player_for(player_order)
      gp.mark_tile_unused!(action_before&.dig("klass")&.demodulize || "SwordTile")
      gp.save
    end
  end

  def apply_place_wall(player_order:, to:, chosen_terrain_before: :not_provided)
    coord = Coordinate.from_key(to)
    @game.board_contents_will_change!
    @game.board_contents.remove(coord.row, coord.col)
    @game.stone_walls += 1
    restore_chosen_terrain(chosen_terrain_before)
    @game.save
  end

  def apply_activate_outpost(player_order:)
    gp = player_for(player_order)
    gp.mark_tile_unused!("OutpostTile")
    current_phase = @game.turn_phase
    if current_phase.is_a?(TurnPhase::MandatoryBuildPhase)
      @game.turn_phase = TurnPhase::MandatoryBuildPhase.new(
        chosen_terrain: current_phase.chosen_terrain,
        builds: current_phase.builds,
        outpost_active: false
      )
    else
      current_action = @game.current_action.dup
      current_action.delete("outpost_active")
      @game.turn_phase = TurnPhase::LegacyPhase.new(current_action)
    end
    gp.save
  end

  def apply_activate_fort(player_order:)
    # Non-reversible — never called during undo
  end

  def apply_draw_fort_card(player_order:, drawn_card:, deck_after:, discard_after:)
    # Non-reversible — never called during undo
  end

  def apply_place_warrior(player_order:, to:, action_before: nil)
    coord = Coordinate.from_key(to)
    @game.board_contents_will_change!
    @game.board_contents.remove(coord.row, coord.col)
    gp = player_for(player_order)
    gp.mark_tile_unused!("BarracksTile")
    gp.increment_warrior_supply!
    gp.save
    @game.turn_phase = TurnPhase.deserialize(action_before) if action_before
  end

  def apply_remove_warrior(player_order:, from:, action_before: nil)
    coord = Coordinate.from_key(from)
    @game.board_contents_will_change!
    @game.board_contents.place_warrior(coord.row, coord.col, player_order)
    gp = player_for(player_order)
    gp.mark_tile_unused!("BarracksTile")
    gp.decrement_warrior_supply!
    gp.save
    @game.turn_phase = TurnPhase.deserialize(action_before) if action_before
  end

  def apply_place_ship(player_order:, to:, action_before: nil)
    coord = Coordinate.from_key(to)
    @game.board_contents_will_change!
    @game.board_contents.remove(coord.row, coord.col)
    gp = player_for(player_order)
    gp.mark_tile_unused!("LighthouseTile")
    gp.increment_ship_supply!
    gp.save
    @game.turn_phase = TurnPhase.deserialize(action_before) if action_before
  end

  def apply_remove_ship(player_order:, from:, action_before: nil)
    coord = Coordinate.from_key(from)
    @game.board_contents_will_change!
    @game.board_contents.place_ship(coord.row, coord.col, player_order)
    gp = player_for(player_order)
    gp.mark_tile_unused!("LighthouseTile")
    gp.decrement_ship_supply!
    gp.save
    @game.turn_phase = TurnPhase.deserialize(action_before) if action_before
  end

  def apply_move_ship(player_order:, from:, to:, action_before: nil, phase_after: nil)
    to_coord = Coordinate.from_key(to)
    from_coord = Coordinate.from_key(from)
    @game.board_contents_will_change!
    @game.board_contents.move_settlement(to_coord.row, to_coord.col, from_coord.row, from_coord.col)
    gp = player_for(player_order)
    gp.mark_tile_unused!("LighthouseTile")
    gp.save
    @game.turn_phase = TurnPhase.deserialize(action_before) if action_before
  end

  def apply_select_ship(player_order:, from:)
    current_phase = @game.turn_phase
    if current_phase.is_a?(TurnPhase::MeepleMovementPhase)
      @game.turn_phase = TurnPhase::MeepleMovementPhase.new(
        action_type: current_phase.type,
        klass_name: current_phase.klass_name
      )
    else
      current_action = @game.current_action.dup
      current_action.delete("from")
      @game.turn_phase = TurnPhase::LegacyPhase.new(current_action)
    end
  end

  def apply_place_wagon(player_order:, to:, action_before: nil)
    coord = Coordinate.from_key(to)
    @game.board_contents_will_change!
    @game.board_contents.remove(coord.row, coord.col)
    gp = player_for(player_order)
    gp.mark_tile_unused!("WagonTile")
    gp.increment_wagon_supply!
    gp.save
    @game.turn_phase = TurnPhase.deserialize(action_before) if action_before
  end

  def apply_remove_wagon(player_order:, from:, action_before: nil)
    coord = Coordinate.from_key(from)
    @game.board_contents_will_change!
    @game.board_contents.place_wagon(coord.row, coord.col, player_order)
    gp = player_for(player_order)
    gp.mark_tile_unused!("WagonTile")
    gp.decrement_wagon_supply!
    gp.save
    @game.turn_phase = TurnPhase.deserialize(action_before) if action_before
  end

  def apply_move_wagon(player_order:, from:, to:, action_before: nil, phase_after: nil)
    to_coord = Coordinate.from_key(to)
    from_coord = Coordinate.from_key(from)
    @game.board_contents_will_change!
    @game.board_contents.move_settlement(to_coord.row, to_coord.col, from_coord.row, from_coord.col)
    gp = player_for(player_order)
    gp.mark_tile_unused!("WagonTile")
    gp.save
    @game.turn_phase = TurnPhase.deserialize(action_before) if action_before
  end

  def apply_select_wagon(player_order:, from:)
    current_phase = @game.turn_phase
    if current_phase.is_a?(TurnPhase::MeepleMovementPhase)
      @game.turn_phase = TurnPhase::MeepleMovementPhase.new(
        action_type: current_phase.type,
        klass_name: current_phase.klass_name
      )
    else
      current_action = @game.current_action.dup
      current_action.delete("from")
      @game.turn_phase = TurnPhase::LegacyPhase.new(current_action)
    end
  end

  def apply_place_city_hall(player_order:, to:, action_before: nil)
    center = Coordinate.from_key(to)
    cluster = [ [ center.row, center.col ] ] + @game.board_contents.neighbors(center.row, center.col)
    @game.board_contents_will_change!
    cluster.each { |r, c| @game.board_contents.remove(r, c) }
    gp = player_for(player_order)
    gp.increment_city_hall_supply!
    gp.mark_tile_unpermanent!("CityHallTile")
    @game.turn_phase = TurnPhase.deserialize(action_before) if action_before
    gp.save
  end

  private

  def player_for(order)
    @game.game_players.find { |gp| gp.order == order }
  end

  def restore_chosen_terrain(chosen_terrain_before)
    return if chosen_terrain_before == :not_provided
    current_phase = @game.turn_phase
    if current_phase.is_a?(TurnPhase::MandatoryBuildPhase)
      @game.turn_phase = TurnPhase::MandatoryBuildPhase.new(
        chosen_terrain: chosen_terrain_before,
        builds: current_phase.builds,
        outpost_active: current_phase.outpost_active?
      )
    else
      current_action = @game.current_action.dup
      if chosen_terrain_before.nil?
        current_action.delete("chosen_terrain")
      else
        current_action["chosen_terrain"] = chosen_terrain_before
      end
      @game.turn_phase = TurnPhase::LegacyPhase.new(current_action)
    end
  end
end
