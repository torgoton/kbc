module Tiles
  class Permanent
    class CaveTile < Tiles::Permanent
      CREATOR = "Claude".freeze
      DESCRIPTION = Game::DECREES["caves"][:description]

      include Tiles::MovesAlongShore

      def shore(board_contents) = board_contents.cave_shore
    end
  end
end
