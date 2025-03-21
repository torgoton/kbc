module Tiles
  class Tile
    attr_accessor :qty

    def initialize(qty)
      @qty = qty
    end

    def location_index
      0
    end
  end
end
