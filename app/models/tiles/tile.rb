module Tiles
  class Tile
    BUILDABLE_TERRAIN = %w[C D F G T].freeze

    attr_accessor :qty

    def initialize(qty)
      @qty = qty
    end

    def build_terrain = nil

    def valid_destinations(from_row: nil, from_col: nil, board_contents:, board:, player_order:, hand: nil)
      terrain = build_terrain || hand
      return [] unless terrain

      settlements = board_contents.settlements_for(player_order)
      settlements = settlements.reject { |r, c| r == from_row && c == from_col } if from_row && from_col

      adjacent = settlements.flat_map do |r, c|
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

    def selectable_settlements(player_order:, board_contents:, board:, hand: nil)
      return [] unless moves_settlement?
      return [] unless valid_destinations(board_contents:, board:, player_order:, hand:).any?
      board_contents.settlements_for(player_order)
    end

    def activatable?(player_order:, board_contents:, board:, hand: nil)
      valid_destinations(board_contents:, board:, player_order:, hand:).any?
    end

    def builds_settlement?
      false
    end

    def moves_settlement?
      false
    end

    def nomad_tile?
      false
    end

    def places_wall?
      false
    end

    def outpost_tile?
      false
    end

    def sword_tile?
      false
    end

    # Returns the terrain key that constrains the move destination, or nil if unconstrained.
    # Subclasses override this (e.g. BarnTile returns hand, HarborTile returns "W").
    def move_terrain(hand:) = nil

    # Human-readable description of what the player must do with this tile.
    def action_message(player_handle:, terrain_names:, hand: nil)
      if moves_settlement?
        terrain = move_terrain(hand:)
        msg = "#{player_handle} must move a settlement"
        terrain ? "#{msg} to a #{terrain_names[terrain]} space" : msg
      else
        terrain = build_terrain || hand
        terrain ? "#{player_handle} must build on a #{terrain_names[terrain]} space" : "#{player_handle} must build"
      end
    end

    def self.from_hash(hash)
      "Tiles::#{hash['klass']}".constantize.new(0)
    rescue NameError
      raise ArgumentError, "Unknown tile class: #{hash['klass']}"
    end
  end
end
