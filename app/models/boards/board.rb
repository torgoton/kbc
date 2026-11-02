module Boards
  class Board
    attr_reader :map, :island, :ferry_hex, :cave_hexes
    attr_reader :content

    TERRAIN_NAMES = {
      "C" => "Canyon",
      "D" => "Desert",
      "F" => "Flowers",
      "G" => "Grass",
      "H" => "Farmland",
      "T" => "Timberland",
      "W" => "Water",
      "M" => "Mountain",
      "B" => "Swamp",
      "S" => "Silver",
      "L" => "Location",
      "Z" => ""
    }

    # "GB" => "Grass / Swamp"
    def self.card_name(card)
      card.to_s.chars.map { |t| TERRAIN_NAMES[t] }.join(" / ")
    end

    TILE_CLASSES = {
      "BarnTile"             => Tiles::Location::BarnTile,
      "FarmTile"             => Tiles::Location::FarmTile,
      "OasisTile"            => Tiles::Location::OasisTile,
      "OracleTile"           => Tiles::Location::OracleTile,
      "PaddockTile"          => Tiles::Location::PaddockTile,
      "TavernTile"           => Tiles::Location::TavernTile,
      "TowerTile"            => Tiles::Location::TowerTile,
      "HarborTile"           => Tiles::Location::HarborTile,
      "CaravanTile"          => Tiles::Location::CaravanTile,
      "GardenTile"           => Tiles::Location::GardenTile,
      "QuarryTile"           => Tiles::Location::QuarryTile,
      "VillageTile"          => Tiles::Location::VillageTile,
      "LighthouseTile"       => Tiles::Location::LighthouseTile,
      "ForestersLodgeTile"   => Tiles::Location::ForestersLodgeTile,
      "BarracksTile"         => Tiles::Location::BarracksTile,
      "CrossroadsTile"       => Tiles::Location::CrossroadsTile,
      "CityHallTile"         => Tiles::Location::CityHallTile,
      "FortTile"             => Tiles::Location::FortTile,
      "MonasteryTile"        => Tiles::Location::MonasteryTile,
      "WagonTile"            => Tiles::Location::WagonTile,
      "TempleTile"           => Tiles::Location::TempleTile,
      "RefugeTile"           => Tiles::Location::RefugeTile,
      "FountainTile"         => Tiles::Location::FountainTile,
      "CanoeTile"            => Tiles::Location::CanoeTile,
      "BazaarTile"           => Tiles::Location::BazaarTile,
      "WaterMillTile"        => Tiles::Location::WaterMillTile,
      "MountainStationTile"  => Tiles::Location::MountainStationTile,
      "ScoutCabinTile"       => Tiles::Location::ScoutCabinTile,
      "CathedralTile"        => Tiles::Location::CathedralTile,
      "WatchtowerTile"       => Tiles::Location::WatchtowerTile,
      "UniversityTile"       => Tiles::Location::UniversityTile,
      "PalisadeTile"         => Tiles::Location::PalisadeTile,
      "RopeBridgeTile"       => Tiles::Location::RopeBridgeTile,
      "TreeHouseTile"        => Tiles::Location::TreeHouseTile,
      "FountainBonusTile"    => Tiles::Bonus::FountainBonusTile,
      "TempleBonusTile"      => Tiles::Bonus::TempleBonusTile,
      "CanoeBonusTile"       => Tiles::Bonus::CanoeBonusTile,
      "RefugeBonusTile"      => Tiles::Bonus::RefugeBonusTile,
      "MandatoryTile"        => Tiles::Permanent::MandatoryTile,
      "FarmlandTile"         => Tiles::Permanent::FarmlandTile,
      "FerryTile"            => Tiles::Permanent::FerryTile,
      "CaveTile"             => Tiles::Permanent::CaveTile,
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

    # Terrains that count as water for "next to water" rules; X is the Island's sea rim.
    WATER = %w[W X].freeze

    def initialize(game)
      @map = []
      @island = Island.new(game.decree["map"]) if game.island?
      @ferry_hex = game.ferry_hex
      @cave_hexes = game.cave_hexes
      game.boards.each do |section|
        @map << BoardSection.new(section[0], section[1])
      end
      game.capitol_hexes&.each { |r, c| @map[2 * (r / 10) + c / 10].change_silver_hex(r % 10, c % 10, "Capitol") }
      # This fills in the in-memory content of the board from board_contents, which is the source of
      # truth for what's on the board. We need to do this to properly instantiate tile objects with
      # their qty, and to properly instantiate settlements with their player.
      @content = {}
      game.board_contents.occupied.each do |row, col|
        klass = game.board_contents.tile_klass(row, col)
        @content[[ row, col ]] =
          if klass == "Wall"
            Wall.new
          elsif klass == "Scout"
            Scout.new(game.board_contents.scout_owner(row, col))
          elsif klass
            tile_class = TILE_CLASSES.fetch(klass) { raise ArgumentError, "Unknown tile class: #{klass}" }
            tile_class.new(game.board_contents.tile_qty(row, col))
          elsif (player = game.board_contents.player_at(row, col))
            Settlement.new(player,
              meeple_type: game.board_contents.meeple_at(row, col),
              city_hall: game.board_contents.city_hall_at?(row, col))
          else
            raise "Unknown board content type at [#{row}, #{col}]"
          end
      end
    end

    def terrain_at(row, col)
      return @island ? @island.terrain_at(row, col) : "" if row >= Island::ROW
      section = 2 * (row / 10) + col / 10
      return "" unless (0..3).include? section
      return "" unless @map[section] # some tests have no boards
      @map[section].terrain_at(row % 10, col % 10)
    end

    def content_at(row, col)
      @content[[ row, col ]]
    end

    # Board [row, col] of every silver hex of `kind`, Island included.
    def silver_hexes_of(kind)
      main = @map.each_with_index.flat_map do |section, i|
        section.silver_hexes.select { |h| h[:k] == kind }.map { |h| [ i / 2 * 10 + h[:r], i % 2 * 10 + h[:c] ] }
      end
      main + island_silver_hexes.select { |h| h[:k] == kind }.map { |h| [ h[:r], h[:c] ] }
    end

    def island_silver_hexes = @island ? @island.silver_hexes : []

    def island_cells = @island ? @island.cells : []
  end
end
