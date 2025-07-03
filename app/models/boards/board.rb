module Boards
  class Board
    attr_reader :map
    attr_reader :content

    TERRAIN_NAMES = {
      "C" => "Canyon",
      "D" => "Desert",
      "F" => "Flowers",
      "G" => "Grass",
      "T" => "Timberland",
      "W" => "Water",
      "M" => "Mountain",
      "S" => "Silver",
      "L" => "Location"
    }

    def initialize(game)
      @map = []
      game.boards.each do |section|
        @map << "Boards::#{section[0]}Board".constantize.new(section[1])
      end
      @content = Array.new(20) { Array.new(20) }
      if game.board_contents
        game.board_contents.each do |k, v|
          coords = JSON.parse k
          case v["klass"]
          when /Tile\z/
            @content[coords[0]][coords[1]] = "Tiles::#{v['klass']}".constantize.new(v["qty"])
          when "Settlement"
            @content[coords[0]][coords[1]] = Settlement.new(v["player"])
          else
            raise "Unknown board content type"
          end
        end
      end
    end

    def terrain_at(row, col)
      section = 2 * (row / 10) + col / 10
      return "" unless (0..4).include? section
      return "" unless @map[section] # some tests have no boards
      @map[section].terrain_at(row % 10, col % 10)
    end

    def content_at(row, col)
      @content[row][col]
    end
  end
end
