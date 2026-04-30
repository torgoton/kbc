module Tiles
  class CityHallTile < Tiles::Tile
    CREATOR = "Icon by Chris Schumann".freeze
    DESCRIPTION = "Place your City Hall on 7 connected hexes".freeze

    def places_city_hall? = true

    def on_pickup(game_player:)
      game_player.add_city_halls!(1)
    end

    def activatable?(player_order:, board_contents:, board:, hand: nil, supply: Hash.new(0))
      supply["city_hall"].to_i > 0 && valid_destinations(board_contents:, board:, player_order:, supply:).any?
    end

    def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order:, hand: nil, supply: Hash.new(0))
      return [] if supply["city_hall"].to_i < 1

      (0..19).flat_map do |r|
        (0..19).filter_map do |c|
          [ r, c ] if valid_center?(r, c, board_contents:, board:, player_order:)
        end
      end
    end

    def action_message(player_handle:, terrain_names:, hand: nil)
      "#{player_handle} must place their City Hall"
    end

    def cluster_hexes(center_row, center_col, board_contents)
      neighbors = board_contents.neighbors(center_row, center_col)
      [ [ center_row, center_col ] ] + neighbors
    end

    private

    def valid_center?(row, col, board_contents:, board:, player_order:)
      return false unless buildable_and_empty?(row, col, board_contents:, board:)

      neighbors = board_contents.neighbors(row, col)
      return false unless neighbors.size == 6
      return false unless neighbors.all? { |nr, nc| buildable_and_empty?(nr, nc, board_contents:, board:) }

      cluster = Set.new([ [ row, col ] ] + neighbors)
      neighbors.any? do |nr, nc|
        board_contents.neighbors(nr, nc).any? do |or_, oc|
          !cluster.include?([ or_, oc ]) && board_contents.settlements_for(player_order).include?([ or_, oc ])
        end
      end
    end

    def buildable_and_empty?(row, col, board_contents:, board:)
      board_contents.empty?(row, col) && BUILDABLE_TERRAIN.include?(board.terrain_at(row, col))
    end
  end
end
