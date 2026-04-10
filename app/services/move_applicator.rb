module MoveApplicator
  def self.dispatch(backend, move)
    player_order = move.game_player.order
    case move.action
    when "select_action"
      backend.apply_select_action(player_order: player_order, type: move.to, klass: move.payload&.dig("klass"))
    when "select_settlement"
      backend.apply_select_settlement(player_order: player_order, from: move.from)
    when "move_settlement"
      backend.apply_move_settlement(player_order: player_order, from: move.from, to: move.to, tile_klass: move.payload&.dig("tile_klass"))
    when "build"
      backend.apply_build(player_order: player_order, to: move.to, tile_klass: move.payload&.dig("tile_klass"))
    when "pick_up_tile"
      backend.apply_pick_up_tile(player_order: player_order, from: move.from, klass: move.payload["klass"])
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
        owner_order: move.payload["owner_order"]
      )
    when "place_wall"
      backend.apply_place_wall(player_order: player_order, to: move.to)
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

  def apply_select_action(player_order:, type:, klass: nil)
    @current_action = { "type" => type }
    @current_action["klass"] = klass if klass
  end

  def apply_select_settlement(player_order:, from:)
    @current_action = @current_action.merge("from" => from)
  end

  def apply_build(player_order:, to:, tile_klass:)
    coord = Coordinate.from_key(to)
    @board.place_settlement(coord.row, coord.col, player_order)
    @players[player_order]["supply"]["settlements"] -= 1
    if tile_klass
      mark_tile_used(@players[player_order], tile_klass)
      @current_action = { "type" => "mandatory" }
    else
      @mandatory_count -= 1
      @current_action = @current_action.merge(
        "builds" => (@current_action["builds"] || []) + [ [ coord.row, coord.col ] ]
      )
    end
  end

  def apply_pick_up_tile(player_order:, from:, klass:)
    coord = Coordinate.from_key(from)
    @board.decrement_tile(coord.row, coord.col)
    player = @players[player_order]
    player["tiles"] = (player["tiles"] || []) + [ { "klass" => klass, "from" => from, "used" => true } ]
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
    @discard.push(card_discarded)
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
    next_player["tiles"] = (next_player["tiles"] || []).map { |t| t.merge("used" => false) }
  end

  def apply_score_goal(player_order:, goal:, score:)
    player = @players[player_order]
    player["bonus_scores"] ||= {}
    player["bonus_scores"][goal] = (player["bonus_scores"][goal] || 0) - score
  end

  def apply_remove_settlement(player_order:, from:, owner_order:)
    coord = Coordinate.from_key(from)
    @board.remove(coord.row, coord.col)
    @players[owner_order]["supply"]["settlements"] += 1
  end

  def apply_place_wall(player_order:, to:)
    coord = Coordinate.from_key(to)
    @board.place_wall(coord.row, coord.col)
    @stone_walls = (@stone_walls || 0) - 1
  end

  def apply_move_settlement(player_order:, from:, to:, tile_klass:)
    from_coord = Coordinate.from_key(from)
    to_coord = Coordinate.from_key(to)
    @board.move_settlement(from_coord.row, from_coord.col, to_coord.row, to_coord.col)
    @current_action = { "type" => "mandatory" }
    mark_tile_used(@players[player_order], tile_klass)
  end

  private

  def mark_tile_used(player, klass)
    idx = player["tiles"]&.index { |t| t["klass"] == klass && t["used"] == false }
    return unless idx
    updated = player["tiles"].dup
    updated[idx] = updated[idx].merge("used" => true)
    player["tiles"] = updated
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

  def apply_build(player_order:, to:, tile_klass:)
    coord = Coordinate.from_key(to)
    @game.board_contents_will_change!
    @game.board_contents.remove(coord.row, coord.col)
    gp = player_for(player_order)
    gp.increment_supply!
    @game.ending = false
    if tile_klass
      gp.mark_tile_unused!(tile_klass)
      @game.current_action = { "type" => tile_klass.delete_suffix("Tile").downcase }
    else
      @game.mandatory_count += 1
      builds = (@game.current_action["builds"] || [])[0..-2]
      @game.current_action_will_change!
      @game.current_action["builds"] = builds
    end
    gp.save
  end

  def apply_pick_up_tile(player_order:, from:, klass:)
    coord = Coordinate.from_key(from)
    @game.board_contents_will_change!
    @game.board_contents.increment_tile(coord.row, coord.col)
    player_for(player_order).remove_tile_from!(from)
    player_for(player_order).save
  end

  def apply_forfeit_tile(player_order:, from:, klass:, used:)
    gp = player_for(player_order)
    gp.restore_tile!(klass, from: from, used: used)
    gp.save
  end

  def apply_select_action(player_order:, type:, klass: nil)
    @game.current_action = { "type" => "mandatory" }
  end

  def apply_select_settlement(player_order:, from:)
    @game.current_action_will_change!
    @game.current_action.delete("from")
  end

  def apply_move_settlement(player_order:, from:, to:, tile_klass:)
    @game.board_contents_will_change!
    @game.board_contents.move_settlement(*Coordinate.from_key(to), *Coordinate.from_key(from))
    @game.current_action = { "type" => tile_klass.delete_suffix("Tile").downcase, "from" => from }
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

  def apply_remove_settlement(player_order:, from:, owner_order:)
    coord = Coordinate.from_key(from)
    @game.board_contents_will_change!
    @game.board_contents.place_settlement(coord.row, coord.col, owner_order)
    owner = player_for(owner_order)
    owner.decrement_supply!
    owner.save
  end

  def apply_place_wall(player_order:, to:)
    coord = Coordinate.from_key(to)
    @game.board_contents_will_change!
    @game.board_contents.remove(coord.row, coord.col)
    @game.stone_walls += 1
    @game.save
  end

  private

  def player_for(order)
    @game.game_players.find { |gp| gp.order == order }
  end
end
