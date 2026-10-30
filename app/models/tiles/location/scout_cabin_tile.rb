module Tiles
  class Location
    class ScoutCabinTile < Tiles::Location
      CREATOR = "Claude".freeze
      SCOUTS = 2
      # Scouts may go on anything but Silver and Location hexes, Water and Mountain included.
      SCOUT_TERRAINS = %w[C D F G T B H W M].freeze
      DESCRIPTION = "Place up to 2 Scouts on empty hexes next to your settlements or each other. " \
                    "Scouts count as your settlements for adjacency only, and are removed at the end of your turn.".freeze

      def places_scouts? = true
      def cancellable_action? = true

      # No fallback: a Scout must touch one of your pieces (settlements or Scouts).
      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil, supply: Hash.new(0), budget: nil)
        board_contents.adjacency_sources_for(player_order).flat_map do |row, col|
          board_contents.neighbors_where(row, col) do |nr, nc|
            board_contents.empty?(nr, nc) && SCOUT_TERRAINS.include?(board_contents.terrain_at(nr, nc))
          end
        end.uniq
      end

      def action_message(player_handle:, terrain_names:, hand: nil)
        "#{player_handle} may place a Scout next to their settlements or Scouts"
      end
    end
  end
end
