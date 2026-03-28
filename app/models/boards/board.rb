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

    BOARD_CLASSES = {
      "Farm"    => Boards::FarmBoard,
      "Oasis"   => Boards::OasisBoard,
      "Paddock" => Boards::PaddockBoard,
      "Tavern"  => Boards::TavernBoard
    }.freeze

    TILE_CLASSES = {
      "FarmTile"    => Tiles::FarmTile,
      "OasisTile"   => Tiles::OasisTile,
      "PaddockTile" => Tiles::PaddockTile,
      "TavernTile"  => Tiles::TavernTile
    }.freeze

    def initialize(game)
      @map = []
      game.boards.each do |section|
        board_class = BOARD_CLASSES.fetch(section[0]) { raise ArgumentError, "Unknown board type: #{section[0]}" }
        @map << board_class.new(section[1])
      end
      @content = Array.new(20) { Array.new(20) }
      20.times do |row|
        20.times do |col|
          next if game.board_contents.empty?(row, col)
          klass = game.board_contents.tile_klass(row, col)
          if klass
            tile_class = TILE_CLASSES.fetch(klass) { raise ArgumentError, "Unknown tile class: #{klass}" }
            @content[row][col] = tile_class.new(game.board_contents.tile_qty(row, col))
          elsif (player = game.board_contents.player_at(row, col))
            @content[row][col] = Settlement.new(player)
          else
            raise "Unknown board content type at [#{row}, #{col}]"
          end
        end
      end
    end

    def terrain_at(row, col)
      section = 2 * (row / 10) + col / 10
      return "" unless (0..3).include? section
      return "" unless @map[section] # some tests have no boards
      @map[section].terrain_at(row % 10, col % 10)
    end

    def content_at(row, col)
      @content[row][col]
    end
  end
end
