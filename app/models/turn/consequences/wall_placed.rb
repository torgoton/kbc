class Turn
  module Consequences
    WallPlaced = Data.define(:at) do
      def apply!(game)
        game.board_contents_will_change!
        game.board_contents.place_wall(at.row, at.col)
        game.stone_walls -= 1
      end

      def unapply!(game)
        game.board_contents_will_change!
        game.board_contents.remove(at.row, at.col)
        game.stone_walls += 1
      end

      def to_h
        { "type" => "wall_placed", "at" => at.to_key }
      end

      def self.from_h(hash)
        new(at: Coordinate.from_key(hash["at"]))
      end
    end
  end
end
