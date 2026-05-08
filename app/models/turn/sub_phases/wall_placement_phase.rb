class Turn
  module SubPhases
    class WallPlacementPhase < Turn::SubPhase
      TYPE = "wall_placement".freeze
      TILE_KLASS = "QuarryTile".freeze
      MAX_WALLS = 2

      attr_reader :walls_placed, :chosen_terrain

      def initialize(walls_placed: 0, chosen_terrain: nil)
        super()
        @walls_placed = walls_placed.to_i
        @chosen_terrain = chosen_terrain
        @complete = false
      end

      def to_h
        { "walls_placed" => walls_placed, "chosen_terrain" => chosen_terrain }
      end

      def self.from_h(hash)
        new(walls_placed: hash.fetch("walls_placed", 0), chosen_terrain: hash["chosen_terrain"])
      end

      def handle(action_name, game:, player_order:, **params)
        case action_name
        when :place_wall
          handle_place_wall(game:, player_order:, row: params[:row], col: params[:col])
        when :end_tile_action
          handle_end_tile_action(player_order:)
        else
          [ error("unsupported action: #{action_name}") ]
        end
      end

      private

      def handle_place_wall(game:, player_order:, row:, col:)
        return error("no stone walls left") if game.stone_walls <= 0

        terrain = terrain_for(game, player_order, row, col)
        return error("not a valid wall destination") unless terrain

        consequences = [ Turn::Consequences::WallPlaced.new(at: Coordinate.new(row, col)) ]
        next_walls_placed = walls_placed + 1
        next_chosen_terrain = chosen_terrain || terrain

        if next_walls_placed >= MAX_WALLS || remaining_destinations(game, player_order, terrain, excluding: [ row, col ]).empty?
          @complete = true
          consequences << Turn::Consequences::TileConsumed.new(klass: TILE_KLASS, player: player_order)
        else
          prior = to_h
          @walls_placed = next_walls_placed
          @chosen_terrain = next_chosen_terrain
          consequences << Turn::Consequences::SubPhaseStateUpdated.new(prior_state: prior, new_state: to_h)
        end

        consequences
      end

      def handle_end_tile_action(player_order:)
        return error("cannot end Quarry before placing a wall") if walls_placed <= 0

        @complete = true
        [ Turn::Consequences::TileConsumed.new(klass: TILE_KLASS, player: player_order) ]
      end

      def terrain_for(game, player_order, row, col)
        player = player_for(game, player_order)
        terrains = chosen_terrain ? [ chosen_terrain ] : Array(player&.hand)
        terrains.find do |terrain|
          tile.valid_destinations(
            board_contents: game.board_contents,
            board: game.board,
            player_order: player_order,
            hand: terrain
          ).include?([ row, col ])
        end
      end

      def remaining_destinations(game, player_order, terrain, excluding:)
        board_contents = game.board_contents.dup
        board_contents.place_wall(*excluding)
        tile.valid_destinations(
          board_contents: board_contents,
          board: game.board,
          player_order: player_order,
          hand: terrain
        )
      end

      def player_for(game, player_order)
        game.game_players.find { |gp| gp.order == player_order }
      end

      def tile
        Tiles::QuarryTile.new(0)
      end

      def error(message)
        [ Turn::Consequences::Error.new(message: message) ]
      end
    end
  end
end
