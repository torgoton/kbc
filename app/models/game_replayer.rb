class GameReplayer
  def initialize(game)
    snap = game.base_snapshot
    @board = BoardState.load(snap["board_contents"])
    @boards = snap["boards"]
    @deck = snap["deck"].dup
    @discard = snap["discard"].dup
    @goals = snap["goals"]&.dup
    @mandatory_count = snap["mandatory_count"]
    @current_action = snap["current_action"].deep_dup
    @current_player_order = snap["current_player_order"]
    @players = snap["players"].to_h { |p| [ p["order"], p.except("order").deep_dup ] }
    @moves = game.moves
  end

  def replay
    @moves.order(:order).each { |move| apply(move) }
    result
  end

  private

  def apply(move)
    order = move.game_player.order
    player = @players[order]

    case move.action
    when "build"
      to = Coordinate.from_key(move.to)
      @board.place_settlement(to.row, to.col, order)
      player["supply"]["settlements"] -= 1
      tile_klass = move.payload&.dig("tile_klass")
      if tile_klass
        @current_action = { "type" => "mandatory" }
        mark_tile_used(player, tile_klass)
      else
        @mandatory_count -= 1
      end

    when "end_turn"
      @discard.push(move.payload["card_discarded"])
      player["hand"] = move.payload["card_drawn"]
      if move.payload["reshuffled"]
        @deck = move.payload["deck_after"].dup
        @discard = []
      else
        @deck.shift
      end
      @mandatory_count = Game::MANDATORY_COUNT
      @current_action = { "type" => "mandatory" }
      next_order = (order + 1) % @players.size
      @current_player_order = next_order
      next_player = @players[next_order]
      next_player["tiles"] = (next_player["tiles"] || []).map { |t| t.merge("used" => false) }

    when "pick_up_tile"
      coord = Coordinate.from_key(move.from)
      @board.decrement_tile(coord.row, coord.col)
      klass = move.payload["klass"]
      player["tiles"] = (player["tiles"] || []) + [ { "klass" => klass, "from" => move.from, "used" => true } ]

    when "forfeit_tile"
      player["tiles"] = (player["tiles"] || []).reject { |t| t["from"] == move.from }

    when "select_action"
      @current_action = { "type" => move.to }

    when "select_settlement"
      @current_action = @current_action.merge("from" => move.from)

    when "move_settlement"
      from = Coordinate.from_key(move.from)
      to = Coordinate.from_key(move.to)
      @board.move_settlement(from.row, from.col, to.row, to.col)
      @current_action = { "type" => "mandatory" }
      mark_tile_used(player, "PaddockTile")
    end
  end

  def mark_tile_used(player, klass)
    idx = player["tiles"]&.index { |t| t["klass"] == klass && t["used"] == false }
    return unless idx
    updated = player["tiles"].dup
    updated[idx] = updated[idx].merge("used" => true)
    player["tiles"] = updated
  end

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
      "players" => @players.map { |order, data| { "order" => order }.merge(data) }
    }
  end
end
