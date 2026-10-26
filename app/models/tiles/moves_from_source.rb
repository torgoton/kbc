module Tiles
  # Settlement movers whose destinations depend on the settlement moved (Paddock, Caravan,
  # Refuge): a settlement is selectable when it has somewhere to go.
  module MovesFromSource
    def moves_settlement? = true

    def selectable_settlements(player_order:, board_contents:, hand: nil, budget: nil)
      board_contents.settlements_for(player_order).filter_map do |r, c|
        next if board_contents.city_hall_at?(r, c)
        [ r, c ] if valid_destinations(from_row: r, from_col: c, board_contents:).any?
      end
    end

    def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0))
      selectable_settlements(player_order:, board_contents:, hand:).any?
    end
  end
end
