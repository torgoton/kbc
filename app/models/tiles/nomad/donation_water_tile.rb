module Tiles
  class Nomad
    class DonationWaterTile < Tiles::Nomad::DonationTile
      def build_terrain = "W"
    end
  end
end
