module Boards
  class BoardSection
    attr_accessor :terrain
    attr_accessor :content
    attr_reader :flipped

    def map
      raise "Map not implemented"
    end

    def silver_hexes
      []
    end

    def location_hexes
      []
    end

    def initialize(flipped)
      @flipped = flipped
      if @flipped == 0
        map_data = map
      else
        map_data = map.reverse.map(&:reverse)
      end
      @terrain = Array.new(10) { Array.new(10) }
      map_data.each_with_index do |line, r|
        10.times do |c|
          @terrain[r][c] = line[c]
        end
      end
      (silver_hexes + location_hexes).each do |hex|
        # Rails.logger.debug " - adding #{hex.inspect}"
        if @flipped == 0
          @terrain[hex[:r]][hex[:c]] = "#{hex[:k]}Hex"
        else
          @terrain[9 - hex[:r]][9 - hex[:c]] = "#{hex[:k]}Hex"
        end
      end
    end

    def terrain_at(row, column)
      @terrain[row][column]
    end

    # def content_at(row, column)
    #   @content[row][column]
    # end

    # def add_tiles
    #   tile_locations.each do |loc|
    #     if @flipped == 0
    #       @content [loc[0]][loc[1]] = { klass: tile_class, qty: 2 }
    #     else
    #       @content [9 - loc[0]][9 - loc[1]] = { klass: tile_class, qty: 2 }
    #       # @content << { r: 9-loc[0], c: 9-loc[1], klass: tile_class, qty: 2 }
    #     end
    #   end
    # end
  end
end
