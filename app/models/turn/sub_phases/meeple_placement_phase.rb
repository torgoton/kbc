class Turn
  module SubPhases
    # Sub-phase for meeple-action tiles (Barracks, Lighthouse, Wagon).
    # Dispatches by what's at the clicked hex and the tile's capabilities:
    #   empty target, no source         → place (MeeplePlaced)
    #   empty target, source set        → move  (SettlementMoved)
    #   own meeple of `kind`, !movable  → remove (MeepleRemoved)
    #   own meeple of `kind`, movable, no source → set source (SubPhaseStateUpdated)
    class MeeplePlacementPhase < Turn::SubPhase
      TYPE = "meeple_placement".freeze

      attr_reader :tile_klass, :kind, :source

      def initialize(tile_klass:, kind:, source: nil)
        super()
        @tile_klass = tile_klass
        @kind = kind
        @source = source
        @complete = false
      end

      def to_h
        { "tile_klass" => tile_klass, "kind" => kind, "source" => source&.to_key }
      end

      def self.from_h(hash)
        source_key = hash["source"]
        new(
          tile_klass: hash["tile_klass"],
          kind: hash["kind"],
          source: source_key ? Coordinate.from_key(source_key) : nil
        )
      end

      def handle(action_name, game:, player_order:, **params)
        case action_name
        when :place_meeple
          handle_action(game:, player_order:, row: params[:row], col: params[:col])
        else
          [ Turn::Consequences::Error.new(message: "unsupported action: #{action_name}") ]
        end
      end

      private

      def handle_action(game:, player_order:, row:, col:)
        klass = Tiles::Tile.for_klass(tile_klass)
        return error("unknown tile #{tile_klass}") unless klass
        instance = klass.new(0)

        if game.board_contents.empty?(row, col)
          source ? handle_move(instance:, game:, player_order:, row:, col:) : handle_place(instance:, game:, player_order:, row:, col:)
        else
          handle_click_on_occupied(instance:, game:, player_order:, row:, col:)
        end
      end

      def handle_place(instance:, game:, player_order:, row:, col:)
        valid = instance.valid_destinations(
          board_contents: game.board_contents, board: game.board,
          player_order: player_order, supply: supply_hash_for(game, player_order)
        )
        return error("not a valid placement hex") unless valid.include?([ row, col ])

        @complete = true
        [
          Turn::Consequences::MeeplePlaced.new(at: Coordinate.new(row, col), kind: kind, player: player_order),
          Turn::Consequences::TileConsumed.new(klass: tile_klass, player: player_order)
        ]
      end

      def handle_move(instance:, game:, player_order:, row:, col:)
        valid = instance.valid_destinations(
          from_row: source.row, from_col: source.col,
          board_contents: game.board_contents, board: game.board,
          player_order: player_order, supply: supply_hash_for(game, player_order)
        )
        return error("not a valid destination") unless valid.include?([ row, col ])

        @complete = true
        [
          Turn::Consequences::SettlementMoved.new(from: source, to: Coordinate.new(row, col), player: player_order),
          Turn::Consequences::TileConsumed.new(klass: tile_klass, player: player_order)
        ]
      end

      def handle_click_on_occupied(instance:, game:, player_order:, row:, col:)
        return error("not your meeple") unless game.board_contents.player_at(row, col) == player_order
        return error("not a #{kind}") unless game.board_contents.meeple_at(row, col) == kind

        if instance.meeple_movable?
          handle_set_source(row: row, col: col)
        else
          handle_remove(player_order:, row:, col:)
        end
      end

      def handle_set_source(row:, col:)
        return error("source already selected") if source
        prior = to_h
        @source = Coordinate.new(row, col)
        [ Turn::Consequences::SubPhaseStateUpdated.new(prior_state: prior, new_state: to_h) ]
      end

      def handle_remove(player_order:, row:, col:)
        @complete = true
        [
          Turn::Consequences::MeepleRemoved.new(at: Coordinate.new(row, col), kind: kind, player: player_order),
          Turn::Consequences::TileConsumed.new(klass: tile_klass, player: player_order)
        ]
      end

      def supply_hash_for(game, player_order)
        gp = game.game_players.find { |g| g.order == player_order }
        gp&.supply_hash || Hash.new(0)
      end

      def error(msg)
        [ Turn::Consequences::Error.new(message: msg) ]
      end
    end
  end
end
