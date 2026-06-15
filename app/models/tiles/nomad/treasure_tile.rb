module Tiles
  module Nomad
    class TreasureTile < Tiles::NomadTile
      CREATOR = "Icon by Vector Place".freeze
      DESCRIPTION = "Immediately score 3 points when picked up.".freeze

      def scores_on_pickup? = true
    end
  end
end
