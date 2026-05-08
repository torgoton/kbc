class Turn
  module SubPhases
    # Multi-click sub-phase for any tile that moves an existing settlement
    # (Paddock, Wagon move, Ship move). Click 1 (already done = activation
    # via SubPhasePushed) leaves source: nil. Click 2 selects the source.
    # Click 3 chooses the destination, validated via tile.valid_destinations.
    class SettlementMovePhase < Turn::SubPhase
      TYPE = "settlement_move".freeze

      attr_reader :tile_klass, :source

      def initialize(tile_klass:, source: nil)
        super()
        @tile_klass = tile_klass
        @source = source
        @complete = false
      end

      def to_h
        { "tile_klass" => tile_klass, "source" => source&.to_key }
      end

      def self.from_h(hash)
        source_key = hash["source"]
        new(
          tile_klass: hash["tile_klass"],
          source: source_key ? Coordinate.from_key(source_key) : nil
        )
      end

      def handle(action_name, game:, player_order:, **params)
        case action_name
        when :select_settlement
          handle_select(game:, player_order:, row: params[:row], col: params[:col])
        when :move_settlement
          handle_move(game:, player_order:, row: params[:row], col: params[:col])
        else
          [ Turn::Consequences::Error.new(message: "unsupported action: #{action_name}") ]
        end
      end

      private

      def handle_select(game:, player_order:, row:, col:)
        return error("source already selected") if source

        klass = tile_class
        return error("unknown tile #{tile_klass}") unless klass
        return error("not a selectable settlement") unless selectable_settlements(klass, game, player_order).include?([ row, col ])

        prior = to_h
        @source = Coordinate.new(row, col)
        [ Turn::Consequences::SubPhaseStateUpdated.new(prior_state: prior, new_state: to_h) ]
      end

      def handle_move(game:, player_order:, row:, col:)
        return error("no source selected") unless source

        klass = tile_class
        return error("unknown tile #{tile_klass}") unless klass
        valid = klass.new(0).valid_destinations(
          from_row: source.row, from_col: source.col,
          board_contents: game.board_contents, board: game.board,
          player_order: player_order,
          hand: game.game_players.find { |gp| gp.order == player_order }&.hand&.first
        )
        return error("not a valid destination") unless valid.include?([ row, col ])

        @complete = true
        [
          Turn::Consequences::SettlementMoved.new(from: source, to: Coordinate.new(row, col), player: player_order),
          Turn::Consequences::TileConsumed.new(klass: tile_klass, player: player_order)
        ]
      end

      def error(msg)
        [ Turn::Consequences::Error.new(message: msg) ]
      end

      def tile_class
        Tiles::Tile.for_klass(tile_klass)
      end

      def selectable_settlements(klass, game, player_order)
        klass.new(0).selectable_settlements(
          player_order: player_order,
          board_contents: game.board_contents,
          board: game.board,
          hand: player_for(game, player_order)&.hand&.first
        )
      end

      def player_for(game, player_order)
        game.game_players.find { |gp| gp.order == player_order }
      end
    end
  end
end
