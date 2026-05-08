class Turn
  module SubPhases
    class FortPhase < Turn::SubPhase
      TYPE = "fort".freeze

      attr_reader :fort_terrain, :builds_remaining

      def initialize(fort_terrain:, builds_remaining: 2)
        super()
        @fort_terrain = fort_terrain
        @builds_remaining = builds_remaining
        @complete = false
      end

      def to_h
        { "fort_terrain" => fort_terrain, "builds_remaining" => builds_remaining }
      end

      def self.from_h(hash)
        new(fort_terrain: hash["fort_terrain"], builds_remaining: hash["builds_remaining"])
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

        return error("hex outside fort terrain #{fort_terrain}") unless game.board.terrain_at(row, col) == fort_terrain
        return error("hex (#{row}, #{col}) is not empty") unless game.board_contents.empty?(row, col)

        prior = to_h
        @builds_remaining -= 1
        @complete = (@builds_remaining <= 0)

        consequences = [
          Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(row, col), player: player_order, terrain: fort_terrain)
        ]
        # Only emit SubPhaseStateUpdated if not completing — the completion path
        # emits SubPhasePopped at the Turn layer, which restores prior state on undo.
        unless @complete
          consequences << Turn::Consequences::SubPhaseStateUpdated.new(prior_state: prior, new_state: to_h)
        end
        consequences
      end

      def error(msg)
        [ Turn::Consequences::Error.new(message: msg) ]
      end
    end
  end
end
