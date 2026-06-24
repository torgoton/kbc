module Tiles
  class Nomad
    class TreasureTile < Tiles::Nomad
      CREATOR = "Icon by Vector Place".freeze
      DESCRIPTION = "Immediately score 3 points when picked up.".freeze

      def pickup_score = [ "treasure", 3 ]
    end
  end
end
