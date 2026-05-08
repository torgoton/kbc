class Turn
  module SubPhases
    class TileBuildPhase < Turn::SubPhase
      TYPE = "tile_build".freeze

      attr_reader :restricted_terrain, :tile_klass, :tile_source

      def initialize(restricted_terrain:, tile_klass:, tile_source:)
        super()
        @restricted_terrain = restricted_terrain
        @tile_klass = tile_klass
        @tile_source = tile_source
        @complete = false
      end

      def to_h
        {
          "restricted_terrain" => restricted_terrain,
          "tile_klass" => tile_klass,
          "tile_source" => tile_source.to_key
        }
      end

      def self.from_h(hash)
        new(
          restricted_terrain: hash["restricted_terrain"],
          tile_klass: hash["tile_klass"],
          tile_source: Coordinate.from_key(hash["tile_source"])
        )
      end

      def handle(action_name, game:, player_order:, **params)
        case action_name
        when :build
          handle_build(game:, player_order:, row: params[:row], col: params[:col])
        else
          [ Turn::Consequences::Error.new(message: "unsupported action: #{action_name}") ]
        end
      end

      private

      def handle_build(game:, player_order:, row:, col:)
        game.instantiate_board unless game.board
        return error("hex (#{row}, #{col}) is not empty") unless game.board_contents.empty?(row, col)

        if restricted_terrain
          return error("hex outside restricted terrain #{restricted_terrain}") unless game.board.terrain_at(row, col) == restricted_terrain
        else
          return error("hex (#{row}, #{col}) not in #{tile_klass} valid_destinations") unless valid_destination?(game, player_order, row, col)
        end

        terrain = restricted_terrain || game.board.terrain_at(row, col)
        consequences = [
          Turn::Consequences::SettlementPlaced.new(
            at: Coordinate.new(row, col), player: player_order, terrain: terrain
          ),
          *Turn::Consequences::EndTriggered.maybe(game: game, player_order: player_order)
        ]

        game.board_contents.neighbors(row, col).each do |nr, nc|
          next unless game.board_contents.tile_qty(nr, nc) > 0
          consequences << Turn::Consequences::TilePickedUp.new(
            from: Coordinate.new(nr, nc),
            klass: game.board_contents.tile_klass(nr, nc),
            player: player_order
          )
        end

        consequences << Turn::Consequences::TileConsumed.new(klass: tile_klass, player: player_order)
        @complete = true
        consequences
      end

      def error(msg)
        [ Turn::Consequences::Error.new(message: msg) ]
      end

      def valid_destination?(game, player_order, row, col)
        klass = Tiles::Tile.for_klass(tile_klass)
        return false unless klass
        gp = game.game_players.find { |g| g.order == player_order }
        hand = gp&.hand.is_a?(Array) ? gp.hand.first : gp&.hand
        instance = klass.new(0)
        instance.valid_destinations(
          board_contents: game.board_contents,
          board: game.board,
          player_order: player_order,
          hand: hand
        ).include?([ row, col ])
      end
    end
  end
end
