class Turn
  module SubPhases
    class CityHallPhase < Turn::SubPhase
      TYPE = "city_hall".freeze
      TILE_KLASS = "CityHallTile".freeze

      def to_h
        {}
      end

      def self.from_h(_hash)
        new
      end

      def handle(action_name, game:, player_order:, **params)
        case action_name
        when :place_city_hall
          handle_place_city_hall(game:, player_order:, row: params[:row], col: params[:col])
        else
          [ error("unsupported action: #{action_name}") ]
        end
      end

      private

      def handle_place_city_hall(game:, player_order:, row:, col:)
        player = game.game_players.find { |gp| gp.order == player_order }
        return error("no current player") unless player

        valid = tile.valid_destinations(
          board_contents: game.board_contents,
          board: game.board,
          player_order: player_order,
          supply: player.supply_hash
        )
        return error("not a valid City Hall center") unless valid.include?([ row, col ])

        cluster = tile.cluster_hexes(row, col, game.board_contents).map { |r, c| Coordinate.new(r, c) }
        @complete = true
        [
          Turn::Consequences::CityHallPlaced.new(cluster: cluster, player: player_order),
          Turn::Consequences::CityHallSupplyDecremented.new(player: player_order),
          Turn::Consequences::PermanentTileConsumed.new(klass: TILE_KLASS, player: player_order)
        ]
      end

      def tile
        Tiles::CityHallTile.new(0)
      end

      def error(message)
        [ Turn::Consequences::Error.new(message: message) ]
      end
    end
  end
end
