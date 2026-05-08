class Turn
  module SubPhases
    # Single-click sub-phase for meeple-placing tiles (Barracks, Lighthouse,
    # Wagon — the placement subset). Validates target ∈ tile.valid_destinations
    # AND target is empty (placement only — move/remove of own meeples is a
    # separate slice).
    class MeeplePlacementPhase < Turn::SubPhase
      TYPE = "meeple_placement".freeze

      attr_reader :tile_klass, :kind

      def initialize(tile_klass:, kind:)
        super()
        @tile_klass = tile_klass
        @kind = kind
        @complete = false
      end

      def to_h
        { "tile_klass" => tile_klass, "kind" => kind }
      end

      def self.from_h(hash)
        new(tile_klass: hash["tile_klass"], kind: hash["kind"])
      end

      def handle(action_name, game:, player_order:, **params)
        case action_name
        when :place_meeple
          handle_place(game:, player_order:, row: params[:row], col: params[:col])
        else
          [ Turn::Consequences::Error.new(message: "unsupported action: #{action_name}") ]
        end
      end

      private

      def handle_place(game:, player_order:, row:, col:)
        return error("hex (#{row}, #{col}) is not empty") unless game.board_contents.empty?(row, col)

        klass = Tiles::Tile.for_klass(tile_klass)
        return error("unknown tile #{tile_klass}") unless klass
        valid = klass.new(0).valid_destinations(
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
