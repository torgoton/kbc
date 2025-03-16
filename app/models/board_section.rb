class BoardSection
  attr_accessor :terrain
  attr_accessor :content

  def map
    raise "Map not implemented"
  end

  def tile_locations
    raise "Tile locations not implemented"
  end

  def tile_class
    Tile
  end

  def initialize(flipped)
    @flipped = flipped
    if @flipped == 0
      @terrain = map
    else
      @terrain = MAP.reverse.map(&:reverse)
    end
  end

  def terrain_at(row, column)
    @terrain[row][column]
  end

  def add_tiles
    tile_locations.each do |loc|
      if @flipped == 0
        @content << { r: loc[0], c: loc[1], klass: tile_class, qty: 2 }
      else
        @content << { r: 9-loc[0], c: 9-loc[1], klass: tile_class, qty: 2 }
      end
    end
  end
end
