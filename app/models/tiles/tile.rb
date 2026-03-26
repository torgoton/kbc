module Tiles
  class Tile
    attr_accessor :qty

    def initialize(qty)
      @qty = qty
    end

    def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order:)
      []
    end

    def selectable_settlements(player_order:, board_contents:, board:)
      []
    end

    def activatable?(player_order:, board_contents:, board:)
      true
    end

    def self.from_hash(hash)
      "Tiles::#{hash['klass']}".constantize.new(0)
    rescue NameError
      raise ArgumentError, "Unknown tile class: #{hash['klass']}"
    end
  end
end
