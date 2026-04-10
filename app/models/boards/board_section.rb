module Boards
  class BoardSection
    attr_accessor :terrain
    attr_accessor :content
    attr_reader :flipped

    def map
      raise "Map not implemented"
    end

    def raw_silver_hexes
      []
    end

    def raw_location_hexes
      []
    end

    def silver_hexes
      flip_hexes(raw_silver_hexes)
    end

    def location_hexes
      flip_hexes(raw_location_hexes)
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
    end

    def terrain_at(row, column)
      @terrain[row][column]
    end

    private

    def flip_hexes(hexes)
      return hexes if @flipped == 0
      hexes.map { |h| h.merge(r: 9 - h[:r], c: 9 - h[:c]) }
    end
  end
end
