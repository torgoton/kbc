module Tiles
  class Tile
    attr_accessor :qty

    def initialize(qty)
      @qty = qty
    end

    def build_terrain = nil

    def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order:, hand: nil)
      terrain = build_terrain || hand
      return [] unless terrain

      adjacent = board_contents.settlements_for(player_order).flat_map do |r, c|
        board_contents.neighbors_where(r, c) do |nr, nc|
          board_contents.empty?(nr, nc) && board.terrain_at(nr, nc) == terrain
        end
      end.uniq

      return adjacent unless adjacent.empty?

      (0..19).flat_map do |r|
        (0..19).filter_map do |c|
          [ r, c ] if board_contents.empty?(r, c) && board.terrain_at(r, c) == terrain
        end
      end
    end

    def selectable_settlements(player_order:, board_contents:, board:)
      []
    end

    def activatable?(player_order:, board_contents:, board:, hand: nil)
      valid_destinations(board_contents:, board:, player_order:, hand:).any?
    end

    def builds_settlement?
      false
    end

    def self.from_hash(hash)
      "Tiles::#{hash['klass']}".constantize.new(0)
    rescue NameError
      raise ArgumentError, "Unknown tile class: #{hash['klass']}"
    end
  end
end
