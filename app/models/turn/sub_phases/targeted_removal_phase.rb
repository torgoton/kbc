class Turn
  module SubPhases
    class TargetedRemovalPhase < Turn::SubPhase
      TYPE = "targeted_removal".freeze
      TILE_KLASS = "SwordTile".freeze

      attr_reader :pending_orders

      def initialize(pending_orders:)
        super()
        @pending_orders = Array(pending_orders).map(&:to_i)
        @complete = false
      end

      def to_h
        { "pending_orders" => pending_orders }
      end

      def self.from_h(hash)
        new(pending_orders: Array(hash["pending_orders"]))
      end

      def handle(action_name, game:, player_order:, **params)
        case action_name
        when :remove_settlement
          handle_remove(game:, player_order:, row: params[:row], col: params[:col])
        else
          [ error("unsupported action: #{action_name}") ]
        end
      end

      private

      def handle_remove(game:, player_order:, row:, col:)
        return error("cannot remove a City Hall hex") if game.board_contents.city_hall_at?(row, col)

        owner_order = game.board_contents.player_at(row, col)
        return error("not a valid target") unless owner_order && pending_orders.include?(owner_order)

        at = Coordinate.new(row, col)
        kind = game.board_contents.meeple_at(row, col)
        consequences = [
          Turn::Consequences::PieceRemoved.new(at: at, kind: kind, player: owner_order),
          *tile_forfeits(game, owner_order, at)
        ]

        remaining = pending_orders - [ owner_order ]
        if remaining.empty?
          @complete = true
          consequences << Turn::Consequences::TileConsumed.new(klass: TILE_KLASS, player: player_order)
        else
          prior = to_h
          @pending_orders = remaining
          consequences << Turn::Consequences::SubPhaseStateUpdated.new(prior_state: prior, new_state: to_h)
        end

        consequences
      end

      def tile_forfeits(game, owner_order, removed_at)
        owner = game.game_players.find { |gp| gp.order == owner_order }
        settlement_positions = game.board_contents.settlements_for(owner_order).reject do |row, col|
          row == removed_at.row && col == removed_at.col
        end

        Array(owner&.tiles).filter_map do |held_tile|
          next if Tiles::Tile.for_klass(held_tile["klass"])&.new(0)&.nomad_tile?
          from_key = held_tile["from"]
          next unless from_key
          from = Coordinate.from_key(from_key)
          next unless game.board_contents.tile_klass(from.row, from.col)

          still_adjacent = settlement_positions.any? do |row, col|
            game.board_contents.neighbors(row, col).any? { |nr, nc| Coordinate.new(nr, nc).to_key == from_key }
          end
          next if still_adjacent

          Turn::Consequences::TileDiscarded.new(
            player: owner_order,
            klass: held_tile["klass"],
            from: from_key,
            used: held_tile["used"]
          )
        end
      end

      def error(message)
        [ Turn::Consequences::Error.new(message: message) ]
      end
    end
  end
end
