class Turn
  module SubPhases
    class ResettlementPhase < Turn::SubPhase
      TYPE = "resettlement".freeze
      TILE_KLASS = "ResettlementTile".freeze
      STARTING_BUDGET = 4

      attr_reader :budget, :vacated, :moves, :source

      def initialize(budget: STARTING_BUDGET, vacated: [], moves: 0, source: nil)
        super()
        @budget = budget.to_i
        @vacated = Array(vacated)
        @moves = moves.to_i
        @source = source
        @complete = false
      end

      def to_h
        {
          "budget" => budget,
          "vacated" => vacated,
          "moves" => moves,
          "source" => source&.to_key
        }
      end

      def self.from_h(hash)
        source_key = hash["source"] || hash["from"]
        new(
          budget: hash.fetch("budget", STARTING_BUDGET),
          vacated: Array(hash["vacated"]),
          moves: hash.fetch("moves", 0),
          source: source_key ? Coordinate.from_key(source_key) : nil
        )
      end

      def handle(action_name, game:, player_order:, **params)
        case action_name
        when :select_settlement
          handle_select(game:, player_order:, row: params[:row], col: params[:col])
        when :move_settlement
          handle_move(game:, player_order:, row: params[:row], col: params[:col])
        when :end_tile_action
          handle_end_tile_action(player_order:)
        else
          [ error("unsupported action: #{action_name}") ]
        end
      end

      private

      def handle_select(game:, player_order:, row:, col:)
        return error("source already selected") if source
        return error("no movement budget remaining") if budget <= 0
        return error("not a selectable settlement") unless tile.selectable_settlements(
          player_order: player_order,
          board_contents: game.board_contents,
          board: game.board,
          budget: budget,
          vacated: vacated
        ).include?([ row, col ])

        prior = to_h
        @source = Coordinate.new(row, col)
        [ Turn::Consequences::SubPhaseStateUpdated.new(prior_state: prior, new_state: to_h) ]
      end

      def handle_move(game:, player_order:, row:, col:)
        return error("no source selected") unless source

        cost = tile.move_cost(
          from_row: source.row,
          from_col: source.col,
          to_row: row,
          to_col: col,
          board_contents: game.board_contents,
          board: game.board,
          player_order: player_order,
          budget: budget,
          vacated: vacated
        )
        return error("not a valid destination") unless cost

        destination = Coordinate.new(row, col)
        consequences = [
          Turn::Consequences::SettlementMoved.new(from: source, to: destination, player: player_order),
          *tile_forfeits(game, player_order, destination),
          *tile_pickup(game, player_order, destination)
        ]

        remaining_budget = budget - cost
        if remaining_budget <= 0
          @complete = true
          consequences << Turn::Consequences::TileConsumed.new(klass: TILE_KLASS, player: player_order)
        else
          prior = to_h
          @budget = remaining_budget
          @vacated = vacated + [ source.to_key ]
          @moves = moves + 1
          @source = nil
          consequences << Turn::Consequences::SubPhaseStateUpdated.new(prior_state: prior, new_state: to_h)
        end

        consequences
      end

      def handle_end_tile_action(player_order:)
        return error("cannot end Resettlement before moving") if moves <= 0

        @complete = true
        [ Turn::Consequences::TileConsumed.new(klass: TILE_KLASS, player: player_order) ]
      end

      def tile_forfeits(game, player_order, destination)
        gp = player_for(game, player_order)
        settlement_positions = settlements_after_move(game, player_order, destination)

        Array(gp&.tiles).filter_map do |held_tile|
          next if Tiles::Tile.for_klass(held_tile["klass"])&.new(0)&.nomad_tile?
          from_key = held_tile["from"]
          next unless from_key
          from = Coordinate.from_key(from_key)
          next unless game.board_contents.tile_klass(from.row, from.col)

          still_adjacent = settlement_positions.any? do |r, c|
            game.board_contents.neighbors(r, c).any? { |nr, nc| Coordinate.new(nr, nc).to_key == from_key }
          end
          next if still_adjacent

          Turn::Consequences::TileDiscarded.new(
            player: player_order,
            klass: held_tile["klass"],
            from: from_key,
            used: held_tile["used"]
          )
        end
      end

      def tile_pickup(game, player_order, destination)
        gp = player_for(game, player_order)
        pickup = pickup_target(game, gp, destination)
        return [] unless pickup

        consequences = [
          Turn::Consequences::TilePickedUp.new(from: pickup[:from], klass: pickup[:klass], player: player_order)
        ]
        consequences.concat(meeple_grant_for(pickup[:klass], player_order))
        consequences.concat(immediate_score_for(pickup[:klass], pickup[:from], game, gp, player_order))
        consequences.concat(nomad_expiry_for(pickup[:klass], pickup[:from], game, gp, player_order))
        consequences
      end

      def pickup_target(game, gp, destination)
        held_locations = gp.held_tile_locations
        taken_from = gp.taken_from || []
        game.board_contents.neighbors(destination.row, destination.col).each do |row, col|
          klass = game.board_contents.tile_klass(row, col)
          next unless klass && game.board_contents.tile_qty(row, col) > 0
          key = Coordinate.new(row, col).to_key
          next if held_locations.include?(key)
          next if taken_from.include?(key)
          return { from: Coordinate.new(row, col), klass: klass }
        end
        nil
      end

      def meeple_grant_for(klass, player_order)
        grant = Tiles::Tile.for_klass(klass)&.new(0)&.meeple_grant
        return [] unless grant
        [ Turn::Consequences::MeepleGranted.new(player: player_order, kind: grant["kind"], qty: grant["qty"]) ]
      end

      def immediate_score_for(klass, from, _game, gp, player_order)
        score = Tiles::Tile.for_klass(klass)&.new(0)&.immediate_score
        return [] unless score
        prior = gp.bonus_scores&.dig(score["goal"]) || 0
        [
          Turn::Consequences::GoalScored.new(player: player_order, goal: score["goal"], points: score["points"], prior_score: prior),
          Turn::Consequences::TileDiscarded.new(player: player_order, klass: klass, from: from.to_key, used: true)
        ]
      end

      def nomad_expiry_for(klass, from, game, gp, player_order)
        tile_obj = Tiles::Tile.for_klass(klass)&.new(0)
        return [] unless tile_obj&.nomad_tile?
        return [] if tile_obj.immediate_score

        prior = Array(gp.tiles).find { |t| t["klass"] == klass && t["from"] == from.to_key }&.dig("expires_on_turn")
        [
          Turn::Consequences::NomadTileExpirySet.new(
            player: player_order,
            klass: klass,
            from: from.to_key,
            expires_on_turn: game.turn_number + game.game_players.count,
            prior_expires_on_turn: prior
          )
        ]
      end

      def settlements_after_move(game, player_order, destination)
        game.board_contents.settlements_for(player_order).map do |row, col|
          row == source.row && col == source.col ? [ destination.row, destination.col ] : [ row, col ]
        end
      end

      def player_for(game, player_order)
        game.game_players.find { |gp| gp.order == player_order }
      end

      def tile
        Tiles::Nomad::ResettlementTile.new(0)
      end

      def error(msg)
        [ Turn::Consequences::Error.new(message: msg) ]
      end
    end
  end
end
