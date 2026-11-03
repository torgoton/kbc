module Tiles
  class Permanent
    class FerryTile < Tiles::Permanent
      CREATOR = "Claude".freeze
      DESCRIPTION = Game::DECREES["ferry"][:description]

      include Tiles::MovesAlongShore

      def shore(board_contents) = board_contents.ferry_shore
    end
  end
end
