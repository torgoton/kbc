module Tiles
  class Permanent
    class FerryTile < Tiles::Permanent
      CREATOR = "Claude".freeze
      DESCRIPTION = Game::DECREES["ferry"][:description]

      include Tiles::MovesFromSource

      def selectable_settlements(player_order:, board_contents:, hand: nil, budget: nil)
        shore = board_contents.ferry_shore
        super.select { |cell| shore.include?(cell) }
      end

      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order: nil, hand: nil, budget: nil)
        board_contents.ferry_shore.select do |r, c|
          board_contents.available_for_building?(r, c) && BUILDABLE_TERRAIN.include?(board_contents.terrain_at(r, c))
        end
      end
    end
  end
end
