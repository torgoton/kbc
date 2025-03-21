module Boards
  class Board
    attr_reader :map
    attr_reader :content

    def initialize(game)
      @map = []
      game.boards.each do |section|
        @map << "Boards::#{section[0]}Board".constantize.new(section[1])
      end
      @content = Array.new(20) { Array.new(20) }
      game.board_contents.each do |k, v|
        coords = JSON.parse k
        @content[coords[0]][coords[1]] = "Tiles::#{v['klass']}Tile".constantize.new(v["qty"])
        Rails.logger.info " from #{k}, #{v}"
        # Rails.logger.info "  at #{coords[0]},#{coords[1]}, added #{v:klass}Tile"
      end
    end

    def terrain_at(row, col)
      section = 2 * (row / 10) + col / 10
      @map[section].terrain_at(row % 10, col % 10)
    end

    def content_at(row, col)
      @content[row][col]
    end
  end
end
