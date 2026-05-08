class Turn
  module Consequences
    CityHallSupplyDecremented = Data.define(:player) do
      def apply!(game)
        gp(game).decrement_city_hall_supply!
      end

      def unapply!(game)
        gp(game).increment_city_hall_supply!
      end

      def to_h
        { "type" => "city_hall_supply_decremented", "player" => player }
      end

      def self.from_h(hash)
        new(player: hash["player"])
      end

      private

      def gp(game)
        game.game_players.find { |g| g.order == player }
      end
    end
  end
end
