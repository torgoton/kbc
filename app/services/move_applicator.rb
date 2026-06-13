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
      backend.apply_build(player_order: player_order, to: move.to, tile_klass: move.payload&.dig("tile_klass"), remaining_before: move.payload&.dig("remaining_before"), fort_terrain: fort_terrain, build_terrain: move.payload&.dig("card"), chosen_terrain_before: ct_before, triggered_ending: move.payload&.dig("triggered_ending"), action_before: move.payload&.dig("action_before"))
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
    when "redistribute_tile_used"
      backend.apply_redistribute_tile_used(
        player_order: player_order,
        changes: move.payload["changes"]
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

class MoveApplicator::LiveState
  def initialize(game)
    @game = game
  end

  def apply_build(player_order:, to:, tile_klass:, remaining_before: nil, fort_terrain: nil, build_terrain: nil, chosen_terrain_before: :not_provided, triggered_ending: nil, action_before: nil)
    coord = Coordinate.from_key(to)
    @game.board_contents_will_change!
    @game.board_contents.remove(coord.row, coord.col)
    gp = player_for(player_order)
    gp.increment_supply!
    @game.end_trigger_count -= 1 if triggered_ending
    if fort_terrain
      gp.mark_tile_unused!(tile_klass)
      @game.current_action = { "type" => "fort", "klass" => "FortTile", "fort_terrain" => fort_terrain }
    elsif tile_klass
      gp.mark_tile_unused!(tile_klass)
      if action_before
        @game.turn_phase = TurnPhase.deserialize(action_before)
      else
        current_phase = @game.turn_phase
        tile_action_type = tile_klass.delete_suffix("Tile").downcase
        @game.turn_phase = TurnPhase::TileBuildPhase.new(
          action_type: tile_action_type,
          klass_name: tile_klass,
          chosen_terrain: current_phase.respond_to?(:chosen_terrain) ? current_phase.chosen_terrain : nil,
          remaining: remaining_before,
          walls_placed: current_phase.respond_to?(:walls_placed) ? current_phase.walls_placed : nil
        )
      end
    else
      @game.mandatory_count += 1
      if action_before
        @game.turn_phase = TurnPhase.deserialize(action_before)
      else
        current_phase = @game.turn_phase
        @game.turn_phase = TurnPhase::MandatoryBuildPhase.new(
          chosen_terrain: (chosen_terrain_before == :not_provided ? nil : chosen_terrain_before),
          builds: current_phase.is_a?(TurnPhase::MandatoryBuildPhase) ? current_phase.builds[0..-2] : []
        )
      end
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

  # Undo (reverse): restore every reassigned `used` flag to its prior value.
  # Runs after the forfeit_tile reversal, so the just-restored forfeited tile is
  # present and corrected here too.
  def apply_redistribute_tile_used(player_order:, changes:)
    gp = player_for(player_order)
    tiles = gp.tiles || []
    changes.each do |change|
      tile = tiles.find { |t| t["from"] == change["from"] }
      tile["used"] = change["before"] if tile
    end
    gp.tiles = tiles
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
      phase = TurnPhase.deserialize(action_before)
      if phase.is_a?(TurnPhase::ResettlementPhase)
        phase
      else
        TurnPhase::SettlementMovePhase.new(
          action_type: tile_klass.delete_suffix("Tile").downcase,
          klass_name: tile_klass,
          from: from
        )
      end
    elsif phase_after
      TurnPhase.deserialize(phase_after)
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
    elsif current_phase.is_a?(TurnPhase::TileBuildPhase)
      @game.turn_phase = TurnPhase::TileBuildPhase.new(
        action_type: current_phase.type,
        klass_name: current_phase.klass_name,
        chosen_terrain: current_phase.chosen_terrain,
        remaining: current_phase.remaining,
        walls_placed: current_phase.walls_placed,
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
        klass_name: current_phase.klass_name,
        budget: current_phase.budget,
        moves: current_phase.moves
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
        klass_name: current_phase.klass_name,
        budget: current_phase.budget,
        moves: current_phase.moves
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
    elsif current_phase.respond_to?(:chosen_terrain)
      phase_class =
        if current_phase.is_a?(TurnPhase::TileBuildPhase)
          TurnPhase::TileBuildPhase
        elsif current_phase.is_a?(TurnPhase::SettlementMovePhase)
          TurnPhase::SettlementMovePhase
        elsif current_phase.is_a?(TurnPhase::ResettlementPhase)
          TurnPhase::ResettlementPhase
        elsif current_phase.is_a?(TurnPhase::LegacyPhase)
          TurnPhase::LegacyPhase
        else
          current_phase.class
        end

      @game.turn_phase =
        case phase_class.name
        when "TurnPhase::TileBuildPhase"
          TurnPhase::TileBuildPhase.new(
            action_type: current_phase.type,
            klass_name: current_phase.klass_name,
            chosen_terrain: chosen_terrain_before,
            remaining: current_phase.respond_to?(:remaining) ? current_phase.remaining : nil,
            walls_placed: current_phase.respond_to?(:walls_placed) ? current_phase.walls_placed : nil,
            outpost_active: current_phase.respond_to?(:outpost_active?) && current_phase.outpost_active?
          )
        when "TurnPhase::SettlementMovePhase"
          TurnPhase::SettlementMovePhase.new(
            action_type: current_phase.type,
            klass_name: current_phase.klass_name,
            from: current_phase.from
          )
        when "TurnPhase::ResettlementPhase"
          TurnPhase::ResettlementPhase.new(
            budget: current_phase.budget,
            vacated: current_phase.vacated,
            moves: current_phase.moves,
            from: current_phase.from
          )
        when "TurnPhase::LegacyPhase"
          current_action = current_phase.serialize
          current_action = current_action.deep_dup
          if chosen_terrain_before.nil?
            current_action.delete("chosen_terrain")
          else
            current_action["chosen_terrain"] = chosen_terrain_before
          end
          TurnPhase::LegacyPhase.new(current_action)
        else
          current_phase
        end
    end
  end
end
