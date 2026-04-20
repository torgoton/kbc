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

    TILE_CLASSES = {
      "BarnTile"             => Tiles::BarnTile,
      "FarmTile"             => Tiles::FarmTile,
      "OasisTile"            => Tiles::OasisTile,
      "OracleTile"           => Tiles::OracleTile,
      "PaddockTile"          => Tiles::PaddockTile,
      "TavernTile"           => Tiles::TavernTile,
      "TowerTile"            => Tiles::TowerTile,
      "HarborTile"           => Tiles::HarborTile,
      "CaravanTile"          => Tiles::CaravanTile,
      "GardenTile"           => Tiles::GardenTile,
      "QuarryTile"           => Tiles::QuarryTile,
      "VillageTile"          => Tiles::VillageTile,
      "DonationCanyonTile"   => Tiles::Nomad::DonationCanyonTile,
      "DonationDesertTile"   => Tiles::Nomad::DonationDesertTile,
      "DonationFlowerTile"   => Tiles::Nomad::DonationFlowerTile,
      "DonationGrassTile"    => Tiles::Nomad::DonationGrassTile,
      "DonationTimberTile"   => Tiles::Nomad::DonationTimberTile,
      "DonationWaterTile"    => Tiles::Nomad::DonationWaterTile,
      "DonationMountainTile" => Tiles::Nomad::DonationMountainTile,
      "ResettlementTile"     => Tiles::Nomad::ResettlementTile,
      "OutpostTile"          => Tiles::Nomad::OutpostTile,
      "SwordTile"            => Tiles::Nomad::SwordTile,
      "TreasureTile"         => Tiles::Nomad::TreasureTile
    }.freeze

    NOMAD_TILE_POOL = %w[
      DonationCanyonTile DonationDesertTile DonationFlowerTile DonationGrassTile
      DonationTimberTile DonationWaterTile DonationMountainTile
      ResettlementTile ResettlementTile OutpostTile OutpostTile
      SwordTile SwordTile TreasureTile TreasureTile
    ].freeze

    def initialize(game)
      @map = []
      game.boards.each do |section|
        @map << BoardSection.new(section[0], section[1])
      end
      # This fills in the in-memory content of the board from board_contents, which is the source of
      # truth for what's on the board. We need to do this to properly instantiate tile objects with
      # their qty, and to properly instantiate settlements with their player.
      @content = Array.new(20) { Array.new(20) }
      20.times do |row|
        20.times do |col|
          next if game.board_contents.empty?(row, col)
          klass = game.board_contents.tile_klass(row, col)
          if klass == "Wall"
            @content[row][col] = Wall.new
          elsif klass
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
