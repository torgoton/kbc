class Turn
  module Consequences
    CityHallPlaced = Data.define(:cluster, :player) do
      def apply!(game)
        game.board_contents_will_change!
        cluster.each { |coord| game.board_contents.place_city_hall_hex(coord.row, coord.col, player) }
      end

      def unapply!(game)
        game.board_contents_will_change!
        cluster.each { |coord| game.board_contents.remove(coord.row, coord.col) }
      end

      def to_h
        { "type" => "city_hall_placed", "cluster" => cluster.map(&:to_key), "player" => player }
      end

      def self.from_h(hash)
        new(cluster: Array(hash["cluster"]).map { |key| Coordinate.from_key(key) }, player: hash["player"])
      end
    end
  end
end
