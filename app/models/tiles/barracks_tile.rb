module Tiles
  class BarracksTile < Tiles::Tile
    CREATOR = "Icon by Anton Gajdosik".freeze
    DESCRIPTION = "Place or remove a warrior".freeze

    def places_meeple? = true

    def on_pickup(game_player:)
      game_player.add_warriors!(2)
    end

    def activatable?(player_order:, board_contents:, board:, hand: nil, warrior_supply: 0, ship_supply: 0)
      warrior_supply > 0 || board_contents.warriors_for(player_order).any?
    end

    def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order:, hand: nil, warrior_supply: 0, ship_supply: 0)
      placement = warrior_supply > 0 ? placement_hexes(board_contents:, board:, player_order:) : []
      removal = board_contents.warriors_for(player_order)
      (placement + removal).uniq
    end

    private

    def placement_hexes(board_contents:, board:, player_order:)
      all_valid = (0..19).flat_map do |r|
        (0..19).filter_map do |c|
          [ r, c ] if BUILDABLE_TERRAIN.include?(board.terrain_at(r, c)) && board_contents.available_for_building?(r, c)
        end
      end

      own = board_contents.settlements_for(player_order)
      adjacent = own.flat_map { |r, c|
        board_contents.neighbors_where(r, c) { |nr, nc| all_valid.include?([ nr, nc ]) }
      }.uniq

      adjacent.any? ? adjacent : all_valid
    end
  end
end
